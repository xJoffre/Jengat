extends Control

const MIN_PLAYERS := 2
const MAX_PLAYERS := 8

var _count := 2

func _ready() -> void:
	$Buttons/Play.pressed.connect(_on_play)
	$Buttons/How.pressed.connect(func(): $HowToPanel.visible = true)
	$Buttons/Config.pressed.connect(func(): $ConfigPanel.visible = true)
	$Buttons/Quit.pressed.connect(get_tree().quit)
	$ConfigPanel/Minus.pressed.connect(func(): _set_count(_count - 1))
	$ConfigPanel/Plus.pressed.connect(func(): _set_count(_count + 1))
	$ConfigPanel/Sound.toggled.connect(func(on): Audio.set_sound(on))
	$ConfigPanel/Back.pressed.connect(func(): $ConfigPanel.visible = false)
	$HowToPanel/Back.pressed.connect(func(): $HowToPanel.visible = false)
	$Buttons/Mine.pressed.connect(_open_custom)
	$CustomPanel/V/Add.pressed.connect(_add_custom)
	$CustomPanel/V/Buttons/Delete.pressed.connect(_delete_custom)
	$CustomPanel/V/Buttons/Back.pressed.connect(func(): $CustomPanel.visible = false)
	for cat in Custom.CATEGORIES:
		var tex: Texture2D = Custom.icon(cat["id"])
		if tex:
			$CustomPanel/V/Category.add_icon_item(tex, cat["label"])
		else:
			$CustomPanel/V/Category.add_item("%s  %s" % [cat["emoji"], cat["label"]])
	$ConfigPanel/Sound.button_pressed = Settings.sound
	$ConfigPanel/Volume.value = Settings.volume
	$ConfigPanel/Volume.value_changed.connect(func(v): Audio.set_volume(v))
	_set_count(Settings.players.size())
	Audio.music("menu")
	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.dialog_text = "¿Salir del juego?"
	_quit_dialog.ok_button_text = "Salir"
	_quit_dialog.get_cancel_button().text = "Cancelar"
	_quit_dialog.confirmed.connect(get_tree().quit)
	add_child(_quit_dialog)

var _quit_dialog: ConfirmationDialog

# Botón/gesto "Atrás" de Android: cierra el modal abierto o confirma salir.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if $ConfigPanel.visible:
		$ConfigPanel.visible = false
	elif $HowToPanel.visible:
		$HowToPanel.visible = false
	elif $CustomPanel.visible:
		$CustomPanel.visible = false
	else:
		_quit_dialog.popup_centered()

func _set_count(n: int) -> void:
	_count = clampi(n, MIN_PLAYERS, MAX_PLAYERS)
	$ConfigPanel/Count.text = str(_count)

func _on_play() -> void:
	Settings.players.clear()
	for i in _count:
		Settings.players.append("Jugador %d" % (i + 1))
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _open_custom() -> void:
	_refresh_custom()
	$CustomPanel.visible = true

func _add_custom() -> void:
	var text: String = $CustomPanel/V/Text.text
	var idx: int = $CustomPanel/V/Category.selected
	var cat_id: String = Custom.CATEGORIES[max(idx, 0)]["id"]
	Custom.add(text, cat_id)
	$CustomPanel/V/Text.text = ""
	_refresh_custom()

func _delete_custom() -> void:
	var sel: PackedInt32Array = $CustomPanel/V/List.get_selected_items()
	if sel.is_empty():
		return
	Custom.remove_at(sel[0])
	_refresh_custom()

func _refresh_custom() -> void:
	var list: ItemList = $CustomPanel/V/List
	list.clear()
	# Tuyos primero: seleccionables (su índice coincide con Custom.items) y borrables.
	for it in Custom.items:
		_add_row(list, it, false)
	# Luego los que ya vienen en el juego: solo lectura, en gris, para no repetir.
	if not Custom.base_items().is_empty():
		var h := list.add_item("— Ya disponibles en el juego —")
		list.set_item_disabled(h, true)
		list.set_item_custom_fg_color(h, Color(0.6, 0.55, 0.5))
		for e in Custom.base_items():
			_add_row(list, e, true)

# Una fila de la lista. read_only = base (gris, no seleccionable/borrable).
func _add_row(list: ItemList, c: Dictionary, read_only: bool) -> void:
	var cat: Dictionary = Custom.category(Custom.cat_id_of(c))
	var tex: Texture2D = Custom.icon(cat["id"])
	var idx: int
	if tex:
		idx = list.add_item("%s" % c.get("text", ""), tex)
	else:
		idx = list.add_item("%s  %s" % [cat["emoji"], c.get("text", "")])
	if read_only:
		list.set_item_disabled(idx, true)
		list.set_item_custom_fg_color(idx, Color(0.55, 0.52, 0.5))
