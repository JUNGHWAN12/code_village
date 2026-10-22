class_name CameraRig
extends Node3D
## Orbit camera around the board. Drag to rotate, mouse wheel to zoom.

@export var min_distance: float = 8.0
@export var max_distance: float = 60.0

var _yaw: float = 0.0
var _pitch: float = -0.95
var _distance: float = 20.0
var _target: Vector3 = Vector3.ZERO
var _dragging: bool = false
var _speed: float = 10.0  # how fast the camera eases toward its target (higher = snappier)
var _board_view: Dictionary = {}  # the framing frame() computed, for show_board()

@onready var _camera: Camera3D = $Camera3D


## Close-up on `point` (e.g. a villager's face) from `distance` meters, looking down by `pitch`.
## `instant` cuts there; otherwise the camera glides.
func focus_on(point: Vector3, distance: float, pitch: float, instant: bool = false) -> void:
	_target = point
	_distance = distance
	_pitch = pitch
	_yaw = 0.0
	_speed = 3.0
	if instant:
		_apply(1.0)


## Glides back to the whole-board view from the last frame().
func show_board() -> void:
	if _board_view.is_empty():
		return
	_target = _board_view["target"]
	_distance = _board_view["distance"]
	_pitch = _board_view["pitch"]
	_yaw = 0.0
	_speed = 2.2


## Fits the board in view. `back_margin` (meters) extends the framed area past the far edge,
## e.g. to keep a villager standing behind the board in the picture.
func frame(board_size: Vector2, back_margin: float = 0.0) -> void:
	_yaw = 0.0
	_pitch = -0.95
	_target = Vector3(0, 0, board_size.y * 0.08 - back_margin * 0.5)
	board_size.y += back_margin
	var vfov := deg_to_rad(_camera.fov)
	var aspect := 1.2
	var vp := get_viewport()
	if vp:
		var size := vp.get_visible_rect().size
		if size.y > 0:
			aspect = size.x / size.y
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)
	var need_w := (board_size.x * 0.5 + 2.0) / tan(hfov * 0.5)
	var need_h := (board_size.y * 0.5 + 2.0) / tan(vfov * 0.5) * 0.8
	_distance = clampf(maxf(need_w, need_h) * 0.82, min_distance, max_distance)
	_board_view = {"target": _target, "distance": _distance, "pitch": _pitch}
	_speed = 10.0
	_apply(1.0)


func _process(delta: float) -> void:
	_apply(1.0 - exp(-delta * _speed))


func _apply(weight: float) -> void:
	position = position.lerp(_target, weight)
	rotation.x = lerp_angle(rotation.x, _pitch, weight)
	rotation.y = lerp_angle(rotation.y, _yaw, weight)
	if _camera:
		_camera.position.z = lerpf(_camera.position.z, _distance, weight)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb.pressed
			_speed = 10.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance * 0.9, min_distance, max_distance)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance * 1.1, min_distance, max_distance)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.006
		_pitch = clampf(_pitch - mm.relative.y * 0.004, -1.4, -0.3)
