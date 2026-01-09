# A group of characters that travel and act together
class_name Party
extends RegisteredObject

var party_name: String = ""
var member_ids: Array[String] = []
var current_location_id: String = ""

func _init(p_name: String = "") -> void:
	party_name = p_name

func add_member_id(character_id: String) -> void:
	if character_id not in member_ids:
		member_ids.append(character_id)

func remove_member_id(character_id: String) -> bool:
	var idx = member_ids.find(character_id)
	if idx >= 0:
		member_ids.remove_at(idx)
		return true
	return false

func get_member_count() -> int:
	return member_ids.size()

func is_empty() -> bool:
	return member_ids.is_empty()

func has_member(character_id: String) -> bool:
	return character_id in member_ids

func to_dict() -> Dictionary:
	var result = super.to_dict()
	result["party_name"] = party_name
	result["member_ids"] = member_ids.duplicate()
	result["current_location_id"] = current_location_id
	return result

static func from_dict(dict: Dictionary) -> RegisteredObject:
	var party = Party.new(dict.get("party_name", ""))
	party.member_ids = Array(dict.get("member_ids", []), TYPE_STRING, "", null)
	party.current_location_id = dict.get("current_location_id", "")
	return _resolve_canonical(party, dict)
