# LocationLink.gd
# An edge in the location graph connecting two locations
class_name LocationLink
extends RefCounted

var from_location_id: String = ""
var to_location_id: String = ""
var travel_distance: int = 1  # Days required to travel

func _init(p_from: String = "", p_to: String = "", p_distance: int = 1) -> void:
	from_location_id = p_from
	to_location_id = p_to
	travel_distance = p_distance

func connects(location_id: String) -> bool:
	return from_location_id == location_id or to_location_id == location_id

func get_other_end(location_id: String) -> String:
	if from_location_id == location_id:
		return to_location_id
	elif to_location_id == location_id:
		return from_location_id
	return ""

func to_dict() -> Dictionary:
	return {
		"from_location_id": from_location_id,
		"to_location_id": to_location_id,
		"travel_distance": travel_distance
	}

static func from_dict(dict: Dictionary) -> LocationLink:
	return LocationLink.new(
		dict.get("from_location_id", ""),
		dict.get("to_location_id", ""),
		dict.get("travel_distance", 1)
	)
