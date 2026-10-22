class_name Board
extends Node3D
## Builds the 3D village board for a GridWorld from the glb assets in res://asset/glb/glb/.
## Every model is auto-fitted to a footprint, so asset scale and pivot quirks do not matter.

const CELL: float = 2.0
const ASSET_DIR: String = "res://asset/glb/glb/"

const PATH_TILE: String = "EA03_Environment_Road_Cobble_01b"
const APPLE: String = "EA03_Items_House_Apple_01a"
## Model, footprint and floor-mark color for each item kind (GridWorld.ITEM_LETTERS).
const ITEMS: Dictionary = {
	"apple": ["EA03_Items_House_Apple_01a", 0.8, Color(1.0, 0.55, 0.4)],
	"carrot": ["EA03_Items_House_Carrot_01a", 0.9, Color(1.0, 0.7, 0.25)],
	"corn": ["EA03_Items_House_Corn_01a", 0.9, Color(1.0, 0.92, 0.35)],
}
const GOAL_BASKET: String = "EA03_Prop_Vegetable_Basket_02"

## [asset name, footprint in meters] used on blocked cells.
const BLOCKERS: Array = [
	["EA03_Nature_Bush_03a", 1.9],
	["EA03_Nature_Bush_03c", 1.6],
	["EA03_Nature_Bush_04a", 1.9],
	["EA03_Nature_Bush_03b", 1.8],
	["EA03_Prop_Container_Barrel_01d", 0.9],
	["EA03_Prop_Container_Crate_02a", 1.2],
	["EA03_Environment_Rock_Head_01c", 1.7],
	["EA03_Environment_Rock_Head_01b", 1.4],
	["EA03_Prop_Tool_Stump_02a", 1.0],
]
const TREES: PackedStringArray = [
	"EA03_Nature_Tree_01b", "EA03_Nature_Tree_02b", "EA03_Nature_Tree_02c",
	"EA03_Nature_Tree_03b", "EA03_Nature_Tree_03c", "EA03_Nature_Tree_06b",
]
const DOOR: String = "EA03_Fence_WallGate_01a"
const SIGN: String = "res://asset/props/EA03_Prop_Sign_RoadDirect_01a.fbx"
const HORSE: String = "res://asset/props/EA_Animal_Horse_01a.fbx"
const PROP_PALETTE: String = "res://asset/glb/glb/EA03_Items_House_Apple_01a_EA03_FREE_Slavica.png"
const GRASS_SHADER: Shader = preload("res://shaders/EA_GrassWind.gdshader")
const TUFTS: PackedStringArray = ["EA03_Plant_Grass_01c", "EA03_Plant_Grass_01d", "EA03_Plant_Grass_01e"]

## Height of the walkable surface (top of the path tiles).
var floor_y: float = 0.2

var _origin: Vector3 = Vector3.ZERO
var _apples: Dictionary = {}  # Vector2i -> Node3D
var _apple_marks: Dictionary = {}  # Vector2i -> MeshInstance3D, glowing disc under each apple
var _mark_materials: Dictionary = {}  # kind -> glowing floor-mark material
var _goal_fxs: Array[Node3D] = []
var _doors: Dictionary = {}  # Vector2i -> door model while closed
var _horses: Array[Node3D] = []
var _scene_cache: Dictionary = {}
var _wind_materials: Dictionary = {}  # palette texture + model height -> grass ShaderMaterial
static var _palette_materials: Dictionary = {}  # Texture2D -> StandardMaterial3D
var _dirt_material: StandardMaterial3D = _flat_material(Color(0.5, 0.39, 0.26))
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0


func build(world: GridWorld) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_apples.clear()
	_apple_marks.clear()
	_goal_fxs.clear()
	_doors.clear()
	_horses.clear()
	_rng.seed = world.width * 7919 + world.height * 104729
	_origin = Vector3(-(world.width - 1) * CELL * 0.5, 0.0, -(world.height - 1) * CELL * 0.5)

	_add_ground(world)
	for y in world.height:
		for x in world.width:
			var p := Vector2i(x, y)
			if world.cell(p) == "I":
				_add_sign(p)
			elif world.is_walkable(p) or world.doors.has(p):
				_add_path_tile(p)
			else:
				_add_blocker(p)
	for p in world.apples:
		_add_apple(p, world.apples[p])
	for g in world.goals:
		_add_goal(g)
	_add_doors(world)
	_add_horses(world)
	_add_surroundings(world)


func cell_to_world(p: Vector2i) -> Vector3:
	return _origin + Vector3(p.x * CELL, 0.0, p.y * CELL)


## Position on top of the path surface, where the robot and items stand.
func surface(p: Vector2i) -> Vector3:
	return cell_to_world(p) + Vector3(0.0, floor_y, 0.0)


## Puts the apples back for a reset, without rebuilding the rest of the board.
func reset_items(world: GridWorld) -> void:
	for p in _apples:
		_apples[p].queue_free()
	for p in _apple_marks:
		_apple_marks[p].queue_free()
	_apples.clear()
	_apple_marks.clear()
	for p in world.apples:
		_add_apple(p, world.apples[p])
	_add_doors(world)
	_add_horses(world)


## Gate models for closed doors. Rebuilds them all (so a reset closes opened doors again).
func _add_doors(world: GridWorld) -> void:
	for p in _doors:
		_doors[p].queue_free()
	_doors.clear()
	for p in world.doors:
		var gate := _spawn(DOOR, cell_to_world(p), CELL * 0.95, PI * 0.5 if world.cell(p + Vector2i(0, -1)) == "#" else 0.0)
		gate.name = "Door_%d_%d" % [p.x, p.y]
		_doors[p] = gate


## The door at p sinks into the ground and disappears.
func open_door(p: Vector2i) -> void:
	var gate: Node3D = _doors.get(p)
	if gate == null:
		return
	_doors.erase(p)
	var tw := create_tween()
	tw.tween_property(gate, "position:y", gate.position.y - 2.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(gate.queue_free)


func _add_sign(p: Vector2i) -> void:
	_add_blocker_ground(p)
	_spawn(SIGN, cell_to_world(p), 1.4, PI * 0.25)


func _add_blocker_ground(p: Vector2i) -> void:
	if _rng.randf() < 0.6:
		var tuft := TUFTS[_rng.randi() % TUFTS.size()]
		_spawn_grass(tuft, cell_to_world(p) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6)), 0.7, _rng.randf() * TAU)


func _add_horses(world: GridWorld) -> void:
	for h in _horses:
		h.queue_free()
	_horses.clear()
	for i in world.horses.size():
		var horse := _spawn(HORSE, surface(world.horses[i]), 1.8, _yaw_for(world.horse_dirs[i]))
		horse.name = "Horse%d" % i
		_horses.append(horse)


## Slides every horse to its new cell in `dur` seconds, turning to face where it walks.
func move_horses(world: GridWorld, dur: float) -> void:
	for i in mini(_horses.size(), world.horses.size()):
		var horse := _horses[i]
		var tw := create_tween().set_parallel(true)
		tw.tween_property(horse, "position", surface(world.horses[i]), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(horse, "rotation:y", _yaw_for(world.horse_dirs[i]), dur * 0.4)


## The horse model's head points along +Z, so yaw for a grid direction (N, E, S, W).
static func _yaw_for(dir: int) -> float:
	var d: Vector2i = GridWorld.DIRS[dir]
	return atan2(float(d.x), float(d.y))


func collect_apple(p: Vector2i) -> void:
	var mark: Node3D = _apple_marks.get(p)
	if mark:
		_apple_marks.erase(p)
		var fade := create_tween()
		fade.tween_property(mark, "scale", Vector3.ONE * 0.01, 0.3)
		fade.tween_callback(mark.queue_free)
	var apple: Node3D = _apples.get(p)
	if apple == null:
		return
	_apples.erase(p)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(apple, "position:y", apple.position.y + 1.6, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(apple, "scale", Vector3.ONE * 0.01, 0.4).set_delay(0.1)
	tw.chain().tween_callback(apple.queue_free)


func _process(delta: float) -> void:
	_time += delta
	for p in _apples:
		var apple: Node3D = _apples[p]
		apple.rotation.y += delta * 1.2
		apple.position.y = floor_y + 0.3 + sin(_time * 2.5 + p.x) * 0.08
	for fx in _goal_fxs:
		fx.rotation.y += delta * 0.8
		var pulse := 1.0 + sin(_time * 3.0) * 0.06
		fx.scale = Vector3(pulse, 1.0, pulse)


# --- Building blocks ------------------------------------------------------

func _add_ground(world: GridWorld) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 220)
	ground.mesh = plane
	ground.material_override = _flat_material(Color(0.36, 0.5, 0.23))
	ground.name = "Ground"
	add_child(ground)

	# Darker earth patch under the board so the puzzle area reads clearly.
	var patch := MeshInstance3D.new()
	var patch_mesh := PlaneMesh.new()
	patch_mesh.size = Vector2(world.width * CELL + 1.0, world.height * CELL + 1.0)
	patch.mesh = patch_mesh
	patch.material_override = _flat_material(Color(0.3, 0.38, 0.18))
	patch.position.y = 0.01
	patch.name = "BoardPatch"
	add_child(patch)


func _add_path_tile(p: Vector2i) -> void:
	var holder := Node3D.new()
	holder.name = "Tile_%d_%d" % [p.x, p.y]
	holder.position = cell_to_world(p)
	holder.rotation.y = _rng.randi_range(0, 3) * PI * 0.5
	add_child(holder)
	# Warm dirt under the stones so the path reads clearly against the grass.
	var dirt := MeshInstance3D.new()
	var dirt_mesh := PlaneMesh.new()
	dirt_mesh.size = Vector2(CELL, CELL)
	dirt.mesh = dirt_mesh
	dirt.material_override = _dirt_material
	dirt.position.y = 0.03
	holder.add_child(dirt)
	var model := _instance(PATH_TILE)
	holder.add_child(model)
	var box := _local_aabb(model)
	var flatten := 0.55
	model.scale = Vector3(CELL * 0.99 / box.size.x, flatten, CELL * 0.99 / box.size.z)
	var center := box.get_center()
	var bottom := -0.12
	model.position = Vector3(-center.x * model.scale.x, bottom - box.position.y * flatten, -center.z * model.scale.z)
	floor_y = bottom + box.size.y * flatten * 0.85


func _add_blocker(p: Vector2i) -> void:
	var pick: Array = BLOCKERS[_rng.randi() % BLOCKERS.size()]
	var jitter := Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.2, 0.2))
	_spawn(pick[0], cell_to_world(p) + jitter, pick[1] * _rng.randf_range(0.9, 1.1), _rng.randf() * TAU)
	if _rng.randf() < 0.5:
		var tuft := TUFTS[_rng.randi() % TUFTS.size()]
		var off := Vector3(_rng.randf_range(-0.7, 0.7), 0.0, _rng.randf_range(-0.7, 0.7))
		_spawn_grass(tuft, cell_to_world(p) + off, 0.7, _rng.randf() * TAU)


func _add_apple(p: Vector2i, kind: String = "apple") -> void:
	var spec: Array = ITEMS.get(kind, ITEMS["apple"])
	var apple := _spawn(spec[0], surface(p) + Vector3(0, 0.3, 0), spec[1], 0.0)
	apple.name = "Item_%s_%d_%d" % [kind, p.x, p.y]
	_apples[p] = apple
	# Glowing disc on the path so items read clearly from the top-down camera.
	if not _mark_materials.has(kind):
		_mark_materials[kind] = _glow_material(spec[2], 1.4, 0.55)
	var mark := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.02
	mark.mesh = disc
	mark.material_override = _mark_materials[kind]
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position = surface(p) + Vector3(0, 0.02, 0)
	mark.name = "ItemMark_%d_%d" % [p.x, p.y]
	add_child(mark)
	_apple_marks[p] = mark


## A delivered item pops up over cell p and fades away.
func show_drop(p: Vector2i, kind: String) -> void:
	var spec: Array = ITEMS.get(kind, ITEMS["apple"])
	var item := _spawn(spec[0], surface(p) + Vector3(0, 0.6, 0), spec[1], 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(item, "position:y", item.position.y + 1.4, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector3.ONE * 0.01, 0.4).set_delay(0.5)
	tw.chain().tween_callback(item.queue_free)


func _add_goal(p: Vector2i) -> void:
	var base := surface(p)
	var goal_fx := Node3D.new()
	goal_fx.name = "GoalFx_%d_%d" % [p.x, p.y]
	goal_fx.position = base + Vector3(0, 0.04, 0)
	add_child(goal_fx)
	_goal_fxs.append(goal_fx)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.78
	ring.mesh = torus
	ring.material_override = _glow_material(Color(1.0, 0.78, 0.3), 2.5, 1.0)
	goal_fx.add_child(ring)

	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.7
	cyl.height = 3.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	beam.position.y = 1.5
	beam.material_override = _glow_material(Color(1.0, 0.85, 0.45), 1.2, 0.18)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	goal_fx.add_child(beam)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 1.6
	light.omni_range = 4.0
	light.position = base + Vector3(0, 1.2, 0)
	add_child(light)

	_spawn(GOAL_BASKET, base + Vector3(0.55, -0.02, -0.55), 0.8, PI * 0.25)


func _add_surroundings(world: GridWorld) -> void:
	var half_w := world.width * CELL * 0.5
	var half_h := world.height * CELL * 0.5

	# Tree line behind and beside the board (kept away from the camera side).
	for i in 14:
		var x := _rng.randf_range(-half_w - 14.0, half_w + 14.0)
		var z := -half_h - _rng.randf_range(3.0, 9.0)
		_spawn(TREES[_rng.randi() % TREES.size()], Vector3(x, 0, z), _rng.randf_range(3.0, 4.2), _rng.randf() * TAU)
	for side in [-1.0, 1.0]:
		for i in 4:
			var x: float = side * (half_w + _rng.randf_range(3.5, 9.0))
			var z := _rng.randf_range(-half_h, half_h * 0.4)
			_spawn(TREES[_rng.randi() % TREES.size()], Vector3(x, 0, z), _rng.randf_range(3.0, 4.0), _rng.randf() * TAU)

	# Village buildings in the background, at native scale.
	_spawn("EA03_Village_OutBuilding_Cubby_01d", Vector3(-half_w - 9.0, 0, -half_h - 14.0), 0.0, 0.4)
	_spawn("EA03_Village_OutBuilding_PentHouse_01a", Vector3(half_w + 8.0, 0, -half_h - 15.0), 0.0, -0.5)
	_spawn("EA03_Village_Tover_01a", Vector3(-2.0, 0, -half_h - 24.0), 0.0, 0.2)
	_spawn("EA03_Village_OutBuilding_Shed_01a", Vector3(half_w + 15.0, 0, -half_h + 2.0), 0.0, -1.4)
	_spawn("EA03_Village_AnimalBreeding_Hovel_01a", Vector3(-half_w - 6.0, 0, half_h - 1.0), 0.0, 1.2)

	# Small props near the board edges.
	_spawn("EA03_Items_House_Firewood_01a", Vector3(-half_w - 3.0, 0, -half_h + 1.0), 0.0, 1.57)
	_spawn("EA03_Prop_Town_Bench_01a", Vector3(half_w + 2.2, 0, half_h - 2.0), 0.0, 0.0)
	_spawn("EA03_Prop_Container_Barrel_01d", Vector3(half_w + 2.4, 0, -half_h + 0.5), 0.0, 0.3)
	_spawn("EA03_Prop_Container_Bale_01a", Vector3(half_w + 2.0, 0, -half_h + 1.6), 0.9, 0.8)

	# Low vegetable-patch fence along the front edge, so it frames without hiding the board.
	var fence_len := 2.6
	var count := int(ceil((world.width * CELL + 2.0) / fence_len))
	var start_x := -count * fence_len * 0.5 + fence_len * 0.5
	for i in count:
		_spawn("EA03_Fence_VegetablePatch_02a", Vector3(start_x + i * fence_len, 0, half_h + 1.1), 0.0, 0.0)

	# Grass tufts scattered outside the board.
	for i in 70:
		var pos := Vector3(_rng.randf_range(-half_w - 12.0, half_w + 12.0), 0, _rng.randf_range(-half_h - 8.0, half_h + 6.0))
		if absf(pos.x) < half_w + 0.6 and absf(pos.z) < half_h + 0.6:
			continue
		_spawn_grass(TUFTS[_rng.randi() % TUFTS.size()], pos, _rng.randf_range(0.6, 1.4), _rng.randf() * TAU)


# --- Helpers --------------------------------------------------------------

## Instances an asset under a holder at `at`. `footprint` > 0 scales the model so its
## larger horizontal side equals footprint; 0 keeps native scale. The model is centered
## on the holder and its bottom rests on the holder origin.
func _spawn(asset: String, at: Vector3, footprint: float, yaw: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	add_child(holder)
	var model := _instance(asset)
	if model == null:
		return holder
	holder.add_child(model)
	var box := _local_aabb(model)
	var s := 1.0
	if footprint > 0.0:
		s = footprint / maxf(maxf(box.size.x, box.size.z), 0.001)
	model.scale = Vector3.ONE * s
	var center := box.get_center()
	model.position = Vector3(-center.x * s, -box.position.y * s, -center.z * s)
	return holder


## A grass tuft that sways in the wind (EmacEArt stylized grass shader, tint layers off so the
## palette colors stay as they are). Materials are shared per palette texture and model height.
func _spawn_grass(asset: String, at: Vector3, footprint: float, yaw: float) -> Node3D:
	var holder := _spawn(asset, at, footprint, yaw)
	for node in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var src := mi.material_override as BaseMaterial3D
		if src == null or src.albedo_texture == null:
			continue
		var height := maxf(mi.get_aabb().size.y, 0.01)
		var key := "%s|%.2f" % [src.albedo_texture.get_rid(), height]
		if not _wind_materials.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = GRASS_SHADER
			mat.set_shader_parameter("albedo_texture", src.albedo_texture)
			mat.set_shader_parameter("anchor_height", height)
			mat.set_shader_parameter("wind_strength", 0.12 * height)
			mat.set_shader_parameter("alpha_cutoff", 0.0)
			mat.set_shader_parameter("ambient_lift", 0.12)
			for tint in ["tint_intensity_small_blob", "tint_intensity_small_stripes", "tint_intensity_large_blob", "tint_intensity_large_stripes"]:
				mat.set_shader_parameter(tint, 0.0)
			_wind_materials[key] = mat
		mi.material_override = _wind_materials[key]
	return holder


## `asset` is a glb name in ASSET_DIR, or a full res:// path to an FBX taken from the PRO pack.
func _instance(asset: String) -> Node3D:
	var scene: PackedScene = _scene_cache.get(asset)
	if scene == null:
		var path := asset if asset.begins_with("res://") else ASSET_DIR + asset + ".glb"
		scene = load(path) as PackedScene
		if scene == null:
			push_warning("Missing asset: " + asset)
			return null
		_scene_cache[asset] = scene
	var node := scene.instantiate() as Node3D
	if asset.begins_with("res://"):
		_fix_fbx_prop(node)
	else:
		fix_palette_materials(node)
	return node


## PRO-pack FBX props come with three LOD meshes and no texture: keep LOD0 and paint it with
## the shared palette (the same 32x32 color sheet as the glb pack).
static func _fix_fbx_prop(root: Node) -> void:
	var tex: Texture2D = load(PROP_PALETTE)
	if not _palette_materials.has(tex):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.9
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_palette_materials[tex] = mat
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.visible = not (mi.name.ends_with("LOD1") or mi.name.ends_with("LOD2"))
		mi.material_override = _palette_materials[tex]


## The pack colors everything from a 32x32 palette texture. Default linear filtering and
## mipmaps blend neighbouring palette cells, which washes colors out to grey-blue at a
## distance. Swap in one shared material per texture with nearest filtering.
static func fix_palette_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var src := mi.get_active_material(0) as BaseMaterial3D
		if src == null or src.albedo_texture == null:
			continue
		var mat: StandardMaterial3D = _palette_materials.get(src.albedo_texture)
		if mat == null:
			mat = StandardMaterial3D.new()
			mat.albedo_texture = src.albedo_texture
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.roughness = 0.9
			mat.metallic_specular = 0.25
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_palette_materials[src.albedo_texture] = mat
		mi.material_override = mat


## AABB of all visual descendants, in the coordinate space of `root` (ignoring root's own transform).
static func _local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		for child in node.get_children():
			if child is Node3D:
				var child_xf: Transform3D = xf * (child as Node3D).transform
				if child is VisualInstance3D:
					var box: AABB = child_xf * (child as VisualInstance3D).get_aabb()
					result = box if first else result.merge(box)
					first = false
				stack.append([child, child_xf])
	return result


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


static func _glow_material(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
