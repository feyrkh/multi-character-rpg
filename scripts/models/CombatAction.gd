# CombatAction.gd
# A single action within a combat form
class_name CombatAction
extends RegisteredObject

enum ActionType { ATTACK, DEFEND, SKILL, ITEM }
enum TargetType { ENEMY, SELF, ALLY, ALL_ENEMIES, ALL_ALLIES }

var action_type: ActionType = ActionType.ATTACK
var target_type: TargetType = TargetType.ENEMY
var power: int = 10
var skill_id: String = ""  # For SKILL type
var item_id: String = ""   # For ITEM type
var description: String = ""
var icon_path: String = ""  # Path to action icon texture

func _init(p_type: ActionType = ActionType.ATTACK, p_power: int = 10) -> void:
	action_type = p_type
	power = p_power

func get_action_name() -> String:
	match action_type:
		ActionType.ATTACK:
			return "Attack"
		ActionType.DEFEND:
			return "Defend"
		ActionType.SKILL:
			return skill_id if skill_id else "Skill"
		ActionType.ITEM:
			return item_id if item_id else "Item"
	return "Unknown"

func to_dict() -> Dictionary:
	var result = super.to_dict()
	result["action_type"] = action_type
	result["target_type"] = target_type
	result["power"] = power
	result["skill_id"] = skill_id
	result["item_id"] = item_id
	result["description"] = description
	result["icon_path"] = icon_path
	return result

static func from_dict(dict: Dictionary) -> RegisteredObject:
	var action = CombatAction.new()
	action.action_type = dict.get("action_type", ActionType.ATTACK)
	action.target_type = dict.get("target_type", TargetType.ENEMY)
	action.power = dict.get("power", 10)
	action.skill_id = dict.get("skill_id", "")
	action.item_id = dict.get("item_id", "")
	action.description = dict.get("description", "")
	action.icon_path = dict.get("icon_path", "")
	return _resolve_canonical(action, dict)
