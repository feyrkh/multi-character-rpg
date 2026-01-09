extends GutTest

func test_init_default():
	var report = CombatReport.new()
	assert_eq(report.outcome, CombatReport.Outcome.WIN)
	assert_eq(report.damage_dealt, 0)
	assert_eq(report.damage_received, 0)
	assert_eq(report.turns_taken, 0)

func test_get_outcome_string_win():
	var report = CombatReport.new()
	report.outcome = CombatReport.Outcome.WIN
	assert_eq(report.get_outcome_string(), "Victory")

func test_get_outcome_string_loss():
	var report = CombatReport.new()
	report.outcome = CombatReport.Outcome.LOSS
	assert_eq(report.get_outcome_string(), "Defeat")

func test_get_outcome_string_fled():
	var report = CombatReport.new()
	report.outcome = CombatReport.Outcome.FLED
	assert_eq(report.get_outcome_string(), "Fled")

func test_get_summary():
	var report = CombatReport.new()
	report.outcome = CombatReport.Outcome.WIN
	report.enemy_name = "Goblin"
	report.turns_taken = 3
	report.damage_dealt = 50
	report.damage_received = 20

	var summary = report.get_summary()
	assert_true(summary.contains("Victory"))
	assert_true(summary.contains("Goblin"))
	assert_true(summary.contains("3 turns"))
	assert_true(summary.contains("50 damage"))
	assert_true(summary.contains("20 damage"))

func test_to_dict():
	var report = CombatReport.new()
	report.outcome = CombatReport.Outcome.FLED
	report.damage_dealt = 100
	report.damage_received = 75
	report.turns_taken = 5
	report.enemy_name = "Dragon"

	var dict = report.to_dict()
	assert_eq(dict["outcome"], CombatReport.Outcome.FLED)
	assert_eq(dict["damage_dealt"], 100)
	assert_eq(dict["damage_received"], 75)
	assert_eq(dict["turns_taken"], 5)
	assert_eq(dict["enemy_name"], "Dragon")

func test_from_dict():
	var dict = {
		"outcome": CombatReport.Outcome.LOSS,
		"damage_dealt": 30,
		"damage_received": 150,
		"turns_taken": 10,
		"enemy_name": "Boss"
	}
	var report = CombatReport.from_dict(dict)
	assert_eq(report.outcome, CombatReport.Outcome.LOSS)
	assert_eq(report.damage_dealt, 30)
	assert_eq(report.damage_received, 150)
	assert_eq(report.turns_taken, 10)
	assert_eq(report.enemy_name, "Boss")

func test_serialization_roundtrip():
	var original = CombatReport.new()
	original.outcome = CombatReport.Outcome.WIN
	original.damage_dealt = 200
	original.damage_received = 50
	original.turns_taken = 7
	original.enemy_name = "Final Boss"

	var dict = original.to_dict()
	var restored = CombatReport.from_dict(dict)

	assert_eq(restored.outcome, original.outcome)
	assert_eq(restored.damage_dealt, original.damage_dealt)
	assert_eq(restored.damage_received, original.damage_received)
	assert_eq(restored.turns_taken, original.turns_taken)
	assert_eq(restored.enemy_name, original.enemy_name)
