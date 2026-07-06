extends Node

# Retos creados por el usuario + catálogo de categorías (autoload "Custom").
# Se guardan en user://custom_challenges.json como [{text, category}].

const CATEGORIES := [
	{"id": "trago", "label": "Trago", "emoji": "🍻", "color": Color(1, 0.6, 0.25)},
	{"id": "beso", "label": "Beso", "emoji": "💋", "color": Color(1, 0.45, 0.7)},
	{"id": "atrevido", "label": "Atrevido", "emoji": "😈", "color": Color(1, 0.42, 0.45)},
	{"id": "verdad", "label": "Verdad", "emoji": "🎭", "color": Color(0.45, 0.6, 1)},
	{"id": "grupal", "label": "Grupal", "emoji": "🎉", "color": Color(0.4, 0.85, 0.5)},
	{"id": "especial", "label": "Especial", "emoji": "⭐", "color": Color(1, 0.8, 0.3)},
]

const PATH := "user://custom_challenges.json"

var items: Array = []  # [{ "text": String, "category": String }]

# Retos ya mostrados ESTA sesión (solo en memoria; se borra al cerrar la app).
var _used := {}

func _ready() -> void:
	load_items()

# Marca un reto como mostrado para no repetirlo en las próximas partidas.
func mark_used(text: String) -> void:
	if not text.is_empty():
		_used[text] = true

# Baraja de retos para una partida (base + propios), priorizando los NO usados
# esta sesión. Si se agotan los nuevos, repite los ya vistos (no hay de dónde más).
func session_pool(count: int) -> Array:
	var all: Array = base_items() + items
	all.shuffle()
	var unused: Array = []
	var used_ones: Array = []
	for c in all:
		if _used.has(String(c.get("text", ""))):
			used_ones.append(c)
		else:
			unused.append(c)
	var pool: Array = unused + used_ones
	var result: Array = []
	var i := 0
	while result.size() < count and not pool.is_empty():
		result.append(pool[i % pool.size()])
		i += 1
	return result

func load_items() -> void:
	items = []
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		items = data

func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(items))

func add(text: String, category: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	items.append({"text": text, "category": category})
	_save()

func remove_at(i: int) -> void:
	if i >= 0 and i < items.size():
		items.remove_at(i)
		_save()

# Id de categoría de un reto: campo "category" si existe; si no, mapeo del "type".
func cat_id_of(c: Dictionary) -> String:
	if c.has("category"):
		return c["category"]
	match c.get("type", ""):
		"trago": return "trago"
		"comodin": return "especial"
		_: return "atrevido"

# Todos los retos base (data/challenges.json), aplanados. Solo lectura.
func base_items() -> Array:
	var out: Array = []
	var f := FileAccess.open("res://data/challenges.json", FileAccess.READ)
	if f == null:
		return out
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary and d.has("columns"):
		for col in d["columns"].values():
			for e in col:
				out.append(e)
	return out

# Datos de una categoría por id (con fallback seguro).
func category(id: String) -> Dictionary:
	for c in CATEGORIES:
		if c["id"] == id:
			return c
	return {"id": id, "label": id, "emoji": "", "color": Color(1, 0.85, 0.6)}

# Icono propio de una categoría: imagen en assets/icons/<id>.<ext> si existe.
# Si no hay archivo, devuelve null y se usa el emoji. Suelta tus iconos ahí.
func icon(id: String) -> Texture2D:
	# gif: solo carga si tienes un addon importador de GIF en el proyecto;
	# sin él Godot 4 no lo importa y se ignora. No se anima por sí solo.
	for ext in ["png", "svg", "jpg", "jpeg", "webp", "gif"]:
		var p := "res://assets/icons/%s.%s" % [id, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null

# Frames de la animación de un icono. Convención: tira HORIZONTAL de frames
# cuadrados (cada frame = alto x alto). 1 frame si es cuadrado. [] si no hay
# archivo. Así un PNG estático sigue funcionando sin tocar nada.
func icon_frames(id: String) -> Array:
	var tex := icon(id)
	if tex == null:
		return []
	var h := tex.get_height()
	var n: int = maxi(1, tex.get_width() / h) if h > 0 else 1
	if n <= 1:
		return [tex]
	var frames: Array = []
	for i in n:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * h, 0, h, h)
		frames.append(a)
	return frames
