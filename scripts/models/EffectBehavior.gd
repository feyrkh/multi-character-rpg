# EffectBehavior.gd
# Base class for custom status effect behaviors
# Extend this class to create complex, scriptable effects
class_name EffectBehavior
extends RefCounted

# Reference to the StatusEffect data this behavior is attached to
var effect_data: StatusEffect

# Called when the effect is first applied to a target
# Override to add custom initialization logic
func on_apply(target: CombatantState, source: CombatantState) -> void:
	pass

# Called when the effect is removed from a target
func on_remove(target: CombatantState) -> void:
	pass

# Called when stacks are added
func on_stack_added(target: CombatantState, stacks_added: int) -> void:
	pass

# Called at round start if effect has ROUND_START trigger
# Return dictionary with "healing" and "damage" keys
func on_round_start(target: CombatantState) -> Dictionary:
	return {"healing": 0, "damage": 0, "messages": []}

# Called at round end if effect has ROUND_END trigger
func on_round_end(target: CombatantState) -> Dictionary:
	return {"healing": 0, "damage": 0, "messages": []}

# Called before the target executes a move
func on_before_move(target: CombatantState, action: CombatAction) -> void:
	pass

# Called after the target executes a move
func on_after_move(target: CombatantState, action: CombatAction) -> void:
	pass

# Called when the target is attacked
# Can modify the incoming damage instance
func on_attacked(target: CombatantState, attacker: CombatantState, damage_instance: DamageInstance) -> void:
	pass

# Called when the target attacks
# Can modify the outgoing damage instance
func on_attacking(target: CombatantState, victim: CombatantState, damage_instance: DamageInstance) -> void:
	pass

# Called when the target receives healing
# Can modify the incoming healing instance
func on_healing_received(target: CombatantState, healer: CombatantState, healing_instance: HealingInstance) -> void:
	pass

# Called when the target heals someone
# Can modify the outgoing healing instance
func on_healing_applied(target: CombatantState, recipient: CombatantState, healing_instance: HealingInstance) -> void:
	pass

# Custom damage reduction calculation
# Return {"percent": float, "flat": int, "reflect": int}
# Return null to use standard calculation
func calculate_damage_reduction(target: CombatantState):
	return null  # Use standard calculation

# Custom healing calculation
# Return healing amount, or -1 to use standard calculation
func calculate_healing(target: CombatantState) -> int:
	return -1  # Use standard calculation

# Custom damage calculation for DoT effects
# Return damage amount, or -1 to use standard calculation
func calculate_damage(target: CombatantState) -> int:
	return -1  # Use standard calculation

# Custom decay logic
# Return true if effect should be removed, false otherwise
# Return null to use standard decay
func should_remove_custom(target: CombatantState):
	return null  # Use standard decay

# Called when decay is applied
# Override to customize decay behavior
func on_decay(target: CombatantState) -> void:
	pass

# Get display text for tooltips/UI
func get_tooltip_text(target: CombatantState) -> String:
	if effect_data:
		return effect_data.description
	return ""

# Utility method to access effect data properties
func get_stacks() -> int:
	return effect_data.stacks if effect_data else 0

func get_strength() -> float:
	return effect_data.strength if effect_data else 0.0

func get_duration() -> int:
	return effect_data.duration_rounds if effect_data else 0

# Save custom data to dictionary
# Override to save custom state
func save_custom_data() -> Dictionary:
	return {}

# Load custom data from dictionary
# Override to restore custom state
func load_custom_data(data: Dictionary) -> void:
	pass
