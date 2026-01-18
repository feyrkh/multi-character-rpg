# GameView.gd
# Main gameplay container
extends Control

signal menu_requested()

@onready var location_view = $LocationView
@onready var calendar_label: Label = $HUD/TopBar/CalendarPanel/CalendarLabel
@onready var menu_button: Button = $HUD/TopBar/MenuButton
@onready var forms_button: Button = $HUD/TopBar/FormsButton
@onready var explore_button: Button = $HUD/BottomBar/ExploreButton
@onready var combat_view = $CombatView
@onready var combat_forms_view = $CombatFormsView

var _current_party: Party
var _current_composite_event: CompositeEvent = null

func _ready() -> void:
	menu_button.pressed.connect(_on_menu_pressed)
	forms_button.pressed.connect(_on_forms_pressed)
	# Exploration now happens per-location via LocationNode buttons, not from HUD
	explore_button.hide()
	location_view.location_clicked.connect(_on_location_clicked)
	location_view.exit_clicked.connect(_on_exit_clicked)
	location_view.enter_requested.connect(_on_enter_requested)
	location_view.explore_requested.connect(_on_location_explore_requested)
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

func _on_location_explore_requested(location_id: String) -> void:
	"""Handle exploration request from a location node"""
	if _current_party == null:
		return

	var target_loc = LocationMgr.get_location(location_id)
	if target_loc == null:
		return

	# Handle exploration event
	if target_loc.potential_events.size() > 0:
		_handle_exploration_event(target_loc)

func _handle_exploration_event(location: Location) -> void:
	"""Handle new exploration event system"""
	# Pick random event
	var event_path = location.potential_events[randi() % location.potential_events.size()]

	# Load and execute
	var event = ExplorationEvent.load_from_file(event_path)
	if event == null:
		push_error("Failed to load event: " + event_path)
		return

	# Store reference if it's a composite event
	if event is CompositeEvent:
		_current_composite_event = event
	else:
		_current_composite_event = null

	event.event_completed.connect(_on_event_completed)
	event.event_failed.connect(_on_event_failed)

	var context = {"party": _current_party, "location": location, "game_view": self}
	event.execute(context)

func _on_event_completed(success: bool, data: Dictionary) -> void:
	"""Route completed event to appropriate handler"""
	print("[GameView] _on_event_completed called, data keys: %s" % [data.keys()])
	print("[GameView] Has enemies: %s, Has dialogue: %s, Has discovery: %s, Has composite_context: %s" % [
		data.has("enemies"),
		data.has("dialogue_text") or data.has("dialogue_file"),
		data.has("discovered_locations"),
		data.has("composite_context")
	])

	# Check for composite event completion FIRST
	# If data ONLY has composite_context (and maybe party/location/game_view), the event is done
	if data.has("composite_context") and not data.has("enemies") and not data.has("dialogue_text") and not data.has("discovered_locations"):
		print("[GameView] Composite event finished - showing location view")
		# Composite event finished all steps
		_current_composite_event = null
		location_view.show()
	# Route to appropriate handler based on what's in data
	elif data.has("enemies"):
		print("[GameView] Routing to combat handler")
		_handle_combat_event(data)
	elif data.has("dialogue_text") or data.has("dialogue_file"):
		print("[GameView] Routing to dialogue handler")
		_handle_dialogue_event(data)
	elif data.has("discovered_locations"):
		print("[GameView] Routing to discovery handler")
		_handle_discovery_event(data)

func _handle_combat_event(data: Dictionary) -> void:
	"""Handle combat event completion"""
	print("[GameView] _handle_combat_event called")
	var enemies = data.get("enemies", [])
	print("[GameView] Enemies array size: %d" % enemies.size())
	if enemies.is_empty():
		print("[GameView] No enemies, returning")
		return
	print("[GameView] Hiding location view and starting combat")
	location_view.hide()
	combat_view.start_combat(_current_party, enemies)

func _handle_dialogue_event(data: Dictionary) -> void:
	"""Handle dialogue event completion"""
	# Check if DialogueManager singleton exists
	if not Engine.has_singleton("DialogueManager"):
		push_error("DialogueManager singleton not found - dialogue_manager addon may not be enabled")
		location_view.show()
		return

	var dialogue_manager = Engine.get_singleton("DialogueManager")
	var dialogue_mode = data.get("dialogue_mode", "inline")
	var dialogue_resource: DialogueResource

	if dialogue_mode == "inline":
		# Create dialogue resource from inline text
		var text = data.get("dialogue_text", "")
		# Convert to dialogue_manager format
		var dialogue_text = "~ start\n" + text + "\n=> END"
		dialogue_resource = dialogue_manager.create_resource_from_text(dialogue_text)
	else:
		# Load dialogue file and let dialogue_manager import it
		var file_path = data.get("dialogue_file", "")
		# dialogue_manager automatically compiles .dialogue files to .tres
		# We load the compiled resource
		var tres_path = file_path.replace(".dialogue", ".dialogue.import")
		if FileAccess.file_exists(tres_path):
			# Get the imported resource path from the .import file
			dialogue_resource = load(file_path)
		else:
			push_error("Dialogue file not found or not imported: " + file_path)
			location_view.show()
			return

	if dialogue_resource == null:
		push_error("Failed to create dialogue resource")
		location_view.show()
		return

	# Load custom balloon scene
	var balloon_scene = load("res://scenes/ui/event_dialogue_balloon.tscn")
	if balloon_scene == null:
		push_error("Failed to load event_dialogue_balloon.tscn")
		location_view.show()
		return

	# Show dialogue using dialogue_manager
	var title = data.get("dialogue_title", "start")
	var balloon = dialogue_manager.show_dialogue_balloon_scene(
		balloon_scene,
		dialogue_resource,
		title,
		[GameManager, LocationMgr, TimeMgr]
	)

	# Enable choice capture if requested
	if data.get("capture_choice", false):
		var choice_var = data.get("choice_variable", "choice")
		if balloon.has_method("enable_choice_capture"):
			balloon.enable_choice_capture(choice_var)

		# Connect to capture signal
		if balloon.has_signal("choice_captured"):
			balloon.choice_captured.connect(_on_dialogue_choice_captured, CONNECT_ONE_SHOT)

	# Setup visuals if balloon supports it
	if balloon.has_method("setup_visuals"):
		await balloon.setup_visuals(
			data.get("left_portrait", ""),
			data.get("right_portrait", ""),
			data.get("background_image", ""),
			data.get("central_overlay", "")
		)

	# Hide location view during dialogue
	location_view.hide()

	# Connect to dialogue end to show location view again
	dialogue_manager.dialogue_ended.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)

func _on_dialogue_choice_captured(choice_id: String, choice_text: String, choice_variable: String) -> void:
	"""Called when a dialogue choice is captured for branching"""
	# Store in composite context for condition evaluation
	if _current_composite_event != null:
		var step_key = "step_%d" % _current_composite_event.current_step
		if not _current_composite_event._context["composite_context"].has(step_key):
			_current_composite_event._context["composite_context"][step_key] = {}

		_current_composite_event._context["composite_context"][step_key]["choice_id"] = choice_id
		_current_composite_event._context["composite_context"][step_key]["choice_text"] = choice_text
		if choice_variable != "":
			_current_composite_event._context["composite_context"][step_key]["choice_variable"] = choice_variable

func _on_dialogue_finished(_resource: DialogueResource) -> void:
	"""Called when dialogue finishes"""
	print("[GameView] _on_dialogue_finished called")
	location_view.show()

	# If we're in a composite event, continue to next step
	# Additional data (dialogue choice) is already stored via _on_dialogue_choice_captured
	if _current_composite_event != null:
		print("[GameView] In composite event, calling continue_to_next_step")
		_current_composite_event.continue_to_next_step()
	else:
		print("[GameView] Not in composite event")

func _handle_discovery_event(data: Dictionary) -> void:
	"""Handle discovery event completion"""
	var discovered = data.get("discovered_locations", [])
	if discovered.size() > 0:
		# Reload to show newly discovered locations
		location_view.load_area(location_view.current_area_id, _current_party.current_location_id)

		# Show notification
		var msg = data.get("message_text", "")
		if msg == "" and data.get("show_message", true):
			msg = "Discovered: " + ", ".join(discovered)
		if msg != "":
			print("DISCOVERY: " + msg)  # TODO: Replace with toast notification

	# If we're in a composite event, continue to next step
	if _current_composite_event != null:
		_current_composite_event.continue_to_next_step()

func _on_event_failed(error: String) -> void:
	"""Handle event failure"""
	push_error("Event failed: " + error)

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

func _on_time_changed(_cur_month:int, _cur_day: int) -> void:
	_update_calendar()

func _update_calendar() -> void:
	calendar_label.text = "Month %d, Day %d" % [TimeMgr.current_month, TimeMgr.current_day]

func _on_menu_pressed() -> void:
	menu_requested.emit()

func _on_forms_pressed() -> void:
	if _current_party == null:
		return
	combat_forms_view.open(_current_party)

# --- Combat ---

func _on_combat_finished(report: CombatReport) -> void:
	print("[GameView] _on_combat_finished called, outcome: %s" % report.get_outcome_string())
	# Show the map again
	location_view.show()

	# Display combat summary (could be a popup, for now just log)
	print("Combat ended: " + report.get_summary())

	# If we're in a composite event, continue to next step with combat outcome data
	if _current_composite_event != null:
		print("[GameView] In composite event, preparing combat data for continue_to_next_step")
		# Pass combat outcome data for branching
		var combat_data = {
			"combat_outcome": report.get_outcome_string(),  # "Victory", "Defeat", "Fled"
			"combat_result": report.outcome,  # Enum: WIN=0, LOSS=1, FLED=2
			"damage_dealt": report.damage_dealt,
			"damage_received": report.damage_received,
			"turns_taken": report.turns_taken,
			"enemy_name": report.enemy_name
		}
		print("[GameView] Combat data: %s" % [combat_data])
		_current_composite_event.continue_to_next_step(combat_data)
	else:
		print("[GameView] Not in composite event")
