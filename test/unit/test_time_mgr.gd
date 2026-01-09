extends GutTest

var _registry: InstanceRegistry

func before_each():
	_registry = InstanceRegistry.get_registry()
	_registry.clear_all()
	GameManager.new_game()
	TimeMgr.reset()

func after_each():
	_registry.clear_all()

# --- Calendar Tests ---

func test_initial_state():
	assert_eq(TimeMgr.current_month, 1)
	assert_eq(TimeMgr.current_day, 1)

# --- Time Spending Tests ---

func test_can_spend_time_true():
	var char = GameManager.create_character("Hero")
	char.days_remaining = 20
	var party = GameManager.create_party("Party", [char])
	assert_true(TimeMgr.can_spend_time(party, 10))

func test_can_spend_time_false():
	var char = GameManager.create_character("Hero")
	char.days_remaining = 5
	var party = GameManager.create_party("Party", [char])
	assert_false(TimeMgr.can_spend_time(party, 10))

func test_can_spend_time_multiple_members():
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	char1.days_remaining = 20
	char2.days_remaining = 5
	var party = GameManager.create_party("Party", [char1, char2])
	# Should fail because char2 doesn't have enough time
	assert_false(TimeMgr.can_spend_time(party, 10))

func test_spend_time_success():
	var char = GameManager.create_character("Hero")
	char.days_remaining = 20
	var party = GameManager.create_party("Party", [char])
	var result = TimeMgr.spend_time(party, 5)
	assert_true(result)
	assert_eq(char.days_remaining, 15)

func test_spend_time_failure():
	var char = GameManager.create_character("Hero")
	char.days_remaining = 3
	var party = GameManager.create_party("Party", [char])
	var result = TimeMgr.spend_time(party, 5)
	assert_false(result)
	assert_eq(char.days_remaining, 3)

func test_spend_time_multiple_members():
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	char1.days_remaining = 20
	char2.days_remaining = 20
	var party = GameManager.create_party("Party", [char1, char2])
	TimeMgr.spend_time(party, 10)
	assert_eq(char1.days_remaining, 10)
	assert_eq(char2.days_remaining, 10)

func test_get_party_available_time():
	var char1 = GameManager.create_character("Hero1")
	var char2 = GameManager.create_character("Hero2")
	char1.days_remaining = 20
	char2.days_remaining = 15
	var party = GameManager.create_party("Party", [char1, char2])
	# Should return minimum
	assert_eq(TimeMgr.get_party_available_time(party), 15)

func test_get_character_remaining_time():
	var char = GameManager.create_character("Hero")
	char.days_remaining = 25
	assert_eq(TimeMgr.get_character_remaining_time(char), 25)

# --- Month Management Tests ---

func test_advance_month():
	TimeMgr.current_month = 1
	TimeMgr.current_day = 15
	TimeMgr.advance_month()
	assert_eq(TimeMgr.current_month, 2)
	assert_eq(TimeMgr.current_day, 1)

func test_advance_month_wraps_year():
	TimeMgr.current_month = 12
	TimeMgr.advance_month()
	assert_eq(TimeMgr.current_month, 1)

func test_advance_month_resets_character_time():
	var char = GameManager.create_character("Hero")
	char.days_remaining = 5
	TimeMgr.advance_month()
	assert_eq(char.days_remaining, 30)

func test_advance_day():
	TimeMgr.current_day = 10
	TimeMgr.advance_day()
	assert_eq(TimeMgr.current_day, 11)

func test_advance_day_triggers_month():
	TimeMgr.current_month = 1
	TimeMgr.current_day = 30
	TimeMgr.advance_day()
	assert_eq(TimeMgr.current_month, 2)
	assert_eq(TimeMgr.current_day, 1)

func test_advance_multiple_days():
	TimeMgr.current_day = 1
	TimeMgr.advance_day(5)
	assert_eq(TimeMgr.current_day, 6)

# --- State Management ---

func test_get_state():
	TimeMgr.current_month = 7
	TimeMgr.current_day = 22
	var state = TimeMgr.get_state()
	assert_eq(state["current_month"], 7)
	assert_eq(state["current_day"], 22)

func test_load_state():
	var state = {"current_month": 9, "current_day": 15}
	TimeMgr.load_state(state)
	assert_eq(TimeMgr.current_month, 9)
	assert_eq(TimeMgr.current_day, 15)

func test_reset():
	TimeMgr.current_month = 5
	TimeMgr.current_day = 20
	TimeMgr.reset()
	assert_eq(TimeMgr.current_month, 1)
	assert_eq(TimeMgr.current_day, 1)

# --- Signal Tests ---

func test_month_changed_signal():
	watch_signals(TimeMgr)
	TimeMgr.advance_month()
	assert_signal_emitted(TimeMgr, "month_changed")

func test_day_changed_signal():
	watch_signals(TimeMgr)
	TimeMgr.advance_day()
	assert_signal_emitted(TimeMgr, "day_changed")

func test_time_spent_signal():
	var char = GameManager.create_character("Hero")
	var party = GameManager.create_party("Party", [char])
	watch_signals(TimeMgr)
	TimeMgr.spend_time(party, 5)
	assert_signal_emitted(TimeMgr, "time_spent")
