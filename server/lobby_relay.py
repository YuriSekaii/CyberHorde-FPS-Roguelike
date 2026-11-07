"""CyberHorde online lobby relay.

Runs on the Tailscale Funnel machine and is published at
wss://phu-ai-lab.tailbca584.ts.net/cyberhorde. Any player can create a lobby
(becoming peer 1 / host) and up to 3 others join with the 5-letter code. Game
packets are forwarded verbatim between lobby members, so the Godot host stays
authoritative exactly like ENet co-op.

Wire protocol (one WebSocket per player):
  text frames   = JSON control messages
    -> {"op":"create"}                       <- {"op":"created","code":"ABCDE","id":1}
    -> {"op":"join","code":"ABCDE"}          <- {"op":"joined","code":..,"id":N,"peers":[1,..]}
    -> {"op":"lock","locked":true}           (host only: refuse new joins)
    -> {"op":"kick","id":N}                  (host only)
    -> {"op":"signal","to":N,"data":{..}}    <- {"op":"signal","from":N,"data":{..}}
                                             <- {"op":"peer_connected","id":N}
                                             <- {"op":"peer_disconnected","id":N}
                                             <- {"op":"error","msg":".."}  (then closed, reason = msg)
  binary frames = game packets
    -> int32 LE target (0 = all, >0 = peer, <0 = all except -target) + payload
    <- int32 LE source peer id + payload

UDP bridge (optional, unreliable packets only; reliable ones always use the WebSocket):
  clients birthday-punch to this PC's UDP bridge port (CYBERHORDE_BRIDGE_PORT, default 8096)
  text  -> {"op":"bridge","kind":"random|fixed","ip":<client public ip>,"port":<client mapped port>}
        <- {"op":"bridge_open","ip":<lab public ip>,"port":<lab udp port>,"token":<u32>}
  text  -> {"op":"bridge_go"}              (client announces are out: start probing it)
  control = 0xFF 'C' 'H' + u8 type (1 announce, 2 probe, 3 ack, 4 keepalive) + u32 token LE
  client -> lab = 0xFE + s32 target (0 all, >0 peer, <0 all except) + u32 seq + payload
  lab -> client = 0xFE + s32 source peer id + u32 seq + payload
  Recipients without a bridge get a normal WebSocket frame (seq stripped).
  CYBERHORDE_BRIDGE_TEST=1 skips STUN and advertises 127.0.0.1 (local tests).
"""

import asyncio
import ipaddress
import json
import logging
import os
import random
import secrets
import signal
import socket
import struct
import subprocess
import sys
import time
from http import HTTPStatus

if sys.flags.no_site:
    # Launched with -S to skip site-packages .pth startup hooks (this PC has one that
    # imports torch, ~1.3 GB per process); put site-packages back so websockets resolves.
    import sysconfig
    sys.path.append(sysconfig.get_paths()["purelib"])

from websockets.asyncio.server import serve

ROOT_DIR = os.path.abspath(os.path.dirname(__file__))

if sys.stdout is None or sys.stderr is None:
    log_file = open(os.path.join(ROOT_DIR, "relay_runtime.log"), "a", encoding="utf-8", buffering=1)
    sys.stdout = sys.stdout or log_file
    sys.stderr = sys.stderr or log_file

PORT = int(os.environ.get("CYBERHORDE_RELAY_PORT", 8095))
BRIDGE_PORT = int(os.environ.get("CYBERHORDE_BRIDGE_PORT", 8096))
BRIDGE_TEST = os.environ.get("CYBERHORDE_BRIDGE_TEST") == "1"
STUN_HOST = ("stun.l.google.com", 19302)
STUN_MAX_AGE = 60
FUNNEL_PATH = "/cyberhorde"
MAX_PLAYERS = 4
MAX_PACKET = 1 << 20
MAX_QUEUED = 4096  # outbound frames buffered per player before we drop them as too slow
CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", stream=sys.stdout)
log = logging.getLogger("relay")
logging.getLogger("websockets").setLevel(logging.WARNING)


class Member:
    def __init__(self, ws, peer_id):
        self.ws = ws
        self.id = peer_id
        self.lobby = None
        self.bridge_token = 0
        self.bridge_expect_ip = ""
        self.bridge_kind = "random"
        self.bridge_port = 0
        self.bridge_addr = None
        self.queue = asyncio.Queue()
        self.sender = asyncio.create_task(self._send_loop())

    async def _send_loop(self):
        try:
            while True:
                await self.ws.send(await self.queue.get())
        except Exception:
            pass

    def push(self, frame):
        if self.queue.qsize() >= MAX_QUEUED:
            log.warning("peer %d too slow, dropping connection", self.id)
            asyncio.create_task(self.ws.close(1008, "too slow"))
            return
        self.queue.put_nowait(frame)

    def push_json(self, msg):
        self.push(json.dumps(msg))


class Lobby:
    def __init__(self, code):
        self.code = code
        self.members = {}
        self.next_id = 2
        self.locked = False


lobbies = {}


def new_code():
    while True:
        code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(5))
        if code not in lobbies:
            return code


# ---- UDP bridge ----

bridge = {"transport": None, "addr": None, "stun_at": 0.0, "stun_tx": b"", "stun_fut": None}
bridge_addrs = {}   # client udp addr -> Member
bridge_tokens = {}  # token -> Member


def stun_parse(data):
    """XOR-MAPPED-ADDRESS (or MAPPED-ADDRESS) of a STUN Binding success response, as (ip, port)."""
    i = 20
    while i + 4 <= len(data):
        t, l = struct.unpack_from(">HH", data, i)
        if t in (0x0020, 0x0001) and l >= 8 and data[i + 5] == 1:
            x = 0x2112A442 if t == 0x0020 else 0
            port = struct.unpack_from(">H", data, i + 6)[0] ^ (x >> 16)
            ip = struct.unpack_from(">I", data, i + 8)[0] ^ x
            return str(ipaddress.IPv4Address(ip)), port
        i += 4 + ((l + 3) & ~3)
    return None


async def bridge_refresh_stun():
    if BRIDGE_TEST or time.time() - bridge["stun_at"] < STUN_MAX_AGE:
        return
    try:
        loop = asyncio.get_running_loop()
        infos = await loop.getaddrinfo(*STUN_HOST, family=socket.AF_INET, type=socket.SOCK_DGRAM)
        bridge["stun_tx"] = os.urandom(12)
        bridge["stun_fut"] = loop.create_future()
        bridge["transport"].sendto(struct.pack(">HHI", 1, 0, 0x2112A442) + bridge["stun_tx"], infos[0][4])
        await asyncio.wait_for(bridge["stun_fut"], 3)
    except Exception as e:
        log.warning("bridge STUN failed: %s", e)


class BridgeProtocol(asyncio.DatagramProtocol):
    def connection_made(self, transport):
        bridge["transport"] = transport

    def datagram_received(self, data, addr):
        if len(data) < 8:
            return
        if data[0] == 0x01 and data[1] == 0x01 and len(data) >= 20 and data[8:20] == bridge["stun_tx"]:
            found = stun_parse(data)
            fut = bridge["stun_fut"]
            if found:
                bridge["addr"] = found
                bridge["stun_at"] = time.time()
                if fut and not fut.done():
                    fut.set_result(None)
            return
        t = bridge["transport"]
        if data[0] == 0xFF and data[1:3] == b"CH":
            m = bridge_tokens.get(struct.unpack_from("<I", data, 4)[0])
            if m is None or addr[0] != m.bridge_expect_ip:
                return
            kind = data[3]
            if kind in (1, 2, 3) and m.bridge_addr is None:
                m.bridge_addr = addr
                bridge_addrs[addr] = m
                log.info("peer %d bridged via udp %s:%d", m.id, addr[0], addr[1])
                for _ in range(3):
                    t.sendto(data[:3] + b"\x03" + data[4:8], addr)
            elif kind == 4 and m.bridge_addr == addr:
                t.sendto(data[:8], addr)
        elif data[0] == 0xFE and len(data) >= 9:
            sender = bridge_addrs.get(addr)
            if sender is not None:
                (target,) = struct.unpack_from("<i", data, 1)
                bridge_route(sender, target, data[5:])


def bridge_route(sender, target, rest):
    """rest = u32 seq + payload."""
    head = struct.pack("<i", sender.id)
    for m in list(sender.lobby.members.values()):
        if m is sender or (m.id != target if target > 0 else (target < 0 and m.id == -target)):
            continue
        if m.bridge_addr:
            bridge["transport"].sendto(b"\xFE" + head + rest, m.bridge_addr)
        else:
            m.push(head + rest[4:])


async def bridge_probe(m):
    """Punch towards the client: random ports (it has many sockets) or its exact mapped port."""
    pkt = b"\xFFCH\x02" + struct.pack("<I", m.bridge_token)
    rnd = m.bridge_kind == "random"
    token = m.bridge_token
    for _ in range(300 if rnd else 100):
        if m.bridge_addr or token not in bridge_tokens:
            return
        bridge["transport"].sendto(pkt, (m.bridge_expect_ip, random.randint(1024, 65535) if rnd else m.bridge_port))
        await asyncio.sleep(0.033 if rnd else 0.1)


def bridge_forget(m):
    bridge_tokens.pop(m.bridge_token, None)
    if m.bridge_addr:
        bridge_addrs.pop(m.bridge_addr, None)
        m.bridge_addr = None


async def bridge_start():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    if hasattr(socket, "SIO_UDP_CONNRESET"):
        sock.ioctl(socket.SIO_UDP_CONNRESET, False)  # else ICMP resets from probes kill receiving
    sock.bind(("0.0.0.0", BRIDGE_PORT))
    await asyncio.get_running_loop().create_datagram_endpoint(BridgeProtocol, sock=sock)
    if BRIDGE_TEST:
        bridge["addr"] = ("127.0.0.1", sock.getsockname()[1])
    else:
        await bridge_refresh_stun()
    log.info("UDP bridge on 0.0.0.0:%d (public: %s)", BRIDGE_PORT, bridge["addr"])


async def bridge_request(m, msg):
    try:
        ip = str(ipaddress.IPv4Address(str(msg.get("ip", ""))))
        port = int(msg.get("port", 0))
    except ValueError:
        return
    await bridge_refresh_stun()
    if not bridge["addr"]:
        return
    bridge_forget(m)
    m.bridge_token = secrets.randbits(32)
    m.bridge_expect_ip = ip
    m.bridge_kind = "fixed" if msg.get("kind") == "fixed" else "random"
    m.bridge_port = port
    bridge_tokens[m.bridge_token] = m
    m.push_json({"op": "bridge_open", "ip": bridge["addr"][0], "port": bridge["addr"][1], "token": m.bridge_token})


async def reject(ws, msg):
    # The reason rides on the close frame too: clients may drop queued text once the socket closes.
    await ws.send(json.dumps({"op": "error", "msg": msg}))
    await ws.close(4001, msg)


def route(lobby, sender, target, payload):
    frame = struct.pack("<i", sender.id) + payload
    if target > 0:
        dest = lobby.members.get(target)
        if dest:
            dest.push(frame)
        return
    exclude = -target if target < 0 else 0
    for m in lobby.members.values():
        if m is not sender and m.id != exclude:
            m.push(frame)


async def handler(ws):
    lobby = None
    me = None
    try:
        first = json.loads(await asyncio.wait_for(ws.recv(), timeout=15))
        op = first.get("op")
        if op == "create":
            lobby = Lobby(new_code())
            lobbies[lobby.code] = lobby
            me = Member(ws, 1)
            me.lobby = lobby
            lobby.members[1] = me
            me.push_json({"op": "created", "code": lobby.code, "id": 1})
            log.info("lobby %s created (%d open)", lobby.code, len(lobbies))
        elif op == "join":
            code = str(first.get("code", "")).strip().upper()
            candidate = lobbies.get(code)
            if candidate is None:
                await reject(ws, "Lobby %s not found." % code)
                return
            if candidate.locked:
                await reject(ws, "Lobby %s is not accepting players." % code)
                return
            if len(candidate.members) >= MAX_PLAYERS:
                await reject(ws, "Lobby %s is full (%d/%d)." % (code, MAX_PLAYERS, MAX_PLAYERS))
                return
            lobby = candidate
            me = Member(ws, lobby.next_id)
            me.lobby = lobby
            lobby.next_id += 1
            me.push_json({"op": "joined", "code": lobby.code, "id": me.id, "peers": list(lobby.members.keys())})
            for m in lobby.members.values():
                m.push_json({"op": "peer_connected", "id": me.id})
            lobby.members[me.id] = me
            log.info("peer %d joined %s (%d/%d)", me.id, lobby.code, len(lobby.members), MAX_PLAYERS)
        else:
            await reject(ws, "Expected create or join.")
            return

        async for message in ws:
            if isinstance(message, bytes):
                if len(message) < 4:
                    continue
                (target,) = struct.unpack_from("<i", message)
                route(lobby, me, target, message[4:])
                continue
            msg = json.loads(message)
            if msg.get("op") == "signal":
                dest = lobby.members.get(int(msg.get("to", 0)))
                if dest and dest is not me:
                    dest.push_json({"op": "signal", "from": me.id, "data": msg.get("data")})
                continue
            if msg.get("op") == "bridge":
                await bridge_request(me, msg)
                continue
            if msg.get("op") == "bridge_go":
                if me.bridge_token in bridge_tokens:
                    asyncio.create_task(bridge_probe(me))
                continue
            if me.id != 1:
                continue
            if msg.get("op") == "lock":
                lobby.locked = bool(msg.get("locked"))
            elif msg.get("op") == "kick":
                victim = lobby.members.get(int(msg.get("id", 0)))
                if victim and victim.id != 1:
                    await victim.ws.close(1000, "kicked")
    except (asyncio.TimeoutError, json.JSONDecodeError):
        pass
    except Exception as e:
        log.info("connection ended: %s", e)
    finally:
        if me:
            bridge_forget(me)
        if lobby and me and lobby.members.get(me.id) is me:
            del lobby.members[me.id]
            me.sender.cancel()
            if me.id == 1:
                # Host left: the session is over for everyone.
                lobbies.pop(lobby.code, None)
                for m in list(lobby.members.values()):
                    await m.ws.close(1000, "host left")
                log.info("lobby %s closed (%d open)", lobby.code, len(lobbies))
            else:
                for m in lobby.members.values():
                    m.push_json({"op": "peer_disconnected", "id": me.id})
                log.info("peer %d left %s", me.id, lobby.code)


def health_check(connection, request):
    # Plain HTTP GETs (watchdog, browsers) get a 200 so Funnel health checks pass.
    if request.headers.get("Upgrade", "").lower() != "websocket":
        body = "CyberHorde lobby relay OK - %d open lobbies\n" % len(lobbies)
        return connection.respond(HTTPStatus.OK, body)
    return None


def ensure_tailscale_funnel():
    if "CYBERHORDE_RELAY_PORT" in os.environ:
        return  # test relay on another port: never repoint the public /cyberhorde route
    try:
        subprocess.run(["tailscale", "funnel", "--bg", "--set-path=%s" % FUNNEL_PATH, "http://127.0.0.1:%d" % PORT],
                       capture_output=True, timeout=10)
    except Exception:
        pass


async def main():
    ensure_tailscale_funnel()
    try:
        await bridge_start()
    except OSError as e:
        log.warning("UDP bridge disabled: %s", e)  # lobbies must keep working without it
    async with serve(handler, "127.0.0.1", PORT, process_request=health_check,
                     max_size=MAX_PACKET, ping_interval=20, ping_timeout=20) as server:
        log.info("CyberHorde lobby relay listening on 127.0.0.1:%d (public: wss://phu-ai-lab.tailbca584.ts.net%s)", PORT, FUNNEL_PATH)
        loop = asyncio.get_running_loop()
        stop = loop.create_future()
        for sig in (signal.SIGINT, signal.SIGTERM):
            try:
                loop.add_signal_handler(sig, stop.set_result, None)
            except NotImplementedError:
                pass
        await stop
        server.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
