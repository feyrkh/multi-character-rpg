# Enemy.gd
# A combat enemy with stats and forms
class_name Enemy
extends RefCounted

var enemy_name: String = ""
var hp: int = 100
var max_hp: int = 100
var attack: int = 10
var defense: int = 5
var combat_forms: Array[CombatForm] = []

func _init(p_name: String = "") -> void:
	enemy_name = p_name

func get_random_form() -> CombatForm:
	if combat_forms.is_empty():
		# Return a default attack form
		var default_form = CombatForm.new("Basic Attack")
		var attack_action = CombatAction.new(CombatAction.ActionType.ATTACK, attack)
		default_form.add_action(attack_action)
		return default_form
	return combat_forms[randi() % combat_forms.size()]

func to_combat_data() -> Dictionary:
	# Convert to the dictionary format expected by CombatMgr
	return {
		"name": enemy_name,
		"hp": hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense
	}

func to_dict() -> Dictionary:
	var forms_data = []
	for form in combat_forms:
		forms_data.append(form.to_dict())

	return {
		"enemy_name": enemy_name,
		"hp": hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"combat_forms": forms_data
	}

static func from_dict(dict: Dictionary) -> Enemy:
	var enemy = Enemy.new(dict.get("enemy_name", ""))
	enemy.hp = dict.get("hp", 100)
	enemy.max_hp = dict.get("max_hp", enemy.hp)
	enemy.attack = dict.get("attack", 10)
	enemy.defense = dict.get("defense", 5)

	var forms_data = dict.get("combat_forms", [])
	for form_dict in forms_data:
		enemy.combat_forms.append(CombatForm.from_dict(form_dict))

	return enemy

static func load_from_file(path: String) -> Enemy:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open enemy file: " + path)
		return null

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("Failed to parse enemy JSON: " + path)
		return null

	return from_dict(json.data)
