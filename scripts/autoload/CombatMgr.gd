# CombatMgr.gd
# Manages turn-based combat encounters
extends Node

signal combat_started(party, enemy_data: Dictionary)
signal form_selected(form)
signal turn_started(turn_number: int)
signal action_executed(action, source: String, target: String, damage: int)
signal combat_ended(report)

# Lifecycle signals
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal character_move_started(combatant_id: String, action)
signal character_move_executing(combatant_id: String, action)
signal character_move_finished(combatant_id: String, action, results: Dictionary)
signal status_effect_applied(combatant_id: String, effect)
signal damage_dealt(source_id: String, target_id: String, damage: int, actual_damage: int)
signal healing_applied(target_id: String, amount: int, actual_healing: int)

enum CombatState { INACTIVE, SELECTING_FORM, EXECUTING, ENEMY_TURN, RESOLVED }

enum CombatSpeed { INSTANT, MANUAL, SLOW, NORMAL, FAST, VERY_FAST }

var state = CombatState.INACTIVE
var current_party = null  # type: Party
var current_enemy: Dictionary = {}
var current_enemy_obj = null  # The actual Enemy object with forms, type: Enemy
var selected_form = null  # type: CombatForm
var current_turn: int = 0

# Combat stats for the current battle
# HP values are computed properties that aggregate from combatants
var party_hp: int:
	get:
		return _get_total_hp(party_combatants, false)

var party_max_hp: int:
	get:
		return _get_total_hp(party_combatants, true)

var enemy_hp: int:
	get:
		return _get_total_hp(enemy_combatants, false)

var enemy_max_hp: int:
	get:
		return _get_total_hp(enemy_combatants, true)

var total_damage_dealt: int = 0
var total_damage_received: int = 0

# Per-character combat tracking (single source of truth for HP/stats)
var party_combatants = []  # Array[CharacterCombatant]
var enemy_combatants = []  # Array[CharacterCombatant]

# Turn order caching
var _cached_turn_order: Array = []
var _turn_order_dirty: bool = true

# Speed control
var combat_speed: CombatSpeed = CombatSpeed.NORMAL
var waiting_for_manual_advance: bool = false

func _ready() -> void:
	# Cache initialization
	pass

func is_in_combat() -> bool:
	return state != CombatState.INACTIVE

# --- Combat Initialization ---

func start_combat(party: Party, enemy_data: Variant) -> void:
	"""
	Start combat with a party and enemy/enemies.
	enemy_data can be:
	- A single Dictionary (legacy single enemy)
	- An Array of Dictionaries (multiple enemies)
	"""
	if state != CombatState.INACTIVE:
		push_warning("Combat already in progress")
		return

	current_party = party
	# Store first enemy for legacy compatibility
	if enemy_data is Array and not enemy_data.is_empty():
		current_enemy = enemy_data[0]
	else:
		current_enemy = enemy_data
	current_enemy_obj = null  # Reset enemy object
	current_turn = 0

	# Clear previous combatants
	party_combatants.clear()
	enemy_combatants.clear()

	# Create CharacterCombatant for each party member
	var members = GameManager.get_party_members(party)
	for member in members:
		var combatant = CharacterCombatant.new(member, false)
		party_combatants.append(combatant)

		# Auto-select first form for each character
		if member.combat_forms.size() > 0:
			combatant.selected_form = member.combat_forms[0]
			combatant.reset_for_round()

	# Create CharacterCombatant for enemies (supports single or multiple)
	var enemies_list = []
	if enemy_data is Array:
		enemies_list = enemy_data
	else:
		enemies_list = [enemy_data]

	for i in range(enemies_list.size()):
		var enemy = enemies_list[i]
		var enemy_combatant = CharacterCombatant.new(enemy, true)
		# Make IDs unique if multiple enemies of same type
		if enemies_list.size() > 1:
			enemy_combatant.combatant_id = "enemy_%d_%s" % [i, enemy.get("name", "Enemy").to_lower().replace(" ", "_")]
			if i > 0:
				enemy_combatant.display_name = "%s %d" % [enemy.get("name", "Enemy"), i + 1]
		enemy_combatants.append(enemy_combatant)
		# Assign form to enemy immediately so they appear in turn order
		_assign_form_to_enemy_combatant(enemy_combatant)
	# Note: party_hp, enemy_hp etc. are now computed properties that aggregate automatically

	# Reset stats
	total_damage_dealt = 0
	total_damage_received = 0
	selected_form = null

	state = CombatState.SELECTING_FORM
	_invalidate_turn_order()  # Initialize turn order cache
	combat_started.emit(party, enemy_data)

func set_enemy_object(enemy: Enemy) -> void:
	# Set the Enemy object for form-based combat
	current_enemy_obj = enemy

# --- Form Selection ---

func get_available_forms(character_id: String = ""):
	if not current_party:
		return []

	var result = []
	var members = GameManager.get_party_members(current_party)

	# If character_id specified, filter to only that character's forms
	if character_id != "":
		var combatant = get_combatant_by_id(character_id)
		if combatant and combatant.character_ref:
			# Return only forms owned by this character
			for form in combatant.character_ref.combat_forms:
				result.append(form)

		# Return default form if character has no forms
		if result.is_empty():
			result.append(_create_default_attack_form(10, "A simple attack"))

		return result

	# If no character_id, return all party forms (backward compatibility)
	for member in members:
		for form in member.combat_forms:
			if not result.has(form):
				result.append(form)

	# Return a default form if none available
	if result.is_empty():
		result.append(_create_default_attack_form(10, "A simple attack"))

	return result

func select_form(form) -> void:
	push_warning("DEPRECATED: select_form() assigns the same form to all characters. Use select_form_for_combatant() for per-character selection.")

	if state != CombatState.SELECTING_FORM:
		push_error("Cannot select form in current state")
		return

	selected_form = form

	# LEGACY: Assign form to all party combatants
	# This method is deprecated and should not be used in new code
	# Use select_form_for_combatant() instead for per-character selection
	for combatant in party_combatants:
		combatant.selected_form = form
		combatant.reset_for_round()

	# Assign random form to enemy combatants
	for combatant in enemy_combatants:
		_assign_form_to_enemy_combatant(combatant)

	form_selected.emit(form)

func select_form_for_combatant(combatant_id: String, form: CombatForm) -> bool:
	"""Select a combat form for a specific party combatant. Returns true if successful."""
	if state != CombatState.SELECTING_FORM:
		push_error("Cannot select form in current state")
		return false

	# Find the combatant
	for combatant in party_combatants:
		if combatant.combatant_id == combatant_id:
			combatant.selected_form = form
			combatant.reset_for_round()
			_invalidate_turn_order()
			form_selected.emit(form)
			return true

	push_warning("Combatant not found: %s" % combatant_id)
	return false

func are_all_forms_selected() -> bool:
	"""Check if all party combatants have selected a form."""
	for combatant in party_combatants:
		if not combatant.selected_form:
			return false
	return true

func get_combatant_by_id(combatant_id: String) -> CharacterCombatant:
	"""Get a party combatant by ID."""
	for combatant in party_combatants:
		if combatant.combatant_id == combatant_id:
			return combatant
	return null

func get_turn_order() -> Array:
	"""
	Get the turn order for the current round, starting from current position.
	Returns an array of dictionaries with {combatant, action_number}
	Uses caching to avoid redundant recalculations.
	"""
	if _turn_order_dirty:
		_cached_turn_order = _calculate_turn_order()
		_turn_order_dirty = false

	return _cached_turn_order

func _calculate_turn_order() -> Array:
	"""Internal: Calculate turn order from scratch."""
	var turn_order = []

	# Calculate maximum number of actions
	var max_actions = 0
	for combatant in party_combatants + enemy_combatants:
		max_actions = max(max_actions, combatant.get_action_count())

	# Build turn order by action slot, starting from current position
	for action_slot in range(max_actions):
		# Get all combatants who have an action for this slot
		var active_combatants = []
		for combatant in party_combatants + enemy_combatants:
			if not combatant.is_defeated() and action_slot < combatant.get_action_count():
				# Only include if this action hasn't been executed yet
				if action_slot >= combatant.current_action_index:
					active_combatants.append(combatant)

		# Sort by speed (descending - highest speed goes first)
		_sort_combatants_by_speed(active_combatants)

		# Add to turn order
		for combatant in active_combatants:
			turn_order.append({
				"combatant": combatant,
				"action_number": action_slot + 1
			})

	return turn_order

func _invalidate_turn_order() -> void:
	"""Mark turn order cache as dirty, forcing recalculation on next access."""
	_turn_order_dirty = true

func _sort_combatants_by_speed(combatants: Array) -> void:
	"""Sort combatants by speed (descending), using combatant_id as tiebreaker."""
	combatants.sort_custom(func(a, b):
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.combatant_id < b.combatant_id
	)

func _create_default_attack_form(power: int = 10, description: String = "") -> CombatForm:
	"""Create a default 'Basic Attack' form with specified power. Creates 3 attacks for consistency."""
	var form = CombatForm.new("Basic Attack")
	if description:
		form.description = description
	# Create 3 attack actions for a full round
	for i in range(3):
		var attack = CombatAction.new(CombatAction.ActionType.ATTACK, power)
		form.add_action(attack)
	return form

func _assign_form_to_enemy_combatant(combatant: CharacterCombatant) -> void:
	"""Assign a combat form to an enemy combatant (from enemy or default)."""
	if current_enemy_obj and not current_enemy_obj.combat_forms.is_empty():
		combatant.selected_form = current_enemy_obj.get_random_form()
	else:
		combatant.selected_form = _create_default_attack_form(combatant.attack)
	combatant.reset_for_round()

func _get_total_hp(combatants: Array, use_max: bool) -> int:
	"""Aggregate HP from array of combatants."""
	var total = 0
	for combatant in combatants:
		if use_max:
			total += combatant.combatant_state.max_hp
		else:
			total += combatant.combatant_state.current_hp
	return total

func _are_all_defeated(combatants: Array) -> bool:
	"""Check if all combatants in array are defeated."""
	for combatant in combatants:
		if not combatant.is_defeated():
			return false
	return true

func execute_turn() -> void:
	if state != CombatState.SELECTING_FORM:
		push_error("Cannot execute turn: not in form selection state")
		return

	# Check that all party combatants have selected forms
	if not are_all_forms_selected():
		push_error("Cannot execute turn: not all characters have selected forms")
		return

	# Enemy forms are now assigned in start_combat(), no need to assign here

	current_turn += 1
	turn_started.emit(current_turn)
	state = CombatState.EXECUTING

	# LIFECYCLE: Round Start
	round_started.emit(current_turn)
	await _process_lifecycle_event_per_character(StatusEffect.TriggerEvent.ROUND_START)
	await _apply_speed_delay()

	# Check for defeat from status effects
	if _check_combat_end():
		return

	# Calculate maximum number of actions across all combatants
	var max_actions = 0
	for combatant in party_combatants + enemy_combatants:
		max_actions = max(max_actions, combatant.get_action_count())

	# Execute each action slot in speed-based order
	for action_slot in range(max_actions):
		await _execute_action_slot(action_slot)

		# Check for defeat after each action slot
		if _check_combat_end():
			return

	# LIFECYCLE: Round End
	round_ended.emit(current_turn)
	await _process_lifecycle_event_per_character(StatusEffect.TriggerEvent.ROUND_END)
	await _apply_speed_delay()

	# Apply decay to all combatants
	for combatant in party_combatants + enemy_combatants:
		combatant.combatant_state.apply_round_end_decay()

	# Check for defeat after decay
	if _check_combat_end():
		return

	# Continue combat - reset for next round
	selected_form = null  # Legacy global form

	# Reset action indices but preserve selected forms for next round
	for combatant in party_combatants:
		combatant.reset_for_round()

	# Reassign forms to enemies for next round
	for combatant in enemy_combatants:
		_assign_form_to_enemy_combatant(combatant)

	_invalidate_turn_order()  # Update turn order with new round
	state = CombatState.SELECTING_FORM

# Execute one action slot with speed-based turn order
func _execute_action_slot(slot_index: int) -> void:
	# Get all combatants who have an action for this slot
	var active_combatants = []
	for combatant in party_combatants + enemy_combatants:
		if not combatant.is_defeated() and combatant.current_action_index <= slot_index:
			active_combatants.append(combatant)

	# Sort by speed (descending - highest speed goes first)
	_sort_combatants_by_speed(active_combatants)

	# Execute each combatant's action
	for combatant in active_combatants:
		var action = combatant.get_next_action()

		# LIFECYCLE: Character Move Started
		character_move_started.emit(combatant.combatant_id, action)
		await _apply_speed_delay()

		# LIFECYCLE: Before Move - Call behavior hooks
		_process_before_move_hooks(combatant, action)

		# LIFECYCLE: Character Move Executing
		character_move_executing.emit(combatant.combatant_id, action)

		# Determine target(s)
		var targets = _get_targets_for_combatant_action(action, combatant)

		# Execute action on each target
		var results = await _execute_combatant_action(action, combatant, targets)
		await _apply_speed_delay()

		# LIFECYCLE: After Move - Call behavior hooks
		_process_after_move_hooks(combatant, action)

		# LIFECYCLE: Character Move Finished
		character_move_finished.emit(combatant.combatant_id, action, results)
		_invalidate_turn_order()  # Action completed, turn order changed
		await _apply_speed_delay()

# Check if combat should end due to defeat
func _check_combat_end() -> bool:
	if _are_all_defeated(enemy_combatants):
		_end_combat(CombatReport.Outcome.WIN)
		return true

	if _are_all_defeated(party_combatants):
		_end_combat(CombatReport.Outcome.LOSS)
		return true

	return false

# Process lifecycle events for each combatant individually
func _process_lifecycle_event_per_character(event) -> void:
	for combatant in party_combatants + enemy_combatants:
		if combatant.is_defeated():
			continue

		var result = combatant.combatant_state.process_effects_for_event(event)

		# Apply healing
		if result.healing > 0:
			var healing_inst = HealingInstance.new(result.healing, HealingInstance.HealingType.REGENERATION)
			healing_inst.target_id = combatant.combatant_id
			var actual = combatant.heal(healing_inst)
			healing_applied.emit(combatant.combatant_id, result.healing, actual)

		# Apply damage
		if result.damage > 0:
			var damage_inst = DamageInstance.new(result.damage, DamageInstance.DamageType.MAGICAL)
			damage_inst.target_id = combatant.combatant_id
			var actual = combatant.take_damage(damage_inst)

			if combatant.is_enemy:
				total_damage_dealt += actual
			else:
				total_damage_received += actual

			damage_dealt.emit("status", combatant.combatant_id, result.damage, actual)

		# Print messages
		for msg in result.messages:
			print(msg)

		# Apply reflected damage to other combatants
		if result.has("reflected_damage") and result.reflected_damage is Array:
			for reflection in result.reflected_damage:
				var attacker_id = reflection.get("attacker_id", "")
				var reflect_damage = reflection.get("damage", 0)

				if reflect_damage <= 0 or attacker_id.is_empty():
					continue

				# Find the attacker combatant
				var attacker_combatant = get_combatant_by_id(attacker_id)
				if not attacker_combatant or attacker_combatant.is_defeated():
					continue

				# Create DamageInstance for reflected damage
				var damage_inst = DamageInstance.new(reflect_damage, DamageInstance.DamageType.MAGICAL)
				damage_inst.source_id = combatant.combatant_id
				damage_inst.target_id = attacker_id
				var actual = attacker_combatant.take_damage(damage_inst)

				# Update damage tracking
				if attacker_combatant.is_enemy:
					total_damage_dealt += actual
				else:
					total_damage_received += actual

				# Emit signal for UI updates
				damage_dealt.emit(combatant.combatant_id, attacker_id, reflect_damage, actual)

# Process before move hooks for a combatant's status effects
func _process_before_move_hooks(combatant: CharacterCombatant, action: CombatAction) -> void:
	for effect in combatant.combatant_state.status_effects:
		# Check for custom behavior
		if effect.has_meta("behavior"):
			var behavior: EffectBehavior = effect.get_meta("behavior")
			behavior.on_before_move(combatant.combatant_state, action)

		# Also process BEFORE_MOVE trigger events (for standard effects)
		if effect.trigger_events.has(StatusEffect.TriggerEvent.BEFORE_MOVE):
			# Standard effects can apply buffs/debuffs here
			# For now, this is a placeholder for future standard effects
			pass

# Process after move hooks for a combatant's status effects
func _process_after_move_hooks(combatant: CharacterCombatant, action: CombatAction) -> void:
	for effect in combatant.combatant_state.status_effects:
		# Check for custom behavior
		if effect.has_meta("behavior"):
			var behavior: EffectBehavior = effect.get_meta("behavior")
			behavior.on_after_move(combatant.combatant_state, action)

		# Also process AFTER_MOVE trigger events (for standard effects)
		if effect.trigger_events.has(StatusEffect.TriggerEvent.AFTER_MOVE):
			# Standard effects can apply DoT/HoT here
			# For now, this is a placeholder for future standard effects
			pass

# Get target combatants for an action
func _get_targets_for_combatant_action(action, source):
	var targets = []

	match action.target_type:
		CombatAction.TargetType.ENEMY:
			# Target first living enemy
			for enemy in enemy_combatants if source.is_enemy == false else party_combatants:
				if not enemy.is_defeated():
					targets.append(enemy)
					break

		CombatAction.TargetType.SELF:
			targets.append(source)

		CombatAction.TargetType.ALLY:
			# Target first living ally (for now, just self)
			targets.append(source)

		CombatAction.TargetType.ALL_ENEMIES:
			# Target all living enemies
			for enemy in enemy_combatants if source.is_enemy == false else party_combatants:
				if not enemy.is_defeated():
					targets.append(enemy)

		CombatAction.TargetType.ALL_ALLIES:
			# Target all living allies
			for ally in party_combatants if source.is_enemy == false else enemy_combatants:
				if not ally.is_defeated():
					targets.append(ally)

	return targets

# Execute a combatant's action on targets using DamageInstance/HealingInstance
func _execute_combatant_action(action, source, targets) -> Dictionary:
	var results = {
		"damage_dealt": 0,
		"actual_damage": 0,
		"healing": 0,
		"actual_healing": 0,
		"status_effects_applied": [],
		"messages": []
	}

	match action.action_type:
		CombatAction.ActionType.ATTACK:
			for target in targets:
				# Create damage instance
				var damage_inst = DamageInstance.new(action.power, DamageInstance.DamageType.PHYSICAL)
				damage_inst.source_id = source.combatant_id
				damage_inst.target_id = target.combatant_id

				# HOOK: on_attacking for source's status effects
				for effect in source.combatant_state.status_effects:
					if effect.has_meta("behavior"):
						var behavior: EffectBehavior = effect.get_meta("behavior")
						behavior.on_attacking(source.combatant_state, target.combatant_state, damage_inst)

				# HOOK: on_attacked for target's status effects
				for effect in target.combatant_state.status_effects:
					if effect.has_meta("behavior"):
						var behavior: EffectBehavior = effect.get_meta("behavior")
						behavior.on_attacked(target.combatant_state, source.combatant_state, damage_inst)

				# Apply damage reduction from target's status effects
				var reduction = target.combatant_state.get_total_damage_reduction()
				if reduction.percent > 0.0:
					damage_inst.add_mitigation("Status Effects", reduction.percent / 100.0)
				if reduction.flat > 0:
					damage_inst.add_flat_bonus("Armor", -reduction.flat, DamageInstance.ModifierStage.FLAT_POST)

				# Apply damage (CharacterCombatant will calculate final damage)
				var actual = target.take_damage(damage_inst)
				var final_damage = damage_inst.calculate_final_damage()  # Access cached value

				results.damage_dealt += final_damage
				results.actual_damage += actual

				if source.is_enemy:
					total_damage_received += actual
				else:
					total_damage_dealt += actual

				damage_dealt.emit(source.combatant_id, target.combatant_id, final_damage, actual)
				action_executed.emit(action, source.combatant_id, target.combatant_id, actual)

		CombatAction.ActionType.DEFEND:
			# Determine which defense effect to apply
			var effect: StatusEffect
			# Get defense type from character metadata
			var defense_type = "fighter"  # Default
			if source.character_ref and source.character_ref is PlayableCharacter:
				defense_type = source.character_ref.defense_type

			# Create the appropriate defense effect
			var effect_id = defense_type + "_defense"
			effect = StatusEffectMgr.create_effect(effect_id)

			for target in targets:
				target.apply_status_effect(effect.duplicate(), source)
				status_effect_applied.emit(target.combatant_id, effect)
				results.status_effects_applied.append(effect)

			action_executed.emit(action, source.combatant_id, "multiple", 0)

		CombatAction.ActionType.SKILL:
			if action.skill_id == "heal":
				for target in targets:
					# Create healing instance
					var healing_inst = HealingInstance.new(action.power, HealingInstance.HealingType.DIRECT)
					healing_inst.source_id = source.combatant_id
					healing_inst.target_id = target.combatant_id

					# HOOK: on_healing_applied for source's status effects
					for effect in source.combatant_state.status_effects:
						if effect.has_meta("behavior"):
							var behavior: EffectBehavior = effect.get_meta("behavior")
							behavior.on_healing_applied(source.combatant_state, target.combatant_state, healing_inst)

					# HOOK: on_healing_received for target's status effects
					for effect in target.combatant_state.status_effects:
						if effect.has_meta("behavior"):
							var behavior: EffectBehavior = effect.get_meta("behavior")
							behavior.on_healing_received(target.combatant_state, source.combatant_state, healing_inst)

					# Apply healing
					var final_healing = healing_inst.calculate_final_healing()
					var actual = target.heal(healing_inst)

					results.healing += final_healing
					results.actual_healing += actual

					healing_applied.emit(target.combatant_id, final_healing, actual)

				action_executed.emit(action, source.combatant_id, "multiple", 0)

			elif action.skill_id == "cleanse":
				for target in targets:
					target.combatant_state.clear_cleansable_effects()
					results.messages.append("Cleansed status effects from " + target.display_name)

				action_executed.emit(action, source.combatant_id, "multiple", 0)

	return results

# ===== LEGACY CODE REMOVED =====
# The following functions were removed as they're no longer used:
# - _execute_action() - replaced by _execute_combatant_action()
# - _execute_action_with_effects() - replaced by _execute_combatant_action()
# - _get_targets_for_action() - replaced by _get_targets_for_combatant_action()
# - _process_lifecycle_event() - replaced by _process_lifecycle_event_per_character()
# - _execute_enemy_turn() - replaced by per-character action execution in execute_turn()
# - _execute_enemy_turn_with_lifecycle() - replaced by per-character action execution in execute_turn()

# Speed control methods
func set_combat_speed(speed: CombatSpeed) -> void:
	combat_speed = speed

func advance_manual_step() -> void:
	if combat_speed == CombatSpeed.MANUAL and waiting_for_manual_advance:
		waiting_for_manual_advance = false

func _get_speed_delay() -> float:
	match combat_speed:
		CombatSpeed.INSTANT:
			return 0.0
		CombatSpeed.MANUAL:
			return 0.0
		CombatSpeed.SLOW:
			return 2.0
		CombatSpeed.NORMAL:
			return 1.0
		CombatSpeed.FAST:
			return 0.5
		CombatSpeed.VERY_FAST:
			return 0.1
	return 1.0

func _apply_speed_delay() -> void:
	if combat_speed == CombatSpeed.MANUAL:
		waiting_for_manual_advance = true
		while waiting_for_manual_advance:
			await get_tree().process_frame
	else:
		var delay = _get_speed_delay()
		if delay > 0:
			await get_tree().create_timer(delay).timeout

# --- Flee ---

func flee() -> CombatReport:
	if state == CombatState.INACTIVE:
		return null

	return _end_combat(CombatReport.Outcome.FLED)

# --- Combat Resolution ---

func _end_combat(outcome: CombatReport.Outcome) -> CombatReport:
	var report = CombatReport.new()
	report.outcome = outcome
	report.damage_dealt = total_damage_dealt
	report.damage_received = total_damage_received
	report.turns_taken = current_turn
	report.enemy_name = current_enemy.get("name", "Enemy")

	# Sync HP back to characters
	for combatant in party_combatants:
		combatant.sync_hp_to_character()

	for combatant in enemy_combatants:
		combatant.sync_hp_to_character()

	# Add to action log for party members
	if current_party:
		var log_description = report.get_summary()
		var members = GameManager.get_party_members(current_party)
		for member in members:
			member.add_log_entry(TimeMgr.current_month, TimeMgr.current_day, log_description)

	# Reset state
	state = CombatState.RESOLVED
	combat_ended.emit(report)

	# Clean up
	current_party = null
	current_enemy = {}
	current_enemy_obj = null
	selected_form = null
	party_combatants.clear()
	enemy_combatants.clear()
	state = CombatState.INACTIVE

	return report

# --- State Queries ---

func get_party_hp_percent() -> float:
	if party_max_hp <= 0:
		return 0.0
	return float(party_hp) / float(party_max_hp)

func get_enemy_hp_percent() -> float:
	if enemy_max_hp <= 0:
		return 0.0
	return float(enemy_hp) / float(enemy_max_hp)

func get_current_turn() -> int:
	return current_turn

func get_enemy_name() -> String:
	return current_enemy.get("name", "Enemy")
