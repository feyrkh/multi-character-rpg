# LocationNode.gd
# Clickable node representing a location on the map
extends Control

signal clicked(location_id: String)
signal enter_requested(location_id: String)

var location_id: String = ""

@onready var icon_rect: ColorRect = $VBoxContainer/IconContainer/IconRect
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var exploration_label: Label = $VBoxContainer/ExplorationLabel
@onready var character_icons: HBoxContainer = $VBoxContainer/CharacterIcons
@onready var enter_button: Button = $VBoxContainer/EnterButton

func _ready() -> void:
	enter_button.pressed.connect(_on_enter_pressed)
	enter_button.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit(location_id)
			accept_event()

func setup(location: Location, exploration_percent: float = 100.0) -> void:
	location_id = location.id
	name_label.text = location.display_name

	# Show exploration percentage if not 100%
	if exploration_percent >= 100.0:
		exploration_label.visible = false
	else:
		exploration_label.visible = true
		exploration_label.text = "%d%% explored" % int(exploration_percent)

	# Update icon color based on discovery state
	if location.is_discovered:
		icon_rect.color = Color(0.5, 0.5, 0.5, 1)  # Gray for discovered
	else:
		icon_rect.color = Color(0.2, 0.2, 0.2, 0.5)  # Dark for undiscovered

func set_highlighted(highlighted: bool) -> void:
	if highlighted:
		icon_rect.color = Color(0.7, 0.7, 0.3, 1)  # Yellow highlight
	else:
		icon_rect.color = Color(0.5, 0.5, 0.5, 1)  # Normal gray

func set_current(is_current: bool, has_interior: bool = false) -> void:
	enter_button.visible = is_current and has_interior
	if is_current:
		icon_rect.color = Color(0.3, 0.6, 0.9, 1)  # Blue for current location
	else:
		icon_rect.color = Color(0.5, 0.5, 0.5, 1)  # Normal gray

func update_characters(characters: Array[PlayableCharacter]) -> void:
	# Clear existing icons
	for child in character_icons.get_children():
		child.queue_free()

	# Add character indicators (simple colored squares for now)
	for character in characters:
		var indicator = ColorRect.new()
		indicator.custom_minimum_size = Vector2(8, 8)
		indicator.color = Color(0.3, 0.6, 0.9, 1)  # Blue for party members
		character_icons.add_child(indicator)

func _on_enter_pressed() -> void:
	enter_requested.emit(location_id)
