tool
extends TextEdit

var editor:TextEditor
var _hscroll:HScrollBar
var _vscroll:VScrollBar

var helper:TE_ExtensionHelper
var temporary:bool = false setget set_temporary
var modified:bool = false
var file_path:String = ""

var symbols:Dictionary = {}
var tags:Dictionary = {}
var last_key:int
var last_shift:bool
var last_selected:bool
var last_selection:Array = [0, 0, 0, 0]

var hscroll:int = 0
var vscroll:int = 0
var in_focus:bool = false

func _ready():
	var _e
	if not editor:
		editor = owner
	_e = editor.connect("save_files", self, "save_file")
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = editor.connect("file_renamed", self, "_file_renamed")
	_e = connect("text_changed", self, "text_changed")
	_e = connect("focus_entered", self, "set", ["in_focus", true])
	_e = connect("focus_exited", self, "set", ["in_focus", false])
	
	if get_parent() is TabContainer:
		get_parent().connect("tab_changed", self, "_tab_changed")
		get_parent().connect("tab_selected", self, "_tab_changed")
	
	add_font_override("font", editor.FONT)
	get_menu().add_font_override("font", editor.FONT)
	
	TE_Util.dig(self, self, "_node")

func _node(n):
	var _e
	if n is HScrollBar:
		_e = n.connect("changed", self, "_scroll_h", [n])
	
	elif n is VScrollBar:
		_e = n.connect("changed", self, "_scroll_v", [n])
		n.allow_greater = true

func _scroll_h(h:HScrollBar):
	hscroll = h.value

func _scroll_v(v:VScrollBar):
	vscroll = v.value

func _tab_changed(index:int):
	var myindex = get_index()
	if index == myindex and visible:
		grab_focus()
		grab_click_focus()
		yield(get_tree(), "idle_frame")
		set_h_scroll(hscroll)
		set_v_scroll(vscroll)

func get_state() -> Dictionary:
	return {
		hscroll=scroll_horizontal,
		vscroll=scroll_vertical
	}

func set_state(state:Dictionary):
	yield(get_tree(), "idle_frame")
	hscroll = state.hscroll
	vscroll = state.vscroll
	set_h_scroll(state.hscroll)
	set_v_scroll(state.vscroll)

func _file_renamed(old_path:String, new_path:String):
	if old_path == file_path:
		file_path = new_path
		update_name()

func _input(e):
	if not editor.is_plugin_active():
		return
	
	if not visible or not in_focus:
		return
	
	if e is InputEventKey and e.pressed and e.control:
		# tab to next
		if e.scancode == KEY_TAB:
			get_tree().set_input_as_handled()
			if e.shift:
				get_parent().prev()
			else:
				get_parent().next()
		
		# save files
		elif e.scancode == KEY_S:
			get_tree().set_input_as_handled()
			editor.save_files()
		
		# close file
		elif e.scancode == KEY_W:
			get_tree().set_input_as_handled()
			if e.shift:
				editor.open_last_file()
			else:
				close()
	
	# remember last selection
	if e is InputEventKey and e.pressed:
		last_key = e.scancode
		last_shift = e.shift
		if is_selection_active():
			last_selected = true
			last_selection[0] = get_selection_from_line()
			last_selection[1] = get_selection_from_column()
			last_selection[2] = get_selection_to_line()
			last_selection[3] = get_selection_to_column()
		else:
			last_selected = false
	
	# move lines up/down
	if e is InputEventKey and e.control and e.shift and e.pressed:
		var f
		var t
		if is_selection_active():
			f = get_selection_from_line()
			t = get_selection_to_line()
		else:
			f = cursor_get_line()
			t = cursor_get_line()
		
		# move selected text up or down
		if e.scancode == KEY_UP and f > 0:
			var lines = []
			for i in range(f-1, t+1): lines.append(get_line(i))
			lines.push_back(lines.pop_front())
			for i in len(lines): set_line(f-1+i, lines[i])
			select(f-1, 0, t-1, len(get_line(t-1)))
			cursor_set_line(cursor_get_line()-1, false)
			
		if e.scancode == KEY_DOWN and t < get_line_count()-1:
			var lines = []
			for i in range(f, t+2): lines.append(get_line(i))
			lines.push_front(lines.pop_back())
			for i in len(lines): set_line(f+i, lines[i])
			select(f+1, 0, t+1, len(get_line(t+1)))
			cursor_set_line(cursor_get_line()+1, false)

func _unhandled_key_input(e):
	if not visible:
		return
	
	# comment code
	if e.scancode == KEY_SLASH and e.control and e.pressed:
		helper.toggle_comment(self)
		get_tree().set_input_as_handled()

func _file_selected(p:String):
	if not p:
		return
	
	if p == file_path:
		grab_focus()
		grab_click_focus()
		update_symbols()
		update_heading()

func text_changed():
	if last_selected:
		match last_key:
			KEY_APOSTROPHE:
				undo()
				select(last_selection[0], last_selection[1], last_selection[2], last_selection[3])
				if last_shift:
					insert_text_at_cursor("\"%s\"" % get_selection_text())
				else:
					insert_text_at_cursor("'%s'" % get_selection_text())
			
			KEY_QUOTELEFT:
				undo()
				select(last_selection[0], last_selection[1], last_selection[2], last_selection[3])
				insert_text_at_cursor("`%s`" % get_selection_text())
				
			_:
				print(last_key)
			
	if not modified:
		if temporary:
			temporary = false
		modified = true
		update_name()

func set_temporary(t):
	temporary = t
	update_name()

func update_symbols():
	symbols.clear()
	tags.clear()
	
	# symbol getter
	symbols = helper.get_symbols(text)
	
	# collect tags
	for line_index in symbols:
		var line_info = symbols[line_index]
		for tag in line_info.tags:
			if not tag in tags:
				tags[tag] = 1
			else:
				tags[tag] += 1
	
#	var _e = TE_Util.sort(tags, true)
	editor._file_symbols_updated(file_path)

func close():
	if modified:
		var _e
		_e = editor.popup_unsaved.connect("confirmed", self, "_popup", ["close"], CONNECT_ONESHOT)
		_e = editor.popup_unsaved.connect("custom_action", self, "_popup", [], CONNECT_ONESHOT)
		editor.popup_unsaved.show()
	else:
		editor._close_file(file_path)

func _popup(msg):
	match msg:
		"close":
			editor._close_file(file_path)
		"save_and_close":
			save_file()
			editor._close_file(file_path)

func load_file(path:String):
	file_path = path
	text = TE_Util.load_text(path)
	update_name()
	
	# update colors
	clear_colors()
	
	helper = TextEditor.get_extension_helper(file_path)
	helper.apply_colors(editor, self)

func save_file():
	if modified:
		if not file_path.begins_with("res://"):
			push_error("can't save to %s" % file_path)
			return
		
		modified = false
		editor.save_file(file_path, text)
		update_name()
		update_symbols()

func update_name():
	var n = file_path.get_file().split(".", true, 1)[0]
	if temporary: n = "?" + n
	if modified: n = "*" + n
	
	editor.tab_parent.set_tab_title(get_index(), n)
	update_heading()

func update_heading():
	if Engine.editor_hint:
		return
	
	# set window "file (directory)"
	var f = file_path.get_file()
	if modified:
		f = "*" + f
	var d = file_path.get_base_dir().get_file()
	if d:
		OS.set_window_title("%s (%s) - Text Editor" % [f, d])
	else:
		OS.set_window_title("%s - Text Editor" % f)

func needs_save() -> bool:
	return modified or not File.new().file_exists(file_path)

