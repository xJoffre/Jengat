extends Node

# Efectos de sonido (autoload "Audio"). Pon los archivos en assets/sounds/ con
# estos nombres. Si un archivo no existe, simplemente no suena (sin error).
const SOUNDS := {
	"remove": "res://assets/sounds/remove.mp3",
	"fall": "res://assets/sounds/fall.mp3",
	"challenge": "res://assets/sounds/challenge.mp3",
	"reward": "res://assets/sounds/reward.mp3",
	"select": "res://assets/sounds/select.mp3",  # clic de botones UI (opcional)
}

# Música/ambiente en loop. Una pista por escena. .ogg recomendado (loop limpio),
# pero .mp3 también sirve; si el archivo no existe, no suena.
const MUSIC := {
	"menu": "res://assets/sounds/music_menu.mp3",
	"game": "res://assets/sounds/ambient_fire.mp3",
}

var _music: AudioStreamPlayer
var _current := ""
var _save_timer: Timer  # debounce: el slider llama set_volume decenas de veces seguidas

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(Settings.save)
	add_child(_save_timer)
	set_volume(Settings.volume)
	# ponytail: engancha el clic a todo botón globalmente desde un solo sitio,
	# en vez de cablearlo escena por escena. Cubre botones futuros automáticamente.
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	# El guard evita doble clic si un botón se re-añade al árbol (reparent, etc.).
	if n is BaseButton and not n.pressed.is_connected(_click):
		n.pressed.connect(_click)

func _click() -> void:
	play("select")

# Volumen global (música + SFX) vía bus Master. v en 0..1.
# Guarda a disco con retardo: solo una escritura al soltar el slider.
func set_volume(v: float) -> void:
	Settings.volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(Settings.volume))
	_save_timer.start()

# Cambia la pista de fondo. Repetir la misma no la reinicia.
func music(name: String) -> void:
	_music.stream_paused = false  # al (re)entrar a una escena, nunca quedar en pausa
	if name == _current:
		return
	_current = name
	var path: String = MUSIC.get(name, "")
	if not Settings.sound or path == "" or not ResourceLoader.exists(path):
		_music.stop()
		return
	var stream := load(path)
	stream.loop = true  # AudioStreamOggVorbis/MP3 exponen 'loop'
	_music.stream = stream
	_music.play()

func pause_music() -> void:
	_music.stream_paused = true

func resume_music() -> void:
	_music.stream_paused = false

# Toggle del menú: además de SFX, corta/retoma la música en caliente.
func set_sound(on: bool) -> void:
	Settings.sound = on
	Settings.save()
	if not on:
		_music.stop()
	elif _current != "":
		var c := _current
		_current = ""
		music(c)

func play(name: String) -> void:
	if not Settings.sound:
		return
	var path: String = SOUNDS.get(name, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = load(path)
	p.finished.connect(p.queue_free)
	p.play()
