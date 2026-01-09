# ActionLogEntry.gd
# A single entry in a character's action history
class_name ActionLogEntry
extends RefCounted

var month: int = 1
var day: int = 1
var description: String = ""

func _init(p_month: int = 1, p_day: int = 1, p_description: String = "") -> void:
	month = p_month
	day = p_day
	description = p_description

func to_dict() -> Dictionary:
	return {
		"month": month,
		"day": day,
		"description": description
	}

static func from_dict(dict: Dictionary) -> ActionLogEntry:
	return ActionLogEntry.new(
		dict.get("month", 1),
		dict.get("day", 1),
		dict.get("description", "")
	)
