# CombatModifier.gd
# Shared modifier class for damage and healing calculations
class_name CombatModifier
extends RefCounted

enum Stage {
	FLAT_PRE,       # Flat bonuses applied before percent (e.g., +10 damage)
	PERCENT_PRE,    # Percent bonuses applied early (e.g., +20% damage)
	FLAT_POST,      # Flat bonuses applied after percent (e.g., +5 final damage)
	PERCENT_POST,   # Percent bonuses applied late (e.g., +15% final damage)
	MITIGATION      # Damage reduction (e.g., -30% from armor) - only used for damage
}

var source: String = ""
var amount: float = 0.0
var stage: Stage

func _init(p_source: String, p_amount: float, p_stage: Stage):
	source = p_source
	amount = p_amount
	stage = p_stage

func _to_string() -> String:
	return "%s: %.1f at %s" % [source, amount, Stage.keys()[stage]]
