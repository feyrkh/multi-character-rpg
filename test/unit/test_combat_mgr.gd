extends GutTest

var _registry: InstanceRegistry

func before_each():
	_registry = InstanceRegistry.get_registry()
	_registry.clear_all()
	GameManager.new_game()
	TimeMgr.reset()
	# Reset combat state
	if CombatMgr.is_in_combat():
		CombatMgr.flee()

func after_each():
	_registry.clear_all()
	if CombatMgr.is_in_combat():
		CombatMgr.flee()

func _create_test_party() -> Party:
	var char = GameManager.create_character("Hero")
	char.stats["hp"] = 100
	char.stats["max_hp"] = 100
	return GameManager.create_party("Test Party", [char])

func _create_test_enemy() -> Dictionary:
	return {
		"name": "Goblin",
		"hp": 50,
		"max_hp": 50,
		"attack": 5
	}

# --- Initial State Tests ---

func test_initial_state():
	assert_eq(CombatMgr.state, CombatMgr.CombatState.INACTIVE)
	assert_false(CombatMgr.is_in_combat())

# --- Combat Start Tests ---

func test_start_combat():
	var party = _create_test_party()
	var enemy = _create_test_enemy()

	CombatMgr.start_combat(party, enemy)
	assert_true(CombatMgr.is_in_combat())
	assert_eq(CombatMgr.state, CombatMgr.CombatState.SELECTING_FORM)
	assert_eq(CombatMgr.current_party, party)

func test_start_combat_initializes_hp():
	var party = _create_test_party()
	var enemy = _create_test_enemy()

	CombatMgr.start_combat(party, enemy)
	assert_eq(CombatMgr.party_hp, 100)
	assert_eq(CombatMgr.party_max_hp, 100)
	assert_eq(CombatMgr.enemy_hp, 50)
	assert_eq(CombatMgr.enemy_max_hp, 50)

func test_start_combat_resets_stats():
	var party = _create_test_party()
	var enemy = _create_test_enemy()

	CombatMgr.start_combat(party, enemy)
	assert_eq(CombatMgr.total_damage_dealt, 0)
	assert_eq(CombatMgr.total_damage_received, 0)
	assert_eq(CombatMgr.current_turn, 0)

# --- Form Selection Tests ---

func test_get_available_forms():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	var forms = CombatMgr.get_available_forms()
	assert_gt(forms.size(), 0)  # Should have at least a default form

func test_select_form():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	var form = CombatForm.new("Test Form")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 10))

	CombatMgr.select_form(form)
	assert_eq(CombatMgr.selected_form, form)

func test_select_form_wrong_state():
	var form = CombatForm.new("Test Form")
	# Not in combat, should not work
	CombatMgr.select_form(form)
	assert_push_error("Cannot select form in current state")
	assert_null(CombatMgr.selected_form)

# --- Turn Execution Tests ---

func test_execute_turn():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	var form = CombatForm.new("Attack Form")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 10))
	CombatMgr.select_form(form)

	CombatMgr.execute_turn()
	assert_eq(CombatMgr.current_turn, 1)
	assert_gt(CombatMgr.total_damage_dealt, 0)

func test_execute_turn_deals_damage():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	var initial_enemy_hp = CombatMgr.enemy_hp

	var form = CombatForm.new("Attack Form")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 10))
	CombatMgr.select_form(form)
	CombatMgr.execute_turn()

	assert_lt(CombatMgr.enemy_hp, initial_enemy_hp)

func test_execute_turn_enemy_attacks():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	var initial_party_hp = CombatMgr.party_hp

	var form = CombatForm.new("Attack Form")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))  # Won't kill enemy
	CombatMgr.select_form(form)
	CombatMgr.execute_turn()

	# If combat continues, enemy should have attacked
	if CombatMgr.is_in_combat():
		assert_lt(CombatMgr.party_hp, initial_party_hp)

# --- Combat Resolution Tests ---

func test_win_combat():
	var party = _create_test_party()
	var enemy = {"name": "Weak Enemy", "hp": 10, "max_hp": 10, "attack": 1}
	CombatMgr.start_combat(party, enemy)

	var form = CombatForm.new("Power Attack")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 20))
	CombatMgr.select_form(form)
	CombatMgr.execute_turn()

	assert_false(CombatMgr.is_in_combat())

func test_flee():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	var report = CombatMgr.flee()
	assert_not_null(report)
	assert_eq(report.outcome, CombatReport.Outcome.FLED)
	assert_false(CombatMgr.is_in_combat())

func test_flee_returns_report():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	# Do some combat first
	var form = CombatForm.new("Attack")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))
	CombatMgr.select_form(form)
	CombatMgr.execute_turn()

	if CombatMgr.is_in_combat():
		var report = CombatMgr.flee()
		assert_gt(report.turns_taken, 0)
		assert_eq(report.enemy_name, "Goblin")

# --- HP Percentage Tests ---

func test_get_party_hp_percent():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	assert_eq(CombatMgr.get_party_hp_percent(), 1.0)

	CombatMgr.party_hp = 50
	assert_eq(CombatMgr.get_party_hp_percent(), 0.5)

func test_get_enemy_hp_percent():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	assert_eq(CombatMgr.get_enemy_hp_percent(), 1.0)

	CombatMgr.enemy_hp = 25
	assert_eq(CombatMgr.get_enemy_hp_percent(), 0.5)

# --- Query Tests ---

func test_get_current_turn():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	assert_eq(CombatMgr.get_current_turn(), 0)

	var form = CombatForm.new("Attack")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))
	CombatMgr.select_form(form)
	CombatMgr.execute_turn()

	if CombatMgr.is_in_combat():
		assert_eq(CombatMgr.get_current_turn(), 1)

func test_get_enemy_name():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	assert_eq(CombatMgr.get_enemy_name(), "Goblin")

# --- Signal Tests ---

func test_combat_started_signal():
	var party = _create_test_party()
	var enemy = _create_test_enemy()

	watch_signals(CombatMgr)
	CombatMgr.start_combat(party, enemy)
	assert_signal_emitted(CombatMgr, "combat_started")

func test_form_selected_signal():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	var form = CombatForm.new("Test")
	form.add_action(CombatAction.new())

	watch_signals(CombatMgr)
	CombatMgr.select_form(form)
	assert_signal_emitted(CombatMgr, "form_selected")

func test_turn_started_signal():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	var form = CombatForm.new("Test")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))
	CombatMgr.select_form(form)

	watch_signals(CombatMgr)
	CombatMgr.execute_turn()
	assert_signal_emitted(CombatMgr, "turn_started")

func test_combat_ended_signal():
	var party = _create_test_party()
	var enemy = _create_test_enemy()
	CombatMgr.start_combat(party, enemy)

	watch_signals(CombatMgr)
	CombatMgr.flee()
	assert_signal_emitted(CombatMgr, "combat_ended")

# --- Action Log Integration ---

func test_combat_adds_to_action_log():
	var char = GameManager.create_character("Hero")
	char.stats["hp"] = 100
	var party = GameManager.create_party("Party", [char])
	var enemy = {"name": "Weak Enemy", "hp": 5, "max_hp": 5, "attack": 1}

	var initial_log_size = char.action_log.size()

	CombatMgr.start_combat(party, enemy)
	var form = CombatForm.new("Kill")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 50))
	CombatMgr.select_form(form)
	CombatMgr.execute_turn()

	# Combat should have ended and added a log entry
	assert_gt(char.action_log.size(), initial_log_size)
