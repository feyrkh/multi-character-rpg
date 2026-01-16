# KnownCombatAction.gd
# Per-character reference to a CombatAction with possible modifiers
class_name KnownCombatAction
extends RefCounted

var action_id: String = ""         # Reference to base CombatAction (InstanceRegistry ID)
var power_modifier: int = 0        # Added to base power (can be negative)
var custom_description: String = "" # Override description, or "" for base

func _init(p_action_id: String = "") -> void:
	action_id = p_action_id

func get_base_action() -> CombatAction:
	return GameManager.get_combat_action(action_id)

func get_effective_power() -> int:
	var base = get_base_action()
	return (base.power if base else 0) + power_modifier

func get_display_name() -> String:
	var base = get_base_action()
	return base.get_action_name() if base else action_id

func get_description() -> String:
	if custom_description != "":
		return custom_description
	var base = get_base_action()
	return base.description if base else ""

func get_icon_path() -> String:
	var base = get_base_action()
	return base.icon_path if base else ""

func get_action_type() -> CombatAction.ActionType:
	var base = get_base_action()
	return base.action_type if base else CombatAction.ActionType.ATTACK

func get_target_type() -> CombatAction.TargetType:
	var base = get_base_action()
	return base.target_type if base else CombatAction.TargetType.ENEMY

# Create a CombatAction instance with modified stats for use in combat
func to_combat_action() -> CombatAction:
	var base = get_base_action()
	if base == null:
		return null
	var action = CombatAction.new(base.action_type, get_effective_power())
	action.target_type = base.target_type
	action.skill_id = base.skill_id
	action.item_id = base.item_id
	action.description = get_description()
	action.icon_path = base.icon_path
	return action

func to_dict() -> Dictionary:
	return {
		"action_id": action_id,
		"power_modifier": power_modifier,
		"custom_description": custom_description
	}

static func from_dict(dict: Dictionary) -> KnownCombatAction:
	var known = KnownCombatAction.new()
	known.action_id = dict.get("action_id", "")
	known.power_modifier = dict.get("power_modifier", 0)
	known.custom_description = dict.get("custom_description", "")
	return known
