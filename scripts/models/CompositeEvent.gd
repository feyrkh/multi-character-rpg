# CompositeEvent.gd
# Chains multiple events sequentially or with branching logic
class_name CompositeEvent
extends ExplorationEvent

var steps: Array[Dictionary] = []  # Array of event definitions
var current_step: int = 0
var branch_mode: String = "sequential"  # "sequential" or "branching"
var visited_steps: Array[int] = []  # Track execution path for debugging
var _current_event: ExplorationEvent = null
var _context: Dictionary = {}

func _init() -> void:
	event_type = EventType.COMPOSITE

func execute(context: Dictionary) -> void:
	event_started.emit()
	current_step = 0
	visited_steps = []
	_context = context
	_context["composite_context"] = {}
	_execute_next_step()

func _execute_next_step() -> void:
	if current_step >= steps.size():
		# All steps completed - emit only composite_context to signal completion
		event_completed.emit(true, {"composite_context": _context["composite_context"]})
		return

	# Track visited steps for debugging
	visited_steps.append(current_step)

	var step_data = steps[current_step]
	var step_event = _create_event_from_data(step_data)

	if step_event == null:
		event_failed.emit("Failed to create step event at index " + str(current_step))
		return

	_current_event = step_event
	_current_event.event_completed.connect(_on_step_completed)
	_current_event.event_failed.connect(_on_step_failed)
	_current_event.execute(_context)

func _on_step_completed(success: bool, step_data: Dictionary) -> void:
	# Store step results in composite context
	_context["composite_context"]["step_" + str(current_step)] = step_data

	# Emit this step's completion so GameView can handle it
	# GameView will call continue_to_next_step() when done
	event_completed.emit(success, step_data)

func continue_to_next_step(additional_data: Dictionary = {}) -> void:
	"""Called by GameView after it finishes handling the current step"""
	# Store additional outcome data in current step's context
	var step_key = "step_%d" % current_step
	if additional_data.size() > 0:
		if not _context["composite_context"].has(step_key):
			_context["composite_context"][step_key] = {}
		_context["composite_context"][step_key].merge(additional_data)

	# Resolve next step using branching logic
	var step_data = steps[current_step]
	current_step = _resolve_next_step(step_data)

	# Check for end condition (-1 or out of bounds)
	if current_step < 0 or current_step >= steps.size():
		# Emit ONLY the composite_context to signal completion
		# Don't include the full context which has leftover step data (like enemies)
		event_completed.emit(true, {"composite_context": _context["composite_context"]})
		return

	_execute_next_step()

func _on_step_failed(error: String) -> void:
	event_failed.emit("Step " + str(current_step) + " failed: " + error)

func _resolve_next_step(step_data: Dictionary) -> int:
	"""Determine the next step based on step data and context"""
	print("[CompositeEvent] _resolve_next_step for current step %d" % current_step)
	print("[CompositeEvent] Step data keys: %s" % [step_data.keys()])

	if not step_data.has("next_step"):
		# Default: sequential progression
		print("[CompositeEvent] No next_step field found, using sequential progression")
		return current_step + 1

	var next = step_data["next_step"]
	print("[CompositeEvent] next_step value type: %s" % [type_string(typeof(next))])
	print("[CompositeEvent] next_step value: %s" % [str(next)])

	# Simple integer = direct jump (backward compatible)
	if next is int:
		print("[CompositeEvent] next_step is int, jumping to %d" % next)
		return next

	# Dictionary with branches
	if next is Dictionary:
		print("[CompositeEvent] next_step is Dictionary, evaluating branches")
		return _evaluate_branches(next)

	# Fallback
	print("[CompositeEvent] Unexpected next_step type, using sequential")
	return current_step + 1

func _evaluate_branches(branch_config: Dictionary) -> int:
	"""Evaluate branch conditions and return target step"""
	var branches = branch_config.get("branches", [])

	for branch in branches:
		var condition = branch.get("condition", "true")
		if ConditionEvaluator.evaluate(condition, _context):
			# Check for inline steps vs goto
			if branch.has("steps"):
				# Execute inline branch (NOT IMPLEMENTED YET)
				push_warning("Inline branches not yet supported, using goto_step instead")
				return branch.get("goto_step", current_step + 1)
			else:
				return branch.get("goto_step", current_step + 1)

	# No matching branch, use default
	return branch_config.get("default", current_step + 1)

static func _create_event_from_data(data: Dictionary) -> ExplorationEvent:
	var type_string = data.get("event_type", "")
	match type_string:
		"combat":
			return CombatEvent.from_dict(data)
		"dialogue":
			return DialogueEvent.from_dict(data)
		"discovery":
			return DiscoveryEvent.from_dict(data)
		_:
			push_error("Unknown composite step type: " + type_string)
			return null

static func from_dict(data: Dictionary) -> CompositeEvent:
	var event = CompositeEvent.new()
	event.event_id = data.get("event_id", "")
	event.branch_mode = data.get("branch_mode", "sequential")

	print("[CompositeEvent] Loading from dict, branch_mode: %s" % event.branch_mode)

	var steps_data = data.get("steps", [])
	print("[CompositeEvent] Loading %d steps" % steps_data.size())

	for i in range(steps_data.size()):
		var step = steps_data[i]
		print("[CompositeEvent] Step %d has next_step: %s" % [i, step.has("next_step")])
		if step.has("next_step"):
			print("[CompositeEvent] Step %d next_step type: %s" % [i, type_string(typeof(step["next_step"]))])
		event.steps.append(step)

	return event

func to_dict() -> Dictionary:
	var base = super.to_dict()
	base["branch_mode"] = branch_mode
	base["steps"] = steps
	return base
