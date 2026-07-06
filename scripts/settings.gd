extends Node

# Configuración compartida entre el menú y la partida (autoload "Settings").
var players: Array[String] = ["Jugador 1", "Jugador 2"]
var sound := true
var volume := 1.0  # 0..1 lineal, aplicado al bus Master

const PATH := "user://settings.cfg"

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		sound = cfg.get_value("audio", "sound", sound)
		volume = cfg.get_value("audio", "volume", volume)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "volume", volume)
	cfg.save(PATH)
