class_name Villager
extends Node3D
## A village NPC built from the Slavic villager FBX (res://asset/characters).
## The FBX has a skeleton but no animations. The idle pose comes from a clip converted from the
## pack's Unity animations (tools/convert_unity_anims.py -> asset/characters/anims/*.json); the
## reactions are added from code: a nod while talking, a hop when happy, a head shake when sad.
## Without the clip files (asset/ is not in git) the whole pose is set from code: arms lowered
## from the bind pose and a gentle sway.
## Bone rotation axes are found at setup by measuring where the bones move, so the code does not
## depend on how the rig's local axes happen to be oriented.

const MODELS: Dictionary = {
	"male": "res://asset/characters/EA_C_Villager_Male.fbx",
	"female": "res://asset/characters/EA_C_Peasant_Female.fbx",
}
const PALETTES: Dictionary = {
	"male": ["res://asset/characters/EA_Character_Male_Villager_palette.png", "res://asset/characters/EA_Items_Male_Villager_Palette.png"],
	"female": ["res://asset/characters/EA_Character_Female_Villager_palette.png", "res://asset/characters/EA_Items_Female_Villager_Palette.png"],
}
## Meshes that every outfit shows.
const ALWAYS: PackedStringArray = ["head", "eyes", "teeth", "corpse"]
const HEIGHT: float = 1.75
const B: String = "Humanoid|"
const CLIP_DIR: String = "res://asset/characters/anims/"
## Idle clips; a look picks one with "clip", otherwise its parts decide (the same villager always
## gets the same one). Both rigs share bone names and rest pose, so the male clips fit the female.
const IDLE_CLIPS: PackedStringArray = ["villager_male_idle1", "villager_male_idle2", "villager_male_idle3"]
## Radians the arms swing down from the bind T-pose when no clip poses them.
const ARM_DROP: float = 1.25

enum Mood { IDLE, TALK, HAPPY, SAD }

var _model: Node3D
var _skel: Skeleton3D
var _bones: Dictionary = {}  # short name -> bone index
var _rest: Dictionary = {}  # bone index -> rest Quaternion
var _axes: Dictionary = {}  # "arm_l", "arm_r", "nod", "shake", "lean" -> local axis (Vector3)
var _mood: int = Mood.IDLE
var _mood_time: float = 0.0
var _time: float = 0.0
var _base_y: float = 0.0
var _materials: Dictionary = {}
var _clip: Dictionary = {}  # the idle clip being played, see load_clip(); {} = pose from code only
var _pose: Dictionary = {}  # bone index -> Quaternion the clip gave this frame

static var _clips: Dictionary = {}  # clip name -> loaded clip ({} when the file is missing)


## look = {"model": "male"|"female", "parts": ["Hair_01a", "Vest_01a", ...], "item": "I_Villager_Hammer_01a"}
## Part names may omit the "Villager_Male_" / "Villager_Female_" prefix.
func setup(look: Dictionary) -> void:
	if _model:
		_model.queue_free()
	var kind: String = look.get("model", "male")
	_model = (load(MODELS[kind]) as PackedScene).instantiate()
	add_child(_model)
	_skel = _model.find_children("*", "Skeleton3D", true, false)[0]
	var wanted := {}
	for p in look.get("parts", []):
		wanted[p] = true
	var item: String = look.get("item", "")
	var prefix := "Villager_Male_" if kind == "male" else "Villager_Female_"
	for mi in _skel.find_children("*", "MeshInstance3D", false, false):
		var mesh := mi as MeshInstance3D
		var n := String(mesh.name)
		mesh.visible = n in ALWAYS or wanted.has(n) or wanted.has(n.trim_prefix(prefix)) or n == item
		mesh.material_override = _palette_material(PALETTES[kind][1 if n.begins_with("I_") else 0])
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_find_bones()
	_learn_axes()
	_fit_to_height()
	var parts: Array = look.get("parts", [])
	_clip = load_clip(look.get("clip", IDLE_CLIPS[hash(str(parts)) % IDLE_CLIPS.size()]))
	_apply_pose(0.0)


func say_mood(mood: int, duration: float = 2.0) -> void:
	_mood = mood
	_mood_time = duration


## Talking gestures while a bubble is typing; does not cut a happy or sad reaction short.
func talk(on: bool) -> void:
	if on and (_mood == Mood.IDLE or _mood == Mood.TALK):
		say_mood(Mood.TALK, 60.0)
	elif not on and _mood == Mood.TALK:
		say_mood(Mood.IDLE, 0.0)


## Head position in world space, for placing the speech bubble.
func head_position() -> Vector3:
	if _skel == null or not _bones.has("head"):
		return global_position + Vector3(0, HEIGHT, 0)
	var p := _skel.global_transform * _global_pose(_bones["head"]).origin
	return p + Vector3(0, 0.35 * global_transform.basis.get_scale().y, 0)


func _process(delta: float) -> void:
	if _skel == null:
		return
	_time += delta
	if _mood != Mood.IDLE:
		_mood_time -= delta
		if _mood_time <= 0.0:
			_mood = Mood.IDLE
	_apply_pose(delta)


# --- Pose -------------------------------------------------------------------

## A converted clip by name: {"length", "frames", "rot": {bone: PackedFloat32Array of x, y, z, w per
## frame}, "pos": {bone: PackedFloat32Array of x, y, z per frame}}, or {} when the file is missing.
static func load_clip(clip_name: String) -> Dictionary:
	if _clips.has(clip_name):
		return _clips[clip_name]
	var clip := {}
	var path := CLIP_DIR + clip_name + ".json"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and int(data.get("frames", 0)) >= 2:
			clip = {"length": float(data["length"]), "frames": int(data["frames"]), "rot": {}, "pos": {}}
			for track in ["rot", "pos"]:
				for bone in data.get(track, {}):
					clip[track][bone] = PackedFloat32Array(data[track][bone])
	_clips[clip_name] = clip
	return clip


## Poses the bones from the clip at time t (looping), blending between its two nearest frames.
func _play_clip(t: float) -> void:
	_pose.clear()
	var frames: int = _clip["frames"]
	var at := fposmod(t, _clip["length"]) / float(_clip["length"]) * (frames - 1)
	var a := mini(int(at), frames - 2)
	var w := at - a
	var rot: Dictionary = _clip["rot"]
	for bone in rot:
		if not _bones.has(bone):
			continue
		var d: PackedFloat32Array = rot[bone]
		var q0 := Quaternion(d[a * 4], d[a * 4 + 1], d[a * 4 + 2], d[a * 4 + 3])
		var q1 := Quaternion(d[a * 4 + 4], d[a * 4 + 5], d[a * 4 + 6], d[a * 4 + 7])
		var q := q0.normalized().slerp(q1.normalized(), w)
		_pose[_bones[bone]] = q
		_skel.set_bone_pose_rotation(_bones[bone], q)
	var pos: Dictionary = _clip["pos"]
	for bone in pos:
		# The hips stay where the rig put them: some clips were made around another root height
		# (idle2 has the hips 0.8 m lower), and a villager stands on its own spot anyway.
		if bone == "hips" or not _bones.has(bone):
			continue
		var p: PackedFloat32Array = pos[bone]
		var p0 := Vector3(p[a * 3], p[a * 3 + 1], p[a * 3 + 2])
		var p1 := Vector3(p[a * 3 + 3], p[a * 3 + 4], p[a * 3 + 5])
		_skel.set_bone_pose_position(_bones[bone], p0.lerp(p1, w))


func _apply_pose(_delta: float) -> void:
	var t := _time
	var clip := not _clip.is_empty()
	if clip:
		_play_clip(t)
	var nod := 0.0
	var shake := 0.0
	var lean := 0.0 if clip else sin(t * 1.3) * 0.03
	# With a clip the arms are already down: the angles below are then added to its pose.
	var down := 0.0 if clip else ARM_DROP
	var drop_l := down
	var drop_r := down
	var arms_up := false
	var hop := 0.0
	match _mood:
		Mood.TALK:
			nod = sin(t * 7.0) * 0.12
			drop_r = down - 0.25 + sin(t * 3.5) * 0.12  # small hand gesture
		Mood.HAPPY:
			hop = absf(sin(t * 8.0)) * 0.18
			arms_up = true
			drop_l = -0.9 + sin(t * 10.0) * 0.25  # both arms up, waving: measured from the T-pose
			drop_r = -0.9 - sin(t * 10.0) * 0.25
			nod = -0.15
		Mood.SAD:
			shake = sin(t * 9.0) * 0.35
			nod = 0.25
	_rot("head", "nod", nod, "shake", shake)
	_rot("spine", "lean", lean)
	_rot("upper_arm.L", "arm_l", drop_l, "", 0.0, arms_up)
	_rot("upper_arm.R", "arm_r", drop_r, "", 0.0, arms_up)
	if arms_up and clip:
		# The clip bends the elbows for arms that hang down; straighten them for the wave.
		for bone in ["forearm.L", "forearm.R"]:
			if _bones.has(bone):
				_skel.set_bone_pose_rotation(_bones[bone], _rest[_bones[bone]])
	_model.position.y = _base_y + hop


## Turns a bone by angle_a about a learned axis (and angle_b about a second one), starting from
## the clip's pose for that bone, or from its rest pose when there is none or `from_rest` is set.
func _rot(bone: String, axis_a: String, angle_a: float, axis_b: String = "", angle_b: float = 0.0, from_rest: bool = false) -> void:
	if not _bones.has(bone) or not _axes.has(axis_a):
		return
	var i: int = _bones[bone]
	var start: Quaternion = _rest[i] if from_rest else _pose.get(i, _rest[i])
	var q: Quaternion = start * Quaternion(_axes[axis_a], angle_a)
	if axis_b != "" and _axes.has(axis_b):
		q = q * Quaternion(_axes[axis_b], angle_b)
	_skel.set_bone_pose_rotation(i, q)


func _find_bones() -> void:
	_bones.clear()
	_rest.clear()
	for i in _skel.get_bone_count():
		var short := _skel.get_bone_name(i).trim_prefix(B)
		_bones[short] = i
		_rest[i] = _skel.get_bone_rest(i).basis.get_rotation_quaternion()
		_skel.set_bone_pose_rotation(i, _rest[i])


## Tries rotations about each local axis and keeps the one that moves a probe bone the right way.
func _learn_axes() -> void:
	_axes.clear()
	_axes["arm_l"] = _best_axis("upper_arm.L", "hand.L", func(p: Vector3) -> float: return -p.y)
	_axes["arm_r"] = _best_axis("upper_arm.R", "hand.R", func(p: Vector3) -> float: return -p.y)
	_axes["nod"] = _best_axis("head", "eye.L", func(p: Vector3) -> float: return -p.y)
	var fwd := _forward()
	_axes["lean"] = _best_axis("spine", "head", func(p: Vector3) -> float: return p.dot(fwd))
	# Shake turns the head sideways: the axis that moves the eyes most while keeping them level.
	var side := fwd.cross(Vector3.UP)
	_axes["shake"] = _best_axis("head", "eye.L", func(p: Vector3) -> float: return absf(p.dot(side)) - absf(p.y) * 4.0, 0.3)
	# Face the model toward +Z inside the villager node, so rotation.y of the villager is its heading.
	_model.rotation.y = -atan2(fwd.x, fwd.z)


func _best_axis(bone: String, probe: String, score: Callable, angle: float = 0.6) -> Vector3:
	if not _bones.has(bone) or not _bones.has(probe):
		return Vector3.RIGHT
	var i: int = _bones[bone]
	var j: int = _bones[probe]
	var base := _bone_pos(j)
	var best := Vector3.RIGHT
	var best_score := -INF
	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		_skel.set_bone_pose_rotation(i, _rest[i] * Quaternion(axis, angle))
		var moved := _bone_pos(j) - base
		var s: float = score.call(moved)
		if s > best_score:
			best_score = s
			best = axis
	_skel.set_bone_pose_rotation(i, _rest[i])
	return best


## Bone position in model-root space (y is up there; the FBX skeleton itself is z-up).
func _bone_pos(i: int) -> Vector3:
	return _skel_to_model() * _global_pose(i).origin


## Skeleton-space bone transform computed from the local poses. Skeleton3D's own global pose
## cache only refreshes once the node has processed a frame, which is too late for setup().
func _global_pose(i: int) -> Transform3D:
	var xf := _skel.get_bone_pose(i)
	var p := _skel.get_bone_parent(i)
	while p >= 0:
		xf = _skel.get_bone_pose(p) * xf
		p = _skel.get_bone_parent(p)
	return xf


## Direction the face points, in model-root space (eyes in front of the head bone).
func _forward() -> Vector3:
	if not (_bones.has("head") and _bones.has("eye.L") and _bones.has("eye.R")):
		return Vector3.BACK
	var head := _bone_pos(_bones["head"])
	var eyes := (_bone_pos(_bones["eye.L"]) + _bone_pos(_bones["eye.R"])) * 0.5
	var f := eyes - head
	f.y = 0.0
	return f.normalized() if f.length() > 0.0001 else Vector3.BACK


## Scales the model so the head top is at HEIGHT and the feet stand on y = 0.
func _fit_to_height() -> void:
	_model.scale = Vector3.ONE
	var to_model := _skel_to_model()
	var low := INF
	var high := -INF
	for k in ["toe.L", "toe.R", "foot.L", "foot.R", "head"]:
		if _bones.has(k):
			var y := (to_model * _global_pose(_bones[k]).origin).y
			low = minf(low, y)
			high = maxf(high, y)
	if high <= low:
		return
	# The head bone sits around the ears; the crown is roughly 12% of the body height above it.
	var s := HEIGHT / ((high - low) * 1.12)
	_model.scale = Vector3.ONE * s
	_base_y = -low * s
	_model.position.y = _base_y


## Skeleton space -> model-root space (the FBX puts a unit-scale node in between), ignoring the
## model root's own transform.
func _skel_to_model() -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = _skel
	while n != null and n != _model:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _palette_material(path: String) -> StandardMaterial3D:
	if _materials.has(path):
		return _materials[path]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[path] = mat
	return mat
