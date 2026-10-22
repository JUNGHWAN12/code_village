class_name Sfx
extends Node
## Short sound effects (res://audio/sfx/*.wav, synthesized for this game, no license strings).
## play("pick") picks a free player from a small pool so sounds can overlap.

const NAMES: PackedStringArray = ["move", "turn", "pick", "drop", "bump", "fail", "success", "door", "say", "click", "hoof"]
const VOLUME_DB: Dictionary = {"move": -10.0, "turn": -14.0, "hoof": -12.0, "click": -12.0}
const POOL: int = 8

var muted: bool = false

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	for n in NAMES:
		var stream := load("res://audio/sfx/%s.wav" % n) as AudioStream
		if stream:
			_streams[n] = stream
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## `pitch_jitter` > 0 varies the pitch a little so repeated steps do not sound identical.
func play(sound: String, pitch_jitter: float = 0.0) -> void:
	if muted or not _streams.has(sound) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = VOLUME_DB.get(sound, -6.0)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
