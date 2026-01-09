extends GutTest

func test_init_default():
	var action = CombatAction.new()
	assert_eq(action.action_type, CombatAction.ActionType.ATTACK)
	assert_eq(action.power, 10)
	assert_eq(action.target_type, CombatAction.TargetType.ENEMY)

func test_init_with_values():
	var action = CombatAction.new(CombatAction.ActionType.DEFEND, 5)
	assert_eq(action.action_type, CombatAction.ActionType.DEFEND)
	assert_eq(action.power, 5)

func test_get_action_name_attack():
	var action = CombatAction.new(CombatAction.ActionType.ATTACK)
	assert_eq(action.get_action_name(), "Attack")

func test_get_action_name_defend():
	var action = CombatAction.new(CombatAction.ActionType.DEFEND)
	assert_eq(action.get_action_name(), "Defend")

func test_get_action_name_skill():
	var action = CombatAction.new(CombatAction.ActionType.SKILL)
	action.skill_id = "fireball"
	assert_eq(action.get_action_name(), "fireball")

func test_get_action_name_item():
	var action = CombatAction.new(CombatAction.ActionType.ITEM)
	action.item_id = "health_potion"
	assert_eq(action.get_action_name(), "health_potion")

func test_to_dict():
	var action = CombatAction.new(CombatAction.ActionType.SKILL, 25)
	action.target_type = CombatAction.TargetType.ALL_ENEMIES
	action.skill_id = "thunderbolt"
	action.description = "A powerful lightning attack"

	var dict = action.to_dict()
	assert_eq(dict["action_type"], CombatAction.ActionType.SKILL)
	assert_eq(dict["target_type"], CombatAction.TargetType.ALL_ENEMIES)
	assert_eq(dict["power"], 25)
	assert_eq(dict["skill_id"], "thunderbolt")
	assert_eq(dict["description"], "A powerful lightning attack")

func test_from_dict():
	var dict = {
		"action_type": CombatAction.ActionType.ITEM,
		"target_type": CombatAction.TargetType.SELF,
		"power": 0,
		"skill_id": "",
		"item_id": "mana_potion",
		"description": "Restores MP"
	}
	var action = CombatAction.from_dict(dict)
	assert_eq(action.action_type, CombatAction.ActionType.ITEM)
	assert_eq(action.target_type, CombatAction.TargetType.SELF)
	assert_eq(action.item_id, "mana_potion")

func test_serialization_roundtrip():
	var original = CombatAction.new(CombatAction.ActionType.ATTACK, 15)
	original.target_type = CombatAction.TargetType.ENEMY
	original.description = "Basic attack"

	var dict = original.to_dict()
	var restored = CombatAction.from_dict(dict)

	assert_eq(restored.action_type, original.action_type)
	assert_eq(restored.target_type, original.target_type)
	assert_eq(restored.power, original.power)
	assert_eq(restored.description, original.description)
