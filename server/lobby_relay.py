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
                                             <- {"op":"peer_connected","id":N}
                                             <- {"op":"peer_disconnected","id":N}
                                             <- {"op":"error","msg":".."}  (then closed, reason = msg)
  binary frames = game packets
    -> int32 LE target (0 = all, >0 = peer, <0 = all except -target) + payload
    <- int32 LE source peer id + payload
"""

import asyncio
import json
import logging
import os
import secrets
import signal
import struct
import subprocess
import sys
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
    try:
        subprocess.run(["tailscale", "funnel", "--bg", "--set-path=%s" % FUNNEL_PATH, "http://127.0.0.1:%d" % PORT],
                       capture_output=True, timeout=10)
    except Exception:
        pass


async def main():
    ensure_tailscale_funnel()
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
