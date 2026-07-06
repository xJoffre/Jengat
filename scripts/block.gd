extends RigidBody3D

# Un bloque de la torre. La interacción (raycast, qué bloque se agarra) la
# maneja game.gd; aquí solo está el comportamiento de "tirar con el dedo".
# ponytail: physics-grab clásico. PULL_STRENGTH es el knob a afinar en pulido.
const PULL_STRENGTH := 4.5

var _grabbed := false
var _grab_distance := 0.0

func grab(distance: float) -> void:
	_grabbed = true
	_grab_distance = distance
	_highlight(true)

func release() -> void:
	_grabbed = false
	_highlight(false)

# Brillo cálido en el bloque agarrado: "este es el que estás sacando".
func _highlight(on: bool) -> void:
	var m := $Mesh.material_override as StandardMaterial3D
	if m == null:
		return
	m.emission_enabled = on
	if on:
		m.emission = Color(1, 0.6, 0.25)
		m.emission_energy_multiplier = 0.6

# Sigue el rayo del dedo: ponemos la velocidad hacia el punto objetivo, así el
# bloque se deja arrastrar y aguanta contra la gravedad mientras se agarra.
func drag_to(ray_origin: Vector3, ray_dir: Vector3) -> void:
	if not _grabbed:
		return
	var target := ray_origin + ray_dir * _grab_distance
	linear_velocity = (target - global_position) * PULL_STRENGTH
