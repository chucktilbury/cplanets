"""Minimal Phase E/F envelope codec for Python functional tests."""

from __future__ import annotations


def _u8(value: int) -> bytes:
    return bytes((value & 0xFF,))


def _u16(value: int) -> bytes:
    return (value & 0xFFFF).to_bytes(2, "little")


def _u32(value: int) -> bytes:
    return (value & 0xFFFFFFFF).to_bytes(4, "little")


def compress_store(raw: bytes) -> bytes:
    """STORE codec (0) — always valid, no RLE required."""
    return _u8(0) + raw


def encode_envelope(verb: int, path: str, body: bytes) -> bytes:
    path_bytes = path.encode("utf-8")
    blob = compress_store(body)
    return (
        _u8(1)
        + _u8(verb)
        + _u16(len(path_bytes))
        + path_bytes
        + _u32(len(blob))
        + blob
    )


def put_policy(player_id: int, policy: bytes) -> bytes:
    body = _u32(player_id) + _u32(len(policy)) + policy
    return encode_envelope(2, "/policy", body)


def get_state(player_id: int, since_tick: int = 0) -> bytes:
    body = _u32(player_id) + _u32(since_tick)
    return encode_envelope(1, "/state", body)


def get_digest(player_id: int, since_tick: int = 0) -> bytes:
    body = _u32(player_id) + _u32(since_tick)
    return encode_envelope(1, "/digest", body)


def admin_advance(count: int) -> bytes:
    return encode_envelope(2, "/admin/advance", _u32(count))


def handshake(player_id: int) -> bytes:
    return encode_envelope(2, "/handshake", _u32(player_id))


def put_suspended(player_id: int, flag: bool) -> bytes:
    """PUT /suspended: playerId u32 + flag u8 (intentional AFK hold)."""
    return encode_envelope(
        2, "/suspended", _u32(player_id) + _u8(1 if flag else 0)
    )


def put_pause(flag: bool) -> bytes:
    return encode_envelope(2, "/pause", _u8(1 if flag else 0))


def put_order(
    player_id: int, fleet_id: int, dest_planet_id: int, order: str
) -> bytes:
    order_bytes = order.encode("utf-8")
    body = (
        _u32(player_id)
        + _u32(fleet_id)
        + _u32(dest_planet_id)
        + _u16(len(order_bytes))
        + order_bytes
    )
    return encode_envelope(2, "/order", body)


def put_recall(player_id: int, fleet_id: int) -> bytes:
    return encode_envelope(2, "/recall", _u32(player_id) + _u32(fleet_id))


def _string(text: str) -> bytes:
    raw = text.encode("utf-8")
    return _u16(len(raw)) + raw


def put_design(
    player_id: int,
    name: str,
    speed: str,
    hop: str,
    size: str,
    cargo: str,
    kind: str,
) -> bytes:
    body = (
        _u32(player_id)
        + _string(name)
        + _string(speed)
        + _string(hop)
        + _string(size)
        + _string(cargo)
        + _string(kind)
    )
    return encode_envelope(2, "/design", body)


def put_build(player_id: int, planet_id: int, design_id: int) -> bytes:
    body = _u32(player_id) + _u32(planet_id) + _u32(design_id)
    return encode_envelope(2, "/build", body)


def put_reclaim_hulls(
    player_id: int, fleet_id: int, hulls: int
) -> bytes:
    body = _u32(player_id) + _u32(fleet_id) + _u32(hulls)
    return encode_envelope(2, "/reclaim-hulls", body)


def decompress_store(blob: bytes) -> bytes:
    if not blob:
        raise ValueError("empty compress blob")
    codec = blob[0]
    payload = blob[1:]
    if codec == 0:
        return payload
    if codec != 1:
        raise ValueError(f"unsupported codec {codec}")
    out = bytearray()
    i = 0
    while i + 1 < len(payload):
        count = payload[i]
        value = payload[i + 1]
        out.extend([value] * count)
        i += 2
    return bytes(out)


def decode_envelope(frame: bytes) -> tuple[int, int, str, bytes]:
    if len(frame) < 5:
        raise ValueError("truncated envelope")
    version = frame[0]
    verb = frame[1]
    path_len = int.from_bytes(frame[2:4], "little")
    path_end = 4 + path_len
    path = frame[4:path_end].decode("utf-8")
    body_len = int.from_bytes(frame[path_end : path_end + 4], "little")
    blob = frame[path_end + 4 : path_end + 4 + body_len]
    if version != 1:
        raise ValueError(f"bad version {version}")
    body = decompress_store(blob)
    return version, verb, path, body
