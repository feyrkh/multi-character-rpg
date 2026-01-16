# Main.gd
# Root scene managing game state (title vs gameplay)
extends Control

@onready var title_screen = $TitleScreen
@onready var game_view = $GameView

func _ready() -> void:
	title_screen.new_game_requested.connect(_on_new_game)
	title_screen.continue_game_requested.connect(_on_continue_game)
	title_screen.exit_requested.connect(_on_exit)
	game_view.menu_requested.connect(_on_menu_requested)

func _on_new_game() -> void:
	_setup_new_game()
	_show_game()

func _on_continue_game() -> void:
	_load_game()
	_show_game()

func _on_exit() -> void:
	get_tree().quit()

func _on_menu_requested() -> void:
	_show_title()

func _show_title() -> void:
	title_screen.show()
	game_view.hide()

func _show_game() -> void:
	title_screen.hide()
	game_view.show()

func _setup_new_game() -> void:
	# Reset all managers
	GameManager.new_game()
	TimeMgr.reset()
	LocationMgr.reset()

	# Create Fighter character
	var fighter = GameManager.create_character("Fighter")
	fighter.days_remaining = 30
	fighter.stats.hp = 120
	fighter.stats.max_hp = 120
	fighter.stats.attack = 15
	fighter.stats.defense = 8

	# Fighter form: All-Out Attack (3x attack)
	var all_out_attack = CombatForm.new("All-Out Attack")
	all_out_attack.description = "Unleash a barrage of attacks"
	var attack_action = GameManager.get_combat_action("attack")
	if attack_action:
		for i in range(3):
			all_out_attack.add_action(attack_action)
	fighter.combat_forms.append(all_out_attack)

	# Fighter form: Defensive Posture (1x defend self, 2x defend party)
	var defensive_posture = CombatForm.new("Defensive Posture")
	defensive_posture.description = "Protect yourself and allies"
	var defend_action = GameManager.get_combat_action("defend")
	var defend_all_action = GameManager.get_combat_action("defend_all")
	if defend_action and defend_all_action:
		defensive_posture.add_action(defend_action)  # Defend self
		defensive_posture.add_action(defend_all_action)  # Defend party
		defensive_posture.add_action(defend_all_action)  # Defend party
	fighter.combat_forms.append(defensive_posture)

	# Create Cleric character
	var cleric = GameManager.create_character("Cleric")
	cleric.days_remaining = 30
	cleric.stats.hp = 100
	cleric.stats.max_hp = 100
	cleric.stats.attack = 8
	cleric.stats.defense = 12

	# Add heal and defend_all to cleric's known actions
	cleric.known_actions.append(KnownCombatAction.new("heal"))
	cleric.known_actions.append(KnownCombatAction.new("defend_all"))

	# Cleric form: Protective Aura (3x defend all)
	var protective_aura = CombatForm.new("Protective Aura")
	protective_aura.description = "Shield allies with divine power"
	if defend_all_action:
		for i in range(3):
			protective_aura.add_action(defend_all_action)
	cleric.combat_forms.append(protective_aura)

	# Cleric form: Restoration (1x defend all, 2x heal)
	var restoration = CombatForm.new("Restoration")
	restoration.description = "Heal and protect allies"
	var heal_action = GameManager.get_combat_action("heal")
	if defend_all_action and heal_action:
		restoration.add_action(defend_all_action)
		restoration.add_action(heal_action)
		restoration.add_action(heal_action)
	cleric.combat_forms.append(restoration)

	var starting_location = "World Map\\Small Village\\"
	var party = GameManager.create_party("Party", [fighter, cleric], starting_location)

	# Start the game
	game_view.start_game(party, starting_location)

func _load_game() -> void:
	# Load saved game state
	var save_path = "user://savegame.json"
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.data
			GameManager.load_state(data.get("game_manager", {}))
			TimeMgr.load_state(data.get("time_mgr", {}))
			LocationMgr.load_state(data.get("location_mgr", {}))

			# Get active party and start game
			var parties = GameManager.get_all_parties()
			if parties.size() > 0:
				var party = parties[0]
				var location = LocationMgr.get_location(party.current_location_id)
				var area_id = location.get_containing_area_id() if location else "World Map\\"
				game_view.start_game(party, area_id)

func _save_game() -> void:
	var data = {
		"game_manager": GameManager.get_state(),
		"time_mgr": TimeMgr.get_state(),
		"location_mgr": LocationMgr.get_state()
	}

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(json_string)
	file.close()
