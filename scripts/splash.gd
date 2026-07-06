extends Control

# Splash: nombre del juego al centro, créditos al pie. Funde y pasa al menú.
func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
