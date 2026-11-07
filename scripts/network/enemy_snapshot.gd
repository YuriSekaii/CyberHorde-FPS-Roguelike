extends RefCounted

# Max enemies per snapshot chunk: 96 * 11 bytes = 1056 bytes, safe for UDP/bridge.
const PER_CHUNK := 96
const ENTRY_BYTES := 11

# Encodes [[hash:int, pos:Vector3, yaw:float], ...] into PackedByteArray chunks of
# at most PER_CHUNK entries each. Wire format per entry (11 bytes):
#   s32 hash, half float pos.x, half float pos.y, half float pos.z, u8 yaw (yaw / TAU * 256)
static func encode(entries: Array) -> Array:
	var chunks: Array = []
	var chunk := PackedByteArray()
	var count := 0
	for entry in entries:
		chunk.resize(chunk.size() + ENTRY_BYTES)
		var o := chunk.size() - ENTRY_BYTES
		chunk.encode_s32(o, int(entry[0]))
		chunk.encode_half(o + 4, entry[1].x)
		chunk.encode_half(o + 6, entry[1].y)
		chunk.encode_half(o + 8, entry[1].z)
		chunk.encode_u8(o + 10, int(roundf(wrapf(float(entry[2]), 0.0, TAU) / TAU * 256.0)) & 255)
		count += 1
		if count >= PER_CHUNK:
			chunks.append(chunk)
			chunk = PackedByteArray()
			count = 0
	if chunk.size() > 0:
		chunks.append(chunk)
	return chunks

# Decodes one chunk (see encode) into [[hash, pos, yaw], ...].
static func decode(data: PackedByteArray) -> Array:
	var out: Array = []
	var o := 0
	while o + ENTRY_BYTES <= data.size():
		var hash := data.decode_s32(o)
		var pos := Vector3(data.decode_half(o + 4), data.decode_half(o + 6), data.decode_half(o + 8))
		var yaw := data.decode_u8(o + 10) * TAU / 256.0
		out.append([hash, pos, yaw])
		o += ENTRY_BYTES
	return out
