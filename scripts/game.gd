extends Node3D

# Fase 1: monta la torre, deja arrastrar bloques con el dedo y detecta la caída.
# Sin turnos ni retos todavía (eso es Fase 2).
const BLOCK := preload("res://scenes/Block.tscn")
const LEVELS := 18
const BLOCK_W := 0.5
const BLOCK_H := 0.3
const GAP := 0.0  # tocándose: los 3 de un nivel se apuntalan y la torre aguanta

# ponytail: una sola señal. La torre "cae" cuando su punto más alto baja del 60%
# de la altura inicial. Sacar un bloque no baja la cima; un derrumbe sí. Afina el factor.
const FALL_FACTOR := 0.5

# Una pieza cuenta como "sacada" cuando se aleja en horizontal de su sitio original.
const REMOVE_DIST := 1.0
const MAX_PER_TURN := 1  # un solo bloque por turno (reglas clásicas)
const FLOOR_LOSS_COUNT := 2  # nº de bloques en el suelo para perder (1 = estricto)
const REST_SPEED := 0.25  # por debajo de esto, la pieza se considera quieta
const FLOOR_REST_Y := 0.4  # altura máx. de una pieza tumbada en el suelo

var _removed_this_turn := 0
var _stacked := 0  # piezas apiladas arriba, para seguir el orden de construcción

# Jugadores y turnos. La lista viene del menú (autoload Settings).
var _players: Array = ["Jugador 1", "Jugador 2"]
var _turn := 0
var _deck: ChallengeDeck

# Cámara en órbita alrededor de la torre. Arrastrar el vacío la rota.
const PIVOT := Vector3(0, 2.5, 0)
const ORBIT_SPEED := 0.008  # knob: sensibilidad de rotación
const ZOOM_MIN := 4.0
const ZOOM_MAX := 14.0

var _blocks: Array[RigidBody3D] = []
var _initial_top := 0.0
var _grabbed: RigidBody3D = null
var _to_stack: RigidBody3D = null  # la pieza sacada este turno, pendiente de apilar
var _active: RigidBody3D = null  # última pieza agarrada este turno (candidata a apilar)
var _pending_piece: RigidBody3D = null  # pieza con reto en pantalla, a apilar al pulsar Hecho
var _orbiting := false
var _yaw := 0.785   # ~45°
var _pitch := 0.5   # ~28°
var _radius := 8.0
var _fallen := false

var _wood_tex: Texture2D = null  # si existe assets/textures/wood.png, los bloques la usan

@onready var _camera: Camera3D = $Camera3D

var _scores: Array[int] = []  # retos cumplidos por jugador
var _shake_offset := Vector3.ZERO  # sacudida de cámara por tensión

func _ready() -> void:
	Audio.music("game")
	_update_camera()
	$UI/ChallengeCard/Card/Done.pressed.connect(_on_done)
	$UI/ChallengeCard/Card/Skip.pressed.connect(_on_skip)
	$UI/GameOver/Restart.pressed.connect(get_tree().reload_current_scene)
	$UI/GameOver/Menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	if not Settings.players.is_empty():
		_players = Settings.players.duplicate()
	_scores.resize(_players.size())
	if ResourceLoader.exists("res://assets/textures/wood.png"):
		_wood_tex = load("res://assets/textures/wood.png")
	_deck = ChallengeDeck.new()
	_update_turn_label()
	_build_tower()
	# La torre necesita asentarse antes de medir su altura de referencia.
	# Sin input mientras tanto: tocar bloques en esta ventana escapaba a la detección.
	set_process_unhandled_input(false)
	await get_tree().create_timer(1.5).timeout
	_initial_top = _max_height()
	set_process_unhandled_input(true)

func _build_tower() -> void:
	# Baraja de la partida: retos sin repetir respecto a partidas anteriores de
	# esta sesión (base + propios). Se reparte un reto por bloque.
	var pool := Custom.session_pool(LEVELS * 3)
	var idx := 0
	for level in LEVELS:
		var y := BLOCK_H * 0.5 + level * BLOCK_H
		var rotated := level % 2 == 1
		for i in 3:
			var b: RigidBody3D = BLOCK.instantiate()
			var offset := (i - 1) * (BLOCK_W + GAP)
			# Sin rotar: el bloque es largo en Z, los 3 se separan a lo ancho (X).
			# Rotado 90°: el largo pasa a X, los 3 se separan en Z.
			if rotated:
				b.position = Vector3(0.0, y, offset)
				b.rotation.y = deg_to_rad(90)
			else:
				b.position = Vector3(offset, y, 0.0)
			add_child(b)
			b.set_meta("home", b.position)
			b.set_meta("removed", false)
			b.set_meta("level", level)
			if idx < pool.size():
				b.set_meta("challenge", pool[idx])
			else:
				b.set_meta("challenge", _deck.get_challenge(i, level + 1))
			idx += 1
			_shade(b)
			_blocks.append(b)

# Tono de madera ligeramente distinto por bloque para que se distingan las piezas.
func _shade(b: RigidBody3D) -> void:
	var mesh := b.get_node("Mesh") as MeshInstance3D
	var mat: StandardMaterial3D = mesh.mesh.material.duplicate()
	mat.albedo_color = mat.albedo_color.darkened(randf() * 0.18)
	if _wood_tex:
		mat.albedo_texture = _wood_tex
	mesh.material_override = mat

func _max_height() -> float:
	var top := 0.0
	for b in _blocks:
		top = max(top, b.global_position.y)
	return top

func _physics_process(_delta: float) -> void:
	if _fallen or _initial_top == 0.0:
		return
	if _max_height() < _initial_top * FALL_FACTOR:
		_lose("La torre cayó")
		return
	# Una pieza agarrada que queda fuera (aunque la soltaras antes o esté cayendo)
	# pasa por la misma cuenta que al soltar: así MAX_PER_TURN aplica siempre.
	if _active:
		_count_if_removed(_active)
	_check_floor()
	# Cuando la pieza sacada queda quieta (cae al piso/asienta), sale su reto.
	if not _fallen and not $UI/ChallengeCard.visible:
		var cand := _stack_candidate()
		if cand != null:
			_pending_piece = cand
			_show_challenge(cand)
	_update_shake()

# Polvo + vibración leve en el punto donde se saca una pieza.
func _dust_at(pos: Vector3) -> void:
	var d: CPUParticles3D = $Dust
	d.global_position = pos
	d.restart()
	d.emitting = true
	Input.vibrate_handheld(20)

# Tensión: tiembla por el movimiento real de la torre, más un balanceo base que
# crece según cuántas piezas se han sacado (la torre cada vez más inestable).
func _update_shake() -> void:
	var motion := 0.0
	for b in _blocks:
		if b == _grabbed:
			continue
		motion = max(motion, b.linear_velocity.length())
	var intensity := clampf(motion - 0.4, 0.0, 2.0)
	intensity = max(intensity, clampf(_stacked - 4, 0, 12) * 0.035)
	if intensity > 0.01:
		_shake_offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * intensity * 0.03
		_update_camera()
	elif _shake_offset != Vector3.ZERO:
		_shake_offset = Vector3.ZERO
		_update_camera()

# Pieza lista para apilar: soltada (no en la mano), fuera de su sitio y QUIETA
# (ya cayó/asentó). Mientras se mueve, no se puede apilar.
func _stack_candidate() -> RigidBody3D:
	if _grabbed:
		return null
	var p: RigidBody3D = _to_stack
	if p == null and _active and _is_out(_active):
		p = _active
	if p == null or not _is_out(p):
		return null
	if p.global_position.y > FLOOR_REST_Y:
		return null  # aún no ha caído al piso (sigue en la pila o apoyada)
	if p.linear_velocity.length() > REST_SPEED or p.angular_velocity.length() > REST_SPEED:
		return null
	return p

# Pierdes si un bloque de la torre se desprende y cae al suelo. Exime la pieza
# que tienes en juego (la que agarras/vas a apilar). home.y > 0.4 ignora la base.
func _check_floor() -> void:
	var on_floor := 0
	for b in _blocks:
		if b == _grabbed or b == _to_stack:
			continue
		var home: Vector3 = b.get_meta("home")
		if home.y > 0.4 and b.global_position.y < 0.2:
			on_floor += 1
	if on_floor >= FLOOR_LOSS_COUNT:
		_lose("Cayeron bloques al suelo")

# Solo cuenta la pieza que el jugador agarró y soltó lejos de su sitio.
# Los vecinos empujados por la física no cuentan.
func _count_if_removed(b: RigidBody3D) -> void:
	if b.get_meta("removed"):
		return
	if _is_out(b):
		b.set_meta("removed", true)
		_to_stack = b
		Audio.play("remove")
		_dust_at(b.global_position)
		_removed_this_turn += 1
		if _removed_this_turn > MAX_PER_TURN:
			_lose("Sacaste más de %d bloque(s) en un turno" % MAX_PER_TURN)

# True si la pieza está fuera de su sitio (sacada), no solo meneada.
func _is_out(b: RigidBody3D) -> bool:
	var home: Vector3 = b.get_meta("home")
	return Vector2(b.global_position.x - home.x, b.global_position.z - home.z).length() > REMOVE_DIST

func _lose(reason: String) -> void:
	if _fallen:
		return
	_fallen = true
	Audio.play("fall")
	Input.vibrate_handheld(400)
	$UI/GameOver/OverText.text = "Perdió %s\n\n%s%s" % [_players[_turn], reason, _scoreboard()]
	_show_burla()
	$UI/GameOver.visible = true

# Imagen/video de burla al azar desde assets/burlas/. Si no hay nada, no pasa nada.
const BURLAS_DIR := "res://assets/burlas"

func _show_burla() -> void:
	var files := _list_burlas()
	if files.is_empty():
		return
	var path: String = files[randi() % files.size()]
	if path.get_extension().to_lower() == "ogv":
		var v: VideoStreamPlayer = $UI/GameOver/Video
		v.stream = load(path)
		v.visible = true
		Audio.pause_music()
		v.finished.connect(Audio.resume_music)
		v.play()
	else:
		# Imagen estática: la música sigue (nadie la reanudaría hasta cambiar de escena).
		var img: TextureRect = $UI/GameOver/Media
		img.texture = load(path)
		img.visible = true

# Lista imágenes y .ogv de la carpeta. Dedup por si aparecen .import/.remap.
func _list_burlas() -> Array:
	var seen := {}
	var d := DirAccess.open(BURLAS_DIR)
	if d == null:
		return []
	for f in d.get_files():
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "ogv"]:
			seen[BURLAS_DIR + "/" + f] = true
	return seen.keys()

const ICON_FPS := 12.0  # ritmo de la animación del icono de la carta

var _icon_tween: Tween

# Pinta el icono de la carta. 1 frame = estático; varios = bucle a ICON_FPS.
func _play_icon(rect: TextureRect, frames: Array) -> void:
	if is_instance_valid(_icon_tween):
		_icon_tween.kill()
	if frames.is_empty():
		return
	rect.texture = frames[0]
	if frames.size() == 1:
		return
	_icon_tween = create_tween().set_loops()
	for f in frames:
		_icon_tween.tween_callback(func(): rect.texture = f)
		_icon_tween.tween_interval(1.0 / ICON_FPS)

# El reto del bloque sacado, en la tarjeta modal, con color/emoji de su categoría.
func _show_challenge(piece: RigidBody3D) -> void:
	var c: Dictionary = piece.get_meta("challenge", {})
	Custom.mark_used(c.get("text", ""))
	var cat: Dictionary = Custom.category(Custom.cat_id_of(c))
	$UI/ChallengeCard/Card/Player.text = _players[_turn]
	$UI/ChallengeCard/Card/CardText.text = c.get("text", "(sin reto)")
	# Categoría (sin emoji, ya va el icono grande arriba).
	var kind: Label = $UI/ChallengeCard/Card/Kind
	kind.text = String(cat["label"]).to_upper()
	kind.add_theme_color_override("font_color", cat["color"])
	# Icono grande: tu imagen si existe (animada si es spritesheet), si no el emoji.
	var frames: Array = Custom.icon_frames(cat["id"])
	var icon_rect: TextureRect = $UI/ChallengeCard/Card/Icon
	var big: Label = $UI/ChallengeCard/Card/BigIcon
	icon_rect.visible = not frames.is_empty()
	big.visible = frames.is_empty()
	big.text = cat["emoji"]
	_play_icon(icon_rect, frames)
	$UI/ChallengeCard.visible = true
	Audio.play("challenge")
	_animate_card()

# Pop + fundido de entrada de la tarjeta.
func _animate_card() -> void:
	var card: Control = $UI/ChallengeCard/Card
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.7, 0.7)
	$UI/ChallengeCard.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property($UI/ChallengeCard, "modulate:a", 1.0, 0.2)

# "Hecho": apila la pieza, suma el punto y pasa al siguiente jugador.
func _on_done() -> void:
	_next_turn(_pending_piece != null)

# "No lo hice": la pieza se apila igual, pero sin punto.
func _on_skip() -> void:
	_next_turn(false)

func _next_turn(completed: bool) -> void:
	if _pending_piece:
		_do_stack(_pending_piece)
		_pending_piece = null
	$UI/ChallengeCard.visible = false
	if completed:
		if _turn < _scores.size():
			_scores[_turn] += 1
		_show_feedback()
	_turn = (_turn + 1) % _players.size()
	_removed_this_turn = 0
	_update_turn_label()

# "Reto completado": texto verde que aparece y se desvanece.
func _show_feedback() -> void:
	var f: Label = $UI/Feedback
	f.modulate.a = 1.0
	f.visible = true
	var t := create_tween()
	t.tween_interval(0.7)
	t.tween_property(f, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): f.visible = false)
	var c: CPUParticles2D = $UI/Confetti
	c.restart()
	c.emitting = true
	Audio.play("reward")

# Marcador para la pantalla de fin: retos cumplidos por jugador.
func _scoreboard() -> String:
	var s := "\n\n"
	for i in _players.size():
		s += "%s   ✔ %d\n" % [_players[i], _scores[i]]
	return s

func _update_turn_label() -> void:
	$UI/TurnLabel.text = "Turno: " + _players[_turn]

# "Atrás" de Android: cierra la tarjeta de reto, o vuelve al menú.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if $UI/ChallengeCard.visible:
		_on_skip()  # Atrás no regala el punto: cuenta como reto no cumplido
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# Apila la pieza siguiendo la construcción: rellena el siguiente hueco de la
# siguiente capa (3 por nivel, alternando orientación), encima de los 18 niveles.
func _do_stack(piece: RigidBody3D) -> void:
	_to_stack = null
	_active = null
	var level := LEVELS + _stacked / 3
	var slot := _stacked % 3
	var y := BLOCK_H * 0.5 + level * BLOCK_H
	var offset := (slot - 1) * BLOCK_W
	piece.linear_velocity = Vector3.ZERO
	piece.angular_velocity = Vector3.ZERO
	var rotated := level % 2 == 1
	var target := Vector3(0.0, y, offset) if rotated else Vector3(offset, y, 0.0)
	# Si otra pieza invadió el hueco, teleportar ahí interpenetra y el solver la
	# expulsa violentamente (tira la torre "sola"): mejor soltarla desde arriba.
	if _slot_occupied(piece, target, rotated):
		target.y += BLOCK_H
	target.y += 0.01  # holgura mínima: apoyada, no incrustada
	piece.rotation = Vector3(0, deg_to_rad(90), 0) if rotated else Vector3.ZERO
	piece.position = target
	piece.sleeping = true  # colocada en reposo: sin golpe que sacuda la torre
	piece.set_meta("home", target)  # nuevo sitio: no recontar al moverla
	piece.set_meta("removed", false)
	piece.set_meta("level", level)
	_stacked += 1

# ¿Hay otro cuerpo dentro del hueco destino? (misma caja de colisión de la pieza)
func _slot_occupied(piece: RigidBody3D, target: Vector3, rotated: bool) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = (piece.get_node("Collision") as CollisionShape3D).shape
	var b := Basis.IDENTITY.rotated(Vector3.UP, PI / 2.0) if rotated else Basis.IDENTITY
	q.transform = Transform3D(b, target)
	q.exclude = [piece.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _set_zoom(r: float) -> void:
	_radius = clampf(r, ZOOM_MIN, ZOOM_MAX)
	_update_camera()

func _update_camera() -> void:
	var dir := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))
	_camera.position = PIVOT + dir * _radius + _shake_offset
	_camera.look_at(PIVOT)

func _unhandled_input(event: InputEvent) -> void:
	# En Android cada toque llega dos veces: como ScreenTouch/Drag y como ratón
	# emulado. Descarta el eco (doble grab, órbita a doble velocidad).
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	# Zoom: pellizco de dos dedos en móvil (gesto magnify), rueda en escritorio.
	if event is InputEventMagnifyGesture:
		_set_zoom(_radius / event.factor)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_zoom(_radius - 0.5)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_zoom(_radius + 0.5)
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_try_grab(event.position)
		else:
			_release()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _grabbed:
			var from := _camera.project_ray_origin(event.position)
			var dir := _camera.project_ray_normal(event.position)
			_grabbed.drag_to(from, dir)
		elif _orbiting:
			_yaw -= event.relative.x * ORBIT_SPEED
			_pitch = clamp(_pitch + event.relative.y * ORBIT_SPEED, 0.05, 1.4)
			_update_camera()

# Toca un bloque → lo agarras; toca el vacío → orbitas la cámara.
func _try_grab(screen_pos: Vector2) -> void:
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is RigidBody3D:
		var b: RigidBody3D = hit.collider
		# No puedes tocar otra pieza si la que sacaste sigue sin apilar.
		if _to_stack != null and b != _to_stack:
			print("Apila la pieza que sacaste antes de tocar otra")
			return
		# Prohibido sacar de la fila superior completa o por encima (no cubierta).
		# Al apilar 3 piezas se completa un nivel nuevo y el techo sube.
		var ceiling := LEVELS - 1 + _stacked / 3
		if int(b.get_meta("level", 0)) >= ceiling:
			print("No puedes sacar de la fila superior")
			return
		_grabbed = b
		_active = b
		_grabbed.grab(from.distance_to(hit.position))
	else:
		_orbiting = true

func _release() -> void:
	if _grabbed:
		_grabbed.release()
		_count_if_removed(_grabbed)
		_grabbed = null
	_orbiting = false
