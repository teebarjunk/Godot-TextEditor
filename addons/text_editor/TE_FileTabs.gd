extends TabContainer

onready var editor:TE_Editor = owner
var mouse:bool = false

func _ready():
	if not editor.is_plugin_active():
		return
	
	var _e
	_e = connect("mouse_entered", self, "set", ["mouse", true])
	_e = connect("mouse_exited", self, "set", ["mouse", false])
	
	add_font_override("font", editor.FONT_R)

func _input(e):
	if not editor.is_plugin_active():
		return
	
	if mouse and e is InputEventMouseButton and e.pressed:
		if e.button_index == BUTTON_WHEEL_DOWN:
			prev()
			get_tree().set_input_as_handled()
		
		elif e.button_index == BUTTON_WHEEL_UP:
			next()
			get_tree().set_input_as_handled()
	
	if e is InputEventKey and e.pressed and e.control and e.scancode == KEY_TAB:
		if e.shift:
			prev()
			get_tree().set_input_as_handled()
		else:
			next()
			get_tree().set_input_as_handled()

func prev(): current_tab = wrapi(current_tab - 1, 0, get_child_count())
func next(): current_tab = wrapi(current_tab + 1, 0, get_child_count())
	
