# CharacterCombatant.gd
# Wrapper for individual combatants in combat
# Manages CombatantState, HP proxying, and turn execution
class_name CharacterCombatant
extends RefCounted

# Combat state (with status effects)
var combatant_state: CombatantState = null

# Reference to underlying character/enemy
var character_ref: Variant = null  # PlayableCharacter or Enemy

# Combat stats
var speed: int = 10
var attack: int = 10
var defense: int = 5

# Turn state
var selected_form: CombatForm = null
var current_action_index: int = 0

# Identification
var combatant_id: String = ""
var display_name: String = ""
var is_enemy: bool = false

# HP snapshot (taken at combat start)
var _hp_snapshot: int = 0
var _max_hp_snapshot: int = 0

func _init(p_character_ref: Variant, p_is_enemy: bool = false):
	character_ref = p_character_ref
	is_enemy = p_is_enemy

	# Extract properties from character/enemy
	if p_is_enemy:
		# Enemy is a Dictionary or Enemy object
		if character_ref is Dictionary:
			display_name = character_ref.get("name", "Enemy")
			combatant_id = "enemy_%s" % display_name.to_lower().replace(" ", "_")
			speed = character_ref.get("speed", 10)
			attack = character_ref.get("attack", 10)
			defense = character_ref.get("defense", 5)
		else:
			# Enemy object (future implementation)
			display_name = character_ref.name if character_ref.has("name") else "Enemy"
			combatant_id = "enemy_%s" % display_name.to_lower().replace(" ", "_")
			speed = character_ref.speed if character_ref.has("speed") else 10
			attack = character_ref.attack if character_ref.has("attack") else 10
			defense = character_ref.defense if character_ref.has("defense") else 5
	else:
		# PlayableCharacter
		display_name = character_ref.char_name if character_ref else "Character"
		combatant_id = "char_%s" % display_name.to_lower().replace(" ", "_")
		if character_ref and character_ref.stats:
			speed = character_ref.stats.get("speed", 10)
			attack = character_ref.stats.get("attack", 10)
			defense = character_ref.stats.get("defense", 5)

	# Create CombatantState (will proxy HP)
	combatant_state = CombatantState.new(combatant_id, display_name, 0, 0)

	# Take HP snapshot
	snapshot_hp()

# Snapshot HP at combat start (read-only for CombatantState)
func snapshot_hp() -> void:
	if is_enemy:
		if character_ref is Dictionary:
			_hp_snapshot = character_ref.get("hp", 100)
			_max_hp_snapshot = character_ref.get("max_hp", _hp_snapshot)
		else:
			_hp_snapshot = character_ref.hp if character_ref.has("hp") else 100
			_max_hp_snapshot = character_ref.max_hp if character_ref.has("max_hp") else _hp_snapshot
	else:
		# PlayableCharacter
		if character_ref and character_ref.stats:
			_hp_snapshot = character_ref.stats.get("hp", 100)
			_max_hp_snapshot = character_ref.stats.get("max_hp", 100)
		else:
			_hp_snapshot = 100
			_max_hp_snapshot = 100

	# Set CombatantState HP to snapshot
	combatant_state.current_hp = _hp_snapshot
	combatant_state.max_hp = _max_hp_snapshot

# Sync HP changes back to character at combat end
func sync_hp_to_character() -> void:
	if is_enemy:
		if character_ref is Dictionary:
			character_ref["hp"] = combatant_state.current_hp
		elif character_ref.has("hp"):
			character_ref.hp = combatant_state.current_hp
	else:
		# PlayableCharacter
		if character_ref and character_ref.stats:
			character_ref.stats["hp"] = combatant_state.current_hp

# Get the next action for this combatant this round
func get_next_action() -> CombatAction:
	if not selected_form:
		# No form selected - return exhausted action
		return _create_exhausted_action()

	if current_action_index >= selected_form.actions.size():
		# Out of actions - return exhausted action
		return _create_exhausted_action()

	var action = selected_form.actions[current_action_index]
	current_action_index += 1
	return action

# Check if this combatant has more actions this round
func has_more_actions() -> bool:
	if not selected_form:
		return false
	return current_action_index < selected_form.actions.size()

# Get total number of actions for this round
func get_action_count() -> int:
	if not selected_form:
		return 0
	return selected_form.actions.size()

# Reset for new round
func reset_for_round() -> void:
	current_action_index = 0
	# Note: selected_form persists across rounds (until changed by player)

# Check if combatant is defeated
func is_defeated() -> bool:
	return combatant_state.current_hp <= 0

# Proxy HP operations to CombatantState
func take_damage(damage_instance: DamageInstance) -> int:
	var actual_damage = combatant_state.take_damage(damage_instance.calculate_final_damage())
	return actual_damage

func heal(healing_instance: HealingInstance) -> int:
	var actual_healing = combatant_state.heal(healing_instance.calculate_final_healing())
	healing_instance.actual_healing = actual_healing
	return actual_healing

# Apply status effect
func apply_status_effect(effect: StatusEffect, source: CharacterCombatant = null) -> void:
	var source_state = source.combatant_state if source else null
	combatant_state.apply_status_effect(effect, source_state)

# Helper to create an "exhausted" action when a combatant has no more moves
func _create_exhausted_action() -> CombatAction:
	var exhausted = CombatAction.new()
	exhausted.action_type = CombatAction.ActionType.DEFEND  # Defend self when exhausted
	exhausted.target_type = CombatAction.TargetType.SELF
	exhausted.power = 0
	exhausted.description = "%s has no more actions" % display_name
	return exhausted

# Serialization support
func to_dict() -> Dictionary:
	return {
		"combatant_id": combatant_id,
		"display_name": display_name,
		"is_enemy": is_enemy,
		"hp": combatant_state.current_hp,
		"max_hp": combatant_state.max_hp,
		"speed": speed,
		"attack": attack,
		"defense": defense,
		"current_action_index": current_action_index,
		"selected_form": selected_form.form_name if selected_form else null
	}
