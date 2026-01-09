# GameView.gd
# Main gameplay container
extends Control

signal menu_requested()

@onready var location_view = $LocationView
@onready var calendar_label: Label = $HUD/TopBar/CalendarPanel/CalendarLabel
@onready var menu_button: Button = $HUD/TopBar/MenuButton
@onready var explore_button: Button = $HUD/BottomBar/ExploreButton
@onready var combat_view = $CombatView

var _current_party: Party

func _ready() -> void:
	menu_button.pressed.connect(_on_menu_pressed)
	explore_button.pressed.connect(_on_explore_pressed)
	location_view.location_clicked.connect(_on_location_clicked)
	location_view.exit_clicked.connect(_on_exit_clicked)
	location_view.enter_requested.connect(_on_enter_requested)
	LocationMgr.party_moved.connect(_on_party_moved)
	LocationMgr.move_confirmed.connect(_on_move_confirmed)
	LocationMgr.move_cancelled.connect(_on_move_cancelled)
	TimeMgr.day_changed.connect(_on_time_changed)
	TimeMgr.month_changed.connect(_on_time_changed)
	combat_view.combat_finished.connect(_on_combat_finished)
	_update_calendar()

func start_game(party: Party, starting_area_id: String) -> void:
	_current_party = party
	location_view.load_area(starting_area_id, party.current_location_id)
	_update_calendar()
	_update_explore_button()

	# Center on party location
	if party:
		location_view.center_on_location(party.current_location_id)

func _on_location_clicked(location_id: String) -> void:
	if _current_party == null:
		return

	var current_loc = _current_party.current_location_id

	# If clicking current location, do nothing
	if location_id == current_loc:
		return

	var target_location = LocationMgr.get_location(location_id)
	if target_location == null:
		return

	# Check if we're in an instant-travel area
	if location_view.is_instant_travel_area():
		# In instant-travel areas, clicking enters the location directly
		var inside_id = location_id + "\\"
		var inside_location = LocationMgr.get_location(inside_id)
		if inside_location:
			_move_party_to(inside_id)
			location_view.load_area(inside_id, inside_id)
		return

	# For non-instant-travel areas, use pathfinding and show path preview
	if LocationMgr.can_move_party(_current_party, location_id):
		# Find path and show preview
		var path = LocationMgr.find_path(current_loc, location_id)
		location_view.show_path_preview(path)

		# Request move (will show confirmation dialog)
		LocationMgr.request_move(_current_party, location_id)

func _on_exit_clicked(parent_area_id: String) -> void:
	if _current_party == null:
		return

	# When exiting, party goes to the node representing this area in the parent
	# E.g., exiting "World Map\Small Village\" puts party at "World Map\Small Village"
	var current_area = location_view.current_area_id
	var node_in_parent = current_area.trim_suffix("\\")

	_move_party_to(node_in_parent)
	location_view.load_area(parent_area_id, node_in_parent)

func _on_enter_requested(location_id: String) -> void:
	if _current_party == null:
		return

	# Enter the location (append trailing slash)
	var inside_id = location_id + "\\"
	var inside_location = LocationMgr.get_location(inside_id)
	if inside_location:
		_move_party_to(inside_id)
		location_view.load_area(inside_id, inside_id)

func _move_party_to(location_id: String) -> void:
	# Direct move without pathfinding (for instant-travel)
	var old_location = LocationMgr.get_location(_current_party.current_location_id)
	var new_location = LocationMgr.get_location(location_id)

	_current_party.current_location_id = location_id

	# Update all party members' locations
	var members = GameManager.get_party_members(_current_party)
	for member in members:
		member.current_location_id = location_id
		LocationMgr.moved_to_location.emit(member, old_location, new_location)

	LocationMgr.party_moved.emit(_current_party, old_location, new_location)

func _on_move_confirmed(_party: Party, _target_location_id: String) -> void:
	# Clear path preview after move is confirmed
	location_view.clear_path_preview()

func _on_move_cancelled() -> void:
	# Clear path preview when move is cancelled
	location_view.clear_path_preview()

func _on_party_moved(party: Party, old_location: Location, new_location: Location) -> void:
	if party == _current_party:
		# Update the view if we moved to a different area
		var old_area = old_location.get_containing_area_id() if old_location else ""
		var new_area = new_location.get_containing_area_id() if new_location else ""

		if old_area != new_area:
			location_view.load_area(new_area, new_location.id)
		else:
			location_view.set_party_location(new_location.id)
			location_view._update_character_positions()

		location_view.center_on_location(new_location.id)
		_update_calendar()
		_update_explore_button()

func _on_time_changed(_cur_month:int, _cur_day: int) -> void:
	_update_calendar()

func _update_calendar() -> void:
	calendar_label.text = "Month %d, Day %d" % [TimeMgr.current_month, TimeMgr.current_day]

func _on_menu_pressed() -> void:
	menu_requested.emit()

# --- Explore and Combat ---

func _update_explore_button() -> void:
	if _current_party == null:
		explore_button.hide()
		return

	# Check if current location has enemies
	var current_loc = LocationMgr.get_location(_current_party.current_location_id)
	if current_loc and current_loc.potential_enemies.size() > 0:
		explore_button.show()
	else:
		explore_button.hide()

func _on_explore_pressed() -> void:
	if _current_party == null:
		return

	var current_loc = LocationMgr.get_location(_current_party.current_location_id)
	if current_loc == null or current_loc.potential_enemies.is_empty():
		return

	# Pick a random enemy from the potential enemies
	var enemy_path = current_loc.potential_enemies[randi() % current_loc.potential_enemies.size()]
	var enemy = Enemy.load_from_file(enemy_path)

	if enemy == null:
		push_error("Failed to load enemy: " + enemy_path)
		return

	# Start combat
	location_view.hide()
	explore_button.hide()
	combat_view.start_combat(_current_party, enemy)

func _on_combat_finished(report: CombatReport) -> void:
	# Show the map again
	location_view.show()
	_update_explore_button()

	# Display combat summary (could be a popup, for now just log)
	print("Combat ended: " + report.get_summary())
