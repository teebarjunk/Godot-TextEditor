extends TabContainer

onready var editor:TE_Editor = owner
var mouse:bool = false
var last_tab_index:int = -1

func _ready():
	if not editor.is_plugin_active():
		return
	
	var _e
	_e = connect("mouse_entered", self, "set", ["mouse", true])
	_e = connect("mouse_exited", self, "set", ["mouse", false])
	_e = connect("tab_changed", self, "_tab_changed")
	
	add_font_override("font", editor.FONT_R)

func _tab_changed(index):
	var tab
	var data
	
#	if last_tab_index >= 0 and last_tab_index < get_child_count():
#		tab = get_child(last_tab_index)
#		data = editor.get_file_data(tab.file_path)
#		data.hscroll = tab.hscroll
#		data.vscroll = tab.vscroll
#		data.cursor = tab.get_cursor_state()
#		prints("SAVED", tab.file_path, tab.cursor_state)
#
#	yield(get_tree(), "idle_frame")
#
#	tab = get_child(index)
#	data = editor.get_file_data(tab.file_path)
#	if "cursor" in data:
#		print("LOADED", data.cursor)
#		tab.set_cursor_state(data.cursor)
#		tab.set_h_scroll(data.hscroll)
#		tab.set_v_scroll(data.vscroll)

	tab = get_child(index)
#	var s = tab.get_cursor_state()
	tab.grab_focus()
#	tab.grab_click_focus()
#	yield(get_tree(), "idle_frame")
#	tab.set_cursor_state(s)
	
	last_tab_index = index
#	prints(tab, tab.file_path)

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
	
