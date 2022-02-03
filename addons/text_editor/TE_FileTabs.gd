extends TabContainer

onready var editor:TE_Editor = owner
var mouse:bool = false
var last_tab_index:int = -1
var tab_menu:PopupMenu

func _ready():
	if not editor.is_plugin_active():
		return
	
	var _e
	_e = connect("mouse_entered", self, "set", ["mouse", true])
	_e = connect("mouse_exited", self, "set", ["mouse", false])
	_e = connect("tab_changed", self, "_tab_changed")
	_e = connect("pre_popup_pressed", self, "update_popup")
	
	add_font_override("font", editor.FONT_R)
	
	tab_menu = owner.get_node("popup_tab_menu")
	tab_menu.connect("index_pressed", self, "_popup_selected")

func _tab_changed(index):
	var tab = get_child(index)
	tab.grab_focus()
	
	last_tab_index = index

func _popup_selected(index:int):
	var tindex := tab_menu.get_item_id(index)
	if tindex >= 100:
		current_tab = tindex - 100
		return
	
	match tindex:
		0:	# close
			get_child(hovered_tab_index).close()
		
		1:	# close others
			var all_tabs = owner.get_tabs()
			var hovered = get_child(hovered_tab_index)
			for tab in all_tabs:
				if tab != hovered:
					tab.close()
		
		2:	# close left
			var all_tabs = owner.get_tabs()
			for i in range(0, hovered_tab_index):
				all_tabs[i].close()
			current_tab = 0
		
		3:	# close right
			var all_tabs = owner.get_tabs()
			for i in range(hovered_tab_index+1, len(all_tabs)):
				all_tabs[i].close()
		
var hovered_tab_index:int
func update_popup(index:int=current_tab):
	var all_tabs = owner.get_tabs()
	
	hovered_tab_index = index
	
	tab_menu.clear()
	tab_menu.rect_size = Vector2.ZERO
	tab_menu.add_item("Close", 0)
	tab_menu.add_item("Close others", 1)
	
	if index > 0:
		tab_menu.add_item("Close all to left", 2)
	
	if index < len(all_tabs)-1:
		tab_menu.add_item("Close all to right", 3)
	
	tab_menu.add_separator()
	
	var i = 0
	for tab in owner.get_tabs():
		tab_menu.add_item(tab.name, 100+i)
		i += 1

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
		
		elif e.button_index == BUTTON_RIGHT:
			var index := get_tab_idx_at_point(get_local_mouse_position())
			if index != -1:
				update_popup(index)
				tab_menu.rect_global_position = get_global_mouse_position()
				tab_menu.popup()
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
	
