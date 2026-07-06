class_name ChallengeDeck
extends RefCounted

# Mazo con reto fijo por bloque: cada bloque tiene un reto según su columna
# (izquierda/central/derecha) y su posición/nivel (1..18).
const COLUMNS := ["izquierda", "central", "derecha"]

var _columns: Dictionary = {}

func _init(path := "res://data/challenges.json") -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir el mazo: " + path)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary and data.has("columns"):
		_columns = data["columns"]
	else:
		push_error("challenges.json sin 'columns'")

# slot: 0=izquierda, 1=central, 2=derecha. pos: nivel 1..18.
func get_challenge(slot: int, pos: int) -> Dictionary:
	var arr: Array = _columns.get(COLUMNS[clampi(slot, 0, 2)], [])
	for e in arr:
		if int(e.get("pos", -1)) == pos:
			return e
	return {"text": "(sin reto)", "type": "reto"}
