tool
extends TabContainer

onready var editor:TE_Editor = owner

var mouse_over:bool = false

func _ready():
	var _e
	_e = connect("mouse_entered", self, "set", ["mouse_over", true])
	_e = connect("mouse_exited", self, "set", ["mouse_over", false])

func _input(e):
	if mouse_over and e is InputEventMouseButton and e.pressed:
		if e.button_index == BUTTON_WHEEL_DOWN:
			prev()
			get_tree().set_input_as_handled()
		
		elif e.button_index == BUTTON_WHEEL_UP:
			next()
			get_tree().set_input_as_handled()
	
#	if not editor.is_plugin_active():
#		return

func prev():
	set_current_tab(wrapi(current_tab - 1, 0, get_child_count()))

func next():
	set_current_tab(wrapi(current_tab + 1, 0, get_child_count()))
	
