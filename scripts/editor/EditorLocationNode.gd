# EditorLocationNode.gd
# A draggable location node for the location editor canvas
extends Control

signal selected(node_name: String)
signal moved(node_name: String, new_position: Vector2)

var node_name: String = ""
var is_selected: bool = false

var _is_dragging: bool = false
var _drag_start_world_mouse: Vector2 = Vector2.ZERO
var _drag_start_center: Vector2 = Vector2.ZERO
var _camera: Control = null  # Reference to DraggableCamera2D

@onready var icon_rect: ColorRect = $VBoxContainer/IconRect
@onready var name_label: Label = $VBoxContainer/NameLabel

const COLOR_NORMAL = Color(0.5, 0.5, 0.5, 1.0)
const COLOR_SELECTED = Color(0.3, 0.6, 0.9, 1.0)
const COLOR_LINK_SOURCE = Color(0.9, 0.6, 0.2, 1.0)

func _ready() -> void:
	# Ensure we can receive mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Find and cache the camera reference
	_camera = _find_camera()

func setup(p_name: String, p_display_name: String, p_position: Vector2) -> void:
	node_name = p_name
	if name_label:
		name_label.text = p_display_name
	# Position so that the node is centered on p_position
	# We need to wait for size to be calculated
	await get_tree().process_frame
	position = p_position - size / 2

func _find_camera() -> Control:
	# Walk up the tree to find the DraggableCamera2D
	var node = get_parent()
	while node:
		if "camera_position" in node and "camera_zoom" in node:
			return node
		node = node.get_parent()
	return null

func _get_mouse_world_position() -> Vector2:
	if _camera == null:
		_camera = _find_camera()
	if _camera:
		var viewport_center = _camera.size / 2.0
		var local_mouse = _camera.get_local_mouse_position()
		var offset_from_center = local_mouse - viewport_center
		return _camera.camera_position + offset_from_center / _camera.camera_zoom
	# Fallback to parent local space
	return get_parent().get_local_mouse_position()

func set_display_name(p_name: String) -> void:
	name_label.text = p_name

func set_selected(p_selected: bool) -> void:
	is_selected = p_selected
	_update_color()

func set_link_source(is_source: bool) -> void:
	if is_source:
		icon_rect.color = COLOR_LINK_SOURCE
	else:
		_update_color()

func _update_color() -> void:
	if icon_rect:
		if is_selected:
			icon_rect.color = COLOR_SELECTED
		else:
			icon_rect.color = COLOR_NORMAL

func get_center_position() -> Vector2:
	return position + size / 2

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				selected.emit(node_name)
				_is_dragging = true
				# Store initial world positions for drag calculation
				_drag_start_world_mouse = _get_mouse_world_position()
				_drag_start_center = get_center_position()
				accept_event()
			else:
				if _is_dragging:
					_is_dragging = false
					moved.emit(node_name, get_center_position())
					accept_event()

	elif event is InputEventMouseMotion:
		if _is_dragging:
			# Calculate new position in world coordinates
			var current_world_mouse = _get_mouse_world_position()
			var delta = current_world_mouse - _drag_start_world_mouse
			var new_center = _drag_start_center + delta
			position = new_center - size / 2
			accept_event()
