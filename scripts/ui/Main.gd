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

	# Create starting character and party
	var hero = GameManager.create_character("Hero")
	hero.days_remaining = 30

	var starting_location = "World Map\\Small Village\\"
	var party = GameManager.create_party("Party", [hero], starting_location)

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
