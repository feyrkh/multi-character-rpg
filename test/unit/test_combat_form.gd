extends GutTest

func test_init_default():
	var form = CombatForm.new()
	assert_eq(form.form_name, "")
	assert_eq(form.description, "")
	assert_eq(form.actions.size(), 0)

func test_init_with_name():
	var form = CombatForm.new("Dragon Stance")
	assert_eq(form.form_name, "Dragon Stance")

func test_add_action():
	var form = CombatForm.new("Test Form")
	var action = CombatAction.new(CombatAction.ActionType.ATTACK, 10)
	form.add_action(action)
	assert_eq(form.get_action_count(), 1)

func test_get_action_count():
	var form = CombatForm.new("Multi-hit")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))
	assert_eq(form.get_action_count(), 3)

func test_get_total_power():
	var form = CombatForm.new("Power Combo")
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 10))
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 15))
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 20))
	assert_eq(form.get_total_power(), 45)

func test_get_total_power_with_defend():
	var form = CombatForm.new("Defensive")
	form.add_action(CombatAction.new(CombatAction.ActionType.DEFEND, 0))
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 10))
	assert_eq(form.get_total_power(), 10)

func test_to_dict():
	var form = CombatForm.new("Swift Strike")
	form.description = "A quick attack sequence"
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 8))
	form.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 12))

	var dict = form.to_dict()
	assert_eq(dict["form_name"], "Swift Strike")
	assert_eq(dict["description"], "A quick attack sequence")
	assert_eq(dict["actions"].size(), 2)

func test_from_dict():
	var dict = {
		"form_name": "Heavy Blow",
		"description": "A powerful single strike",
		"actions": [
			{
				"action_type": CombatAction.ActionType.ATTACK,
				"target_type": CombatAction.TargetType.ENEMY,
				"power": 30,
				"skill_id": "",
				"item_id": "",
				"description": ""
			}
		]
	}
	var form = CombatForm.from_dict(dict)
	assert_eq(form.form_name, "Heavy Blow")
	assert_eq(form.description, "A powerful single strike")
	assert_eq(form.get_action_count(), 1)
	assert_eq(form.actions[0].power, 30)

func test_serialization_roundtrip():
	var original = CombatForm.new("Combo Attack")
	original.description = "A three-hit combo"
	original.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 5))
	original.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 10))
	original.add_action(CombatAction.new(CombatAction.ActionType.ATTACK, 15))

	var dict = original.to_dict()
	var restored = CombatForm.from_dict(dict)

	assert_eq(restored.form_name, original.form_name)
	assert_eq(restored.description, original.description)
	assert_eq(restored.get_action_count(), original.get_action_count())
	assert_eq(restored.get_total_power(), original.get_total_power())
