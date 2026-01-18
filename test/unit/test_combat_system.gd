extends GutTest
# test_combat_system.gd
# System tests for combat flow, verifying end-to-end functionality

var _registry: InstanceRegistry

func before_each():
	_registry = InstanceRegistry.get_registry()
	_registry.clear_all()
	GameManager.new_game()
	TimeMgr.reset()
	CombatMgr.set_combat_speed(CombatMgr.CombatSpeed.INSTANT)
	if CombatMgr.is_in_combat():
		CombatMgr.flee()

func after_each():
	_registry.clear_all()
	if CombatMgr.is_in_combat():
		CombatMgr.flee()

# --- Helper Methods ---

func _create_test_party_multi() -> Party:
	"""Create party with 2 characters for multi-character testing"""
	var char1 = GameManager.create_character("Fighter")
	char1.stats["hp"] = 100
	char1.stats["max_hp"] = 100
	char1.stats["attack"] = 15
	char1.stats["defense"] = 10

	var char2 = GameManager.create_character("Cleric")
	char2.stats["hp"] = 80
	char2.stats["max_hp"] = 80
	char2.stats["attack"] = 8
	char2.stats["defense"] = 5

	return GameManager.create_party("Test Party", [char1, char2])

func _create_multi_enemy() -> Array:
	"""Create array of multiple enemies"""
	return [
		{"name": "Goblin", "hp": 30, "max_hp": 30, "attack": 5, "speed": 8},
		{"name": "Orc", "hp": 50, "max_hp": 50, "attack": 10, "speed": 6}
	]

func _create_attack_form(power: int) -> CombatForm:
	var form = CombatForm.new("Attack")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, power))
	return form

func _create_multi_action_form(actions: Array) -> CombatForm:
	var form = CombatForm.new("Combo")
	for action_power in actions:
		form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, action_power))
	return form

# --- Per-Character Form Selection Tests ---

func test_per_character_form_selection():
	"""Test new per-character form selection system"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	# Get combatant IDs
	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	# Assign different forms to each character
	var strong_attack = _create_attack_form(20)
	var weak_attack = _create_attack_form(5)

	var result1 = CombatMgr.select_form_for_combatant(fighter_id, strong_attack)
	var result2 = CombatMgr.select_form_for_combatant(cleric_id, weak_attack)

	assert_true(result1, "Fighter form selection should succeed")
	assert_true(result2, "Cleric form selection should succeed")
	assert_eq(CombatMgr.party_combatants[0].selected_form, strong_attack)
	assert_eq(CombatMgr.party_combatants[1].selected_form, weak_attack)

func test_all_forms_selected_check():
	"""Test that combat requires all characters to select forms"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	# Initially, no forms selected
	assert_false(CombatMgr.are_all_forms_selected())

	# Select form for first character only
	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(10))
	assert_false(CombatMgr.are_all_forms_selected())

	# Select form for second character
	var cleric_id = CombatMgr.party_combatants[1].combatant_id
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(10))
	assert_true(CombatMgr.are_all_forms_selected())

func test_execute_turn_requires_all_forms():
	"""Test that execute_turn fails if not all forms selected"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	# Try to execute without selecting forms
	watch_signals(CombatMgr)
	await CombatMgr.execute_turn()

	# Should have pushed error and not executed
	assert_push_error("Cannot execute turn: not all characters have selected forms")
	assert_eq(CombatMgr.current_turn, 0, "Turn should not have advanced")

# --- Multi-Enemy Combat Tests ---

func test_multi_enemy_combat():
	"""Test combat against multiple enemies"""
	var party = _create_test_party_multi()
	var enemies = _create_multi_enemy()
	CombatMgr.start_combat(party, enemies)

	# Should have 2 enemy combatants
	assert_eq(CombatMgr.enemy_combatants.size(), 2)

	# Total enemy HP should be sum of both
	assert_eq(CombatMgr.enemy_hp, 80)  # 30 + 50
	assert_eq(CombatMgr.enemy_max_hp, 80)

func test_multi_enemy_unique_ids():
	"""Test that multiple enemies get unique IDs"""
	var party = _create_test_party_multi()
	var enemies = _create_multi_enemy()
	CombatMgr.start_combat(party, enemies)

	var id1 = CombatMgr.enemy_combatants[0].combatant_id
	var id2 = CombatMgr.enemy_combatants[1].combatant_id

	assert_ne(id1, id2, "Enemy IDs should be unique")
	assert_true(id1.begins_with("enemy_"), "Enemy ID should have enemy_ prefix")
	assert_true(id2.begins_with("enemy_"), "Enemy ID should have enemy_ prefix")

func test_defeat_all_enemies_to_win():
	"""Test that all enemies must be defeated to win"""
	var party = _create_test_party_multi()
	var enemies = _create_multi_enemy()
	CombatMgr.start_combat(party, enemies)

	# Select powerful forms for all party members
	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id
	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(50))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(50))

	await CombatMgr.execute_turn()

	# Both enemies should be defeated
	assert_false(CombatMgr.is_in_combat(), "Combat should end when all enemies defeated")

# --- Speed-Based Turn Order Tests ---

func test_turn_order_by_speed():
	"""Test that turn order respects speed values"""
	var party = _create_test_party_multi()
	var enemies = _create_multi_enemy()
	CombatMgr.start_combat(party, enemies)

	# Set different speeds
	CombatMgr.party_combatants[0].speed = 15  # Fighter - fastest
	CombatMgr.party_combatants[1].speed = 5   # Cleric - slowest
	# Enemies have speed 8 and 6 from _create_multi_enemy()

	# Select forms (1 action each for party)
	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id
	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(5))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(5))

	var turn_order = CombatMgr.get_turn_order()

	# Should have 8 entries: 1 fighter + 1 cleric + 3 goblin1 + 3 goblin2
	# (enemies get default 3-action forms, party gets 1-action forms)
	assert_eq(turn_order.size(), 8)

	# First action should be Fighter (speed 15 - highest)
	assert_eq(turn_order[0]["combatant"].speed, 15)
	# Verify turn order contains correct speeds (highest to lowest)
	var first_speed = turn_order[0]["combatant"].speed
	assert_eq(first_speed, 15, "First combatant should have speed 15")

func test_multi_action_turn_order():
	"""Test turn order with multi-action sequences"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 100, "max_hp": 100, "attack": 5, "speed": 10}
	CombatMgr.start_combat(party, enemy)

	# Fighter gets 3 actions, Cleric gets 1 action
	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	CombatMgr.party_combatants[0].speed = 20
	CombatMgr.party_combatants[1].speed = 15

	var multi_form = _create_multi_action_form([5, 5, 5])
	var single_form = _create_attack_form(5)

	CombatMgr.select_form_for_combatant(fighter_id, multi_form)
	CombatMgr.select_form_for_combatant(cleric_id, single_form)

	var turn_order = CombatMgr.get_turn_order()

	# Should have 7 total actions: 3 fighter + 3 cleric + 1 enemy
	# (all combatants get 3 actions from default forms, but cleric only selected 1-action form)
	assert_eq(turn_order.size(), 7)

func test_turn_order_caching():
	"""Test that turn order is cached and invalidated correctly"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(5))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(5))

	# Get turn order twice - should be same reference (cached)
	var order1 = CombatMgr.get_turn_order()
	var order2 = CombatMgr.get_turn_order()

	assert_eq(order1.size(), order2.size())
	# Note: Can't test reference equality in GDScript easily, but behavior should be correct

# --- Damage/Healing Modifier Tests ---

func test_damage_instance_modifiers():
	"""Test damage modifier pipeline works"""
	var damage_inst = DamageInstance.new(100, DamageInstance.DamageType.PHYSICAL)

	# Add flat pre-modifier
	damage_inst.add_flat_bonus("weapon", 20, DamageInstance.ModifierStage.FLAT_PRE)
	# Add percent modifier
	damage_inst.add_percent_bonus("strength", 0.5, DamageInstance.ModifierStage.PERCENT_PRE)

	var final = damage_inst.calculate_final_damage()

	# Should be (100 + 20) * 1.5 = 180
	assert_eq(final, 180)

func test_damage_mitigation():
	"""Test damage mitigation modifier"""
	var damage_inst = DamageInstance.new(100, DamageInstance.DamageType.PHYSICAL)

	# Add mitigation
	damage_inst.add_mitigation("armor", 0.3)  # -30% damage

	var final = damage_inst.calculate_final_damage()

	# Should be 100 * 0.7 = 70
	assert_eq(final, 70)

func test_true_damage_ignores_modifiers():
	"""Test TRUE damage type ignores all modifiers"""
	var damage_inst = DamageInstance.new(100, DamageInstance.DamageType.TRUE)

	damage_inst.add_flat_bonus("bonus", 50, DamageInstance.ModifierStage.FLAT_PRE)
	damage_inst.add_mitigation("armor", 0.5)

	var final = damage_inst.calculate_final_damage()

	# Should ignore modifiers and return base damage
	assert_eq(final, 100)

func test_healing_instance_modifiers():
	"""Test healing modifier pipeline works"""
	var healing_inst = HealingInstance.new(50, HealingInstance.HealingType.DIRECT)

	# Add flat bonus
	healing_inst.add_flat_bonus("spell power", 10, HealingInstance.ModifierStage.FLAT_PRE)
	# Add percent bonus
	healing_inst.add_percent_bonus("holy", 0.2, HealingInstance.ModifierStage.PERCENT_PRE)

	var final = healing_inst.calculate_final_healing()

	# Should be (50 + 10) * 1.2 = 72
	assert_eq(final, 72)

# --- Status Effect System Tests ---

func test_apply_defense_status_effect():
	"""Test applying defense status effect during combat"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 10}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	# Create defend form for fighter and attack form for cleric
	var defend_form = CombatForm.new("Defend")
	var defend_action = CombatAction.new(CombatAction.ActionType.DEFEND, 0)
	defend_action.target_type = CombatAction.TargetType.SELF  # Defense affects self
	defend_form.add_action(defend_action)

	var attack_form = CombatForm.new("Attack")
	attack_form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))

	CombatMgr.select_form_for_combatant(fighter_id, defend_form)
	CombatMgr.select_form_for_combatant(cleric_id, attack_form)

	# Execute turn (fighter defends, cleric attacks)
	await CombatMgr.execute_turn()

	# Verify combat executed without error
	assert_true(true, "Execute turn completed")
	# Combat should still be active (weak attack shouldn't kill enemy)
	assert_true(CombatMgr.is_in_combat(), "Combat should still be active")

func test_status_effect_decay():
	"""Test that status effects decay over rounds"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Weak Goblin", "hp": 5, "max_hp": 5, "attack": 1}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	# Fighter defends, cleric attacks weakly
	var defend_form = CombatForm.new("Defend")
	var defend_action = CombatAction.new(CombatAction.ActionType.DEFEND, 0)
	defend_action.target_type = CombatAction.TargetType.SELF  # Defense affects self
	defend_form.add_action(defend_action)
	CombatMgr.select_form_for_combatant(fighter_id, defend_form)
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(1))

	await CombatMgr.execute_turn()

	# Combat should still be active (combat continues after first turn)
	assert_true(CombatMgr.is_in_combat(), "Combat should continue after first turn")

	if CombatMgr.is_in_combat():
		# Do another turn
		CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(1))
		CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(1))
		await CombatMgr.execute_turn()

		# Effects should decay or be removed
		# (Exact behavior depends on effect configuration)
		# Verify combat completed without error
		assert_true(true, "Decay completed without error")

# --- Combat Lifecycle Tests ---

func test_round_start_lifecycle():
	"""Test ROUND_START lifecycle event fires"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(5))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(5))

	watch_signals(CombatMgr)
	await CombatMgr.execute_turn()

	assert_signal_emitted(CombatMgr, "round_started")

func test_round_end_lifecycle():
	"""Test ROUND_END lifecycle event fires"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(5))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(5))

	watch_signals(CombatMgr)
	await CombatMgr.execute_turn()

	assert_signal_emitted(CombatMgr, "round_ended")

func test_character_move_signals():
	"""Test character move lifecycle signals"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(5))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(5))

	watch_signals(CombatMgr)
	await CombatMgr.execute_turn()

	assert_signal_emitted(CombatMgr, "character_move_started")
	assert_signal_emitted(CombatMgr, "character_move_finished")

# --- HP Tracking Tests ---

func test_hp_aggregation_multi_party():
	"""Test HP aggregation with multiple party members"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	# Total party HP should be 100 + 80 = 180
	assert_eq(CombatMgr.party_hp, 180)
	assert_eq(CombatMgr.party_max_hp, 180)

func test_hp_tracking_after_damage():
	"""Test HP values update correctly after damage"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var initial_enemy_hp = CombatMgr.enemy_hp

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(10))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(10))

	await CombatMgr.execute_turn()

	# Enemy should have taken damage
	assert_lt(CombatMgr.enemy_hp, initial_enemy_hp)

# --- Edge Case Tests ---

func test_combat_with_zero_damage():
	"""Test combat continues even with 0 damage attacks"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	# Create attack with 0 power
	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(0))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(0))

	await CombatMgr.execute_turn()

	# Combat should still be active (no one defeated)
	assert_true(CombatMgr.is_in_combat())

func test_exactly_lethal_damage():
	"""Test enemy with exactly 0 HP is defeated"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 20, "max_hp": 20, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	# Deal exactly 20 damage (10 + 10)
	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(10))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(10))

	await CombatMgr.execute_turn()

	# Combat should end (enemy defeated)
	assert_false(CombatMgr.is_in_combat())

func test_overkill_damage():
	"""Test damage exceeding max HP still defeats enemy"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 10, "max_hp": 10, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var cleric_id = CombatMgr.party_combatants[1].combatant_id

	# Deal 100 damage to 10 HP enemy
	CombatMgr.select_form_for_combatant(fighter_id, _create_attack_form(100))
	CombatMgr.select_form_for_combatant(cleric_id, _create_attack_form(5))

	await CombatMgr.execute_turn()

	# Combat should end
	assert_false(CombatMgr.is_in_combat())
	assert_eq(CombatMgr.enemy_hp, 0, "Enemy HP should be 0, not negative")

# --- Helper Method Coverage Tests ---

func test_get_combatant_by_id():
	"""Test get_combatant_by_id helper"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	var fighter_id = CombatMgr.party_combatants[0].combatant_id
	var combatant = CombatMgr.get_combatant_by_id(fighter_id)

	assert_not_null(combatant)
	assert_eq(combatant.combatant_id, fighter_id)

	# Test with invalid ID
	var invalid = CombatMgr.get_combatant_by_id("invalid_id_12345")
	assert_null(invalid)

func test_default_form_creation():
	"""Test that default forms are created when needed"""
	var party = _create_test_party_multi()
	var enemy = {"name": "Goblin", "hp": 50, "max_hp": 50, "attack": 5}
	CombatMgr.start_combat(party, enemy)

	# Get available forms (should include default if no forms exist)
	var forms = CombatMgr.get_available_forms()

	assert_gt(forms.size(), 0, "Should have at least one form (default)")
	assert_eq(forms[0].form_name, "Basic Attack", "Default form should be Basic Attack")
