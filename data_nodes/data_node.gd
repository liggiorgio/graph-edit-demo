class_name DataNode
extends GraphNode


signal popup_request(position: Vector2)
signal user_update


@export var hide_input_on_link: bool = false
var inputs: Array = []
var params: Array = []
var outputs: Array = []
@onready var params_vbox: VBoxContainer = $Parameters


func _ready() -> void:
	size = Vector2.ZERO
	inputs.resize(get_connection_input_count())
	params.resize(params_vbox.get_child_count())
	outputs.resize(get_connection_output_count())
	
	for iid in inputs.size():
		var field = get_child(get_connection_input_slot(iid)).get_child(1)
		if field is SpinBox:
			field.value_changed.connect(_on_fields_updated)
	
	for pid in params.size():
		var field = params_vbox.get_child(pid).get_child(1)
		if field is SpinBox:
			field.value_changed.connect(_on_fields_updated)


func _gui_input(_event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		popup_request.emit(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func evaluate(binds: Dictionary) -> void:
	bind_input(binds)
	fetch()
	function()
	push()


func bind_input(binds: Dictionary) -> void:
	for iid in inputs.size():
		var field = get_child(get_connection_input_slot(iid)).get_child(1)
		if binds.has(iid):
			if field is SpinBox:
				field.set_value_no_signal(binds[iid])
				field.editable = false
				field.visible = not hide_input_on_link
		else:
			field.editable = true
			field.visible = true


func fetch() -> void:
	for iid in inputs.size():
		var field = get_child(get_connection_input_slot(iid)).get_child(1)
		if field is SpinBox:
			inputs[iid] = field.value
	
	for pid in params.size():
		var field = params_vbox.get_child(pid).get_child(1)
		if field is SpinBox:
			params[pid] = field.value


func function() -> void:
	pass


func push() -> void:
	for oid in outputs.size():
		var field = get_child(get_connection_output_slot(oid)).get_child(0)
		if field is Label:
			field.text = str(outputs[oid])


func _on_fields_updated(_value) -> void:
	print(name, ": values updated by the user!")
	user_update.emit()
