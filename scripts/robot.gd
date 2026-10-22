class_name Robot
extends Node3D
## A small wooden helper robot built from primitives, with a basket from the asset pack.
## Faces -Z at yaw 0. All animation methods can be awaited.

const BASKET: String = "res://asset/glb/glb/EA03_Prop_Container_Basket_03a.glb"

var yaw: float = 0.0

var _model: Node3D
var _eye_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _label: Label3D
var _time: float = 0.0
var _busy: bool = false


func _ready() -> void:
	scale = Vector3.ONE * 1.25  # read clearly from the top-down camera
	_build()


func place(pos: Vector3, dir: int) -> void:
	position = pos
	yaw = -dir * PI * 0.5
	rotation = Vector3(0, yaw, 0)
	_model.position = Vector3.ZERO
	_model.rotation = Vector3.ZERO
	_model.scale = Vector3.ONE
	_set_eyes(Color(0.45, 0.95, 1.0))


## Body tint, so several robots on one board can be told apart.
func set_body_color(color: Color) -> void:
	if _body_mat:
		_body_mat.albedo_color = color


## Name tag over the head (e.g. "파랑" when several robots share the board). "" hides it.
func set_label(text: String, color: Color = Color.WHITE) -> void:
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.pixel_size = 0.005
		_label.font_size = 64
		_label.outline_size = 16
		_label.outline_modulate = Color(0.1, 0.07, 0.04, 0.9)
		_label.position = Vector3(0, 2.05, 0)
		add_child(_label)
	_label.text = text
	_label.modulate = color.lightened(0.35)
	_label.visible = text != ""


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func move_to(pos: Vector3, dur: float) -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(self, "position", pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var hop := create_tween()
	hop.tween_property(_model, "position:y", 0.16, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(_model, "position:y", 0.0, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_busy = false


func turn(delta_yaw: float, dur: float) -> void:
	_busy = true
	yaw += delta_yaw
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", yaw, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	_busy = false


func bump(dur: float) -> void:
	_busy = true
	_set_eyes(Color(1.0, 0.3, 0.25))
	var start := position
	var tw := create_tween()
	tw.tween_property(self, "position", start + forward() * 0.45, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position", start, dur * 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var wobble := create_tween()
	wobble.tween_property(_model, "rotation:x", 0.35, dur * 0.35)
	wobble.tween_property(_model, "rotation:x", 0.0, dur * 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_busy = false


func pick_up(dur: float) -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(_model, "rotation:x", -0.45, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "rotation:x", 0.0, dur * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	_busy = false


## Head shake for "nothing here" / errors.
func shrug(dur: float) -> void:
	_busy = true
	_set_eyes(Color(1.0, 0.55, 0.2))
	var tw := create_tween()
	for i in 3:
		tw.tween_property(_model, "rotation:y", 0.35, dur / 6.0)
		tw.tween_property(_model, "rotation:y", -0.35, dur / 6.0)
	tw.tween_property(_model, "rotation:y", 0.0, dur / 6.0)
	await tw.finished
	_busy = false


func celebrate() -> void:
	_busy = true
	_set_eyes(Color(1.0, 0.9, 0.4))
	var tw := create_tween()
	tw.tween_property(_model, "position:y", 0.6, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_model, "rotation:y", TAU, 0.5)
	tw.tween_property(_model, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "position:y", 0.3, 0.15)
	tw.tween_property(_model, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_model.rotation.y = 0.0
	_busy = false


func _process(delta: float) -> void:
	_time += delta
	if not _busy:
		# Gentle idle breathing.
		var s := 1.0 + sin(_time * 3.0) * 0.02
		_model.scale = Vector3(1.0, s, 1.0)


# --- Model ----------------------------------------------------------------

func _build() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)

	var wood := _material(Color(0.78, 0.5, 0.27), 0.7)
	_body_mat = wood
	var dark := _material(Color(0.32, 0.21, 0.13), 0.9)
	var brass := _material(Color(0.86, 0.68, 0.36), 0.35, 0.6)
	_eye_mat = _material(Color(0.45, 0.95, 1.0), 0.3)
	_eye_mat.emission_enabled = true
	_eye_mat.emission_energy_multiplier = 2.5

	for side in [-1.0, 1.0]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.2, 0.28, 0.26)
		_add_mesh(leg, dark, Vector3(0.16 * side, 0.14, 0.0))

	var body := CapsuleMesh.new()
	body.radius = 0.33
	body.height = 0.9
	_add_mesh(body, wood, Vector3(0, 0.68, 0))

	var belt := CylinderMesh.new()
	belt.top_radius = 0.345
	belt.bottom_radius = 0.345
	belt.height = 0.09
	_add_mesh(belt, dark, Vector3(0, 0.58, 0))

	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.5
	_add_mesh(head, brass, Vector3(0, 1.22, 0))

	var visor := BoxMesh.new()
	visor.size = Vector3(0.36, 0.14, 0.06)
	_add_mesh(visor, dark, Vector3(0, 1.24, -0.235))

	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.05
		eye.height = 0.1
		_add_mesh(eye, _eye_mat, Vector3(0.09 * side, 1.245, -0.27))

	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.018
	stalk.bottom_radius = 0.025
	stalk.height = 0.22
	_add_mesh(stalk, dark, Vector3(0, 1.55, 0))
	var tip := SphereMesh.new()
	tip.radius = 0.055
	tip.height = 0.11
	var tip_mat := _material(Color(1.0, 0.35, 0.25), 0.4)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(1.0, 0.35, 0.25)
	tip_mat.emission_energy_multiplier = 1.5
	_add_mesh(tip, tip_mat, Vector3(0, 1.68, 0))

	for side in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.075
		arm.height = 0.5
		var arm_node := _add_mesh(arm, dark, Vector3(0.4 * side, 0.72, -0.04))
		arm_node.rotation.z = 0.25 * side

	# Direction marker on the ground so players can always see where the robot faces.
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.45, 0.4, 0.03)
	var arrow_mat := _material(Color(1.0, 0.85, 0.4), 1.0)
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var arrow_node := MeshInstance3D.new()
	arrow_node.mesh = arrow
	arrow_node.material_override = arrow_mat
	arrow_node.rotation.x = -PI * 0.5
	arrow_node.position = Vector3(0, 0.03, -0.62)
	arrow_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arrow_node)

	var basket_scene := load(BASKET) as PackedScene
	if basket_scene:
		var basket := basket_scene.instantiate() as Node3D
		Board.fix_palette_materials(basket)
		basket.scale = Vector3.ONE * 1.35
		basket.position = Vector3(0, 0.5, 0.34)
		_model.add_child(basket)


func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_model.add_child(mi)
	return mi


func _set_eyes(color: Color) -> void:
	if _eye_mat:
		_eye_mat.albedo_color = color
		_eye_mat.emission = color


static func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
