extends Node3D

# Fogata: parpadeo cálido como punto focal de la escena nocturna.
@onready var _light: OmniLight3D = $Light
@onready var _flame: Node3D = $Flame
var _base := 0.0
var _target := 1.0
var _next := 0.0

func _ready() -> void:
	_base = _light.light_energy

func _process(delta: float) -> void:
	# ponytail: objetivo aleatorio cada 0.1 s + interpolación. randf() por frame
	# se veía estroboscópico y variaba con el framerate.
	_next -= delta
	if _next <= 0.0:
		_next = 0.1
		_target = 0.8 + randf() * 0.4
	var k := minf(delta * 10.0, 1.0)
	_light.light_energy = lerpf(_light.light_energy, _base * _target, k)
	var s := lerpf(_flame.scale.x, _target, k)
	_flame.scale = Vector3(s, s * 1.15, s)
