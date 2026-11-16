"""Converts the villager animation clips of the EmacEArt PRO Unity package into JSON files that
scripts/villager.gd plays on the Godot skeleton.

    python tools/convert_unity_anims.py <pack.unitypackage> [out_dir]

out_dir defaults to asset/characters/anims (asset/ is not in git: the clips are part of the pack).

A .unitypackage is a tar.gz holding one folder per asset (<guid>/pathname, <guid>/asset). The clips
are "generic" ones: a curve of Euler angles (degrees) per bone and a position curve for some bones,
keyed by the bone's path in the hierarchy. Both villager rigs use the same bone names.

Unity mirrors the X axis when it imports an FBX and Godot does not, so a bone's local rotation
(x, y, z, w) in Unity is (x, -y, -z, w) in Godot, and a position (x, y, z) is (-x, y, z).
Unity builds a rotation from Euler angles as Y * X * Z.

Each output file holds:
    {"name", "length" (seconds), "fps", "loop", "frames",
     "rot": {bone: [x, y, z, w, x, y, z, w, ...]},   one quaternion per frame, Godot bone-local
     "pos": {bone: [x, y, z, ...]}}                   one position per frame, Godot bone-local
Bone names have the rig's "Humanoid|" prefix removed.
"""
import json
import math
import os
import re
import sys
import tarfile

FPS = 30
PREFIX = "Humanoid|"
VEC = re.compile(r"\{x: (\S+), y: (\S+), z: (\S+)\}")


def read_clips(package):
    """{clip file name: text} for every .anim in the package."""
    names = {}
    with tarfile.open(package, "r:gz") as tar:
        for member in tar:
            parts = member.name.strip("./").split("/")
            if len(parts) == 2 and parts[1] == "pathname":
                names[parts[0]] = tar.extractfile(member).read().decode("utf-8", "replace").splitlines()[0].strip()
    wanted = {guid: path for guid, path in names.items() if path.lower().endswith(".anim")}
    clips = {}
    with tarfile.open(package, "r:gz") as tar:
        for member in tar:
            parts = member.name.strip("./").split("/")
            if len(parts) == 2 and parts[1] == "asset" and parts[0] in wanted:
                clips[os.path.basename(wanted[parts[0]])] = tar.extractfile(member).read().decode("utf-8", "replace")
    return clips


def number(text):
    text = text.strip().rstrip(",")
    if text in ("Infinity", "inf"):
        return math.inf
    if text in ("-Infinity", "-inf"):
        return -math.inf
    return float(text)


def vector(line):
    m = VEC.search(line)
    return tuple(number(g) for g in m.groups())


def parse(text):
    """Returns (settings, euler, position): the curve dicts map a bone name to its keys,
    each key (time, value xyz, in slope xyz, out slope xyz)."""
    settings = {"length": 0.0, "loop": False, "name": ""}
    curves = {"m_EulerCurves": {}, "m_PositionCurves": {}}
    section = ""
    keys = None
    key = None
    for line in text.splitlines():
        top = re.match(r"^  (m_\w+):", line)
        if top:
            section = top.group(1)
            keys = None
            if section == "m_Name":
                settings["name"] = line.split(":", 1)[1].strip()
            continue
        if section == "m_AnimationClipSettings":
            if "m_StopTime:" in line:
                settings["length"] = number(line.split(":", 1)[1])
            elif "m_LoopTime:" in line:
                settings["loop"] = line.split(":", 1)[1].strip() == "1"
            continue
        if section not in curves:
            continue
        if line.startswith("  - curve:"):
            keys = []
        elif keys is None:
            continue
        elif line.startswith("        time:"):
            key = [number(line.split(":", 1)[1]), None, None, None]
            keys.append(key)
        elif line.startswith("        value:"):
            key[1] = vector(line)
        elif line.startswith("        inSlope:"):
            key[2] = vector(line)
        elif line.startswith("        outSlope:"):
            key[3] = vector(line)
        elif line.startswith("    path:"):
            bone = line.split(":", 1)[1].strip().split("/")[-1]
            if bone.startswith(PREFIX):
                curves[section][bone[len(PREFIX):]] = keys
            keys = None
    return settings, curves["m_EulerCurves"], curves["m_PositionCurves"]


def sample(keys, t):
    """Value of a curve at time t: Unity's cubic Hermite between the two keys around t."""
    if t <= keys[0][0]:
        return keys[0][1]
    if t >= keys[-1][0]:
        return keys[-1][1]
    lo, hi = 0, len(keys) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if keys[mid][0] <= t:
            lo = mid
        else:
            hi = mid
    k0, k1 = keys[lo], keys[hi]
    dt = k1[0] - k0[0]
    s = (t - k0[0]) / dt
    out = []
    for c in range(3):
        m0, m1 = k0[3][c], k1[2][c]
        if math.isinf(m0) or math.isinf(m1):  # a stepped key holds its value
            out.append(k0[1][c])
            continue
        h00 = 2 * s ** 3 - 3 * s ** 2 + 1
        h10 = s ** 3 - 2 * s ** 2 + s
        h01 = -2 * s ** 3 + 3 * s ** 2
        h11 = s ** 3 - s ** 2
        out.append(h00 * k0[1][c] + h10 * dt * m0 + h01 * k1[1][c] + h11 * dt * m1)
    return tuple(out)


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz)


def unity_euler(deg):
    """Unity's Quaternion.Euler: about Z, then X, then Y."""
    hx, hy, hz = (math.radians(a) / 2 for a in deg)
    qx = (math.sin(hx), 0.0, 0.0, math.cos(hx))
    qy = (0.0, math.sin(hy), 0.0, math.cos(hy))
    qz = (0.0, 0.0, math.sin(hz), math.cos(hz))
    return quat_mul(quat_mul(qy, qx), qz)


def to_godot_rotation(q):
    return (q[0], -q[1], -q[2], q[3])


def to_godot_position(p):
    return (-p[0], p[1], p[2])


def convert(text):
    settings, euler, position = parse(text)
    last = 0.0
    for keys in list(euler.values()) + list(position.values()):
        if keys:
            last = max(last, keys[-1][0])
    length = settings["length"] or last
    frames = max(2, int(round(length * FPS)) + 1)
    times = [length * i / (frames - 1) for i in range(frames)]
    rot = {}
    for bone, keys in euler.items():
        if not keys:
            continue
        flat = []
        before = None
        for t in times:
            q = to_godot_rotation(unity_euler(sample(keys, t)))
            # Keep neighbours on the same side, so blending between frames takes the short way.
            if before is not None and sum(a * b for a, b in zip(q, before)) < 0:
                q = tuple(-c for c in q)
            before = q
            flat.extend(round(c, 5) for c in q)
        rot[bone] = flat
    pos = {}
    for bone, keys in position.items():
        if not keys:
            continue
        flat = []
        for t in times:
            flat.extend(round(c, 5) for c in to_godot_position(sample(keys, t)))
        pos[bone] = flat
    return {"name": settings["name"], "length": round(length, 4), "fps": FPS, "loop": settings["loop"],
            "frames": frames, "rot": rot, "pos": pos}


def file_name(clip_name):
    """villager_male_idle1.json, female_villager_walk.json, ..."""
    return re.sub(r"[^a-z0-9]+", "_", clip_name.lower()).strip("_") + ".json"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    out_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.join("asset", "characters", "anims")
    os.makedirs(out_dir, exist_ok=True)
    done = 0
    for name, text in sorted(read_clips(sys.argv[1]).items()):
        clip = convert(text)
        if not clip["rot"]:
            print("skipped (no bone curves):", name)
            continue
        path = os.path.join(out_dir, file_name(os.path.splitext(name)[0]))
        with open(path, "w", encoding="utf-8") as f:
            json.dump(clip, f, separators=(",", ":"))
        done += 1
        print("%-34s %5.2fs %3d frames %2d bones %s" % (os.path.basename(path), clip["length"], clip["frames"],
                                                        len(clip["rot"]), "loop" if clip["loop"] else ""))
    print(done, "clips ->", out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
