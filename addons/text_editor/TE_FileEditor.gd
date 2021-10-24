tool
extends TextEdit

var editor:TE_Editor
var _hscroll:HScrollBar
var _vscroll:VScrollBar

var helper:TE_ExtensionHelper
var temporary:bool = false setget set_temporary
var modified:bool = false
var file_path:String = ""
var mouse_inside:bool = false

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
	# prefab?
	if name == "file_editor":
		set_process(false)
		set_process_input(false)
		return
		
	var _e
	if not editor:
		editor = owner
	_e = editor.connect("save_files", self, "save_file")
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = editor.connect("file_renamed", self, "_file_renamed")
	_e = connect("text_changed", self, "text_changed")
	_e = connect("focus_entered", self, "set", ["in_focus", true])
	_e = connect("focus_exited", self, "set", ["in_focus", false])
	_e = connect("mouse_entered", self, "set", ["mouse_inside", true])
	_e = connect("mouse_exited", self, "set", ["mouse_inside", false])
	
	if get_parent() is TabContainer:
		get_parent().connect("tab_changed", self, "_tab_changed")
		get_parent().connect("tab_selected", self, "_tab_changed")
	
	add_font_override("font", editor.FONT)
	var popup = get_menu()
	popup.add_font_override("font", editor.FONT)
	
	popup.add_separator()
	popup.add_item("Uppercase", 1000)
#	var sc = ShortCut.new()
#	sc.shortcut = InputEventKey.new()
#	sc.shortcut.shift = true
#	sc.shortcut.control = true
#	sc.shortcut.scancode = KEY_U
#	popup.add_item_shortcut(sc, 1000)
	popup.add_item("Lowercase")
	popup.add_item("Capitalize")
	popup.add_item("Variable")
	
#	popup.add_shortcut()
	_e = popup.connect("index_pressed", self, "_popup_menu")
	
	# hint
	theme = Theme.new()
	theme.set_font("font", "TooltipLabel", editor.FONT_R)
	
	TE_Util.dig(self, self, "_node")

func _popup_menu(index:int):
	match get_menu().get_item_text(index):
		"Uppercase": selection_uppercase()
		"Lowercase": selection_lowercase()
		"Capitalize": selection_capitalize()
		"Variable": selection_variable()

var cl
var cc
var isa
var sl1
var sc1
var sl2
var sc2

func _remember_selection():
	cl = cursor_get_line()
	cc = cursor_get_column()
	isa = is_selection_active()
	if isa:
		sl1 = get_selection_from_line()
		sc1 = get_selection_from_column()
		sl2 = get_selection_to_line()
		sc2 = get_selection_to_column()

func _remake_selection():
	cursor_set_line(cl)
	cursor_set_column(cc)
	if isa:
		select(sl1, sc1, sl2, sc2)

func selection_uppercase():
	_remember_selection()
	insert_text_at_cursor(get_selection_text().to_upper())
	_remake_selection()

func selection_lowercase():
	_remember_selection()
	insert_text_at_cursor(get_selection_text().to_lower())
	_remake_selection()

func selection_variable():
	_remember_selection()
	insert_text_at_cursor(get_selection_text().to_lower().replace(" ", "_"))
	_remake_selection()

func selection_capitalize():
	_remember_selection()
	insert_text_at_cursor(get_selection_text().capitalize())
	_remake_selection()

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
#		grab_focus()
#		grab_click_focus()
		yield(get_tree(), "idle_frame")
		set_h_scroll(hscroll)
		set_v_scroll(vscroll)

func get_state() -> Dictionary:
	var state = { hscroll=scroll_horizontal, vscroll=scroll_vertical }
	# unsaved
	if file_path == "":
		state.text = text
	return state
	
func set_state(state:Dictionary):
	yield(get_tree(), "idle_frame")
	hscroll = state.hscroll
	vscroll = state.vscroll
	set_h_scroll(state.hscroll)
	set_v_scroll(state.vscroll)
	
	if "text" in state:
		if state.text.strip_edges():
			text = state.text
		else:
			editor._close_file(file_path)

func _file_renamed(old_path:String, new_path:String):
	if old_path == file_path:
		file_path = new_path
		update_name()
		update_colors()

func _update_selected_line():
	var l = cursor_get_line()
	editor.select_symbol_line(0)
	
	var depth = PoolStringArray()
	for i in len(symbols):
		var sindex = clamp(i, 0, len(symbols))
		var symbol = symbols.values()[sindex]
		while len(depth) <= symbol.deep:
			depth.append("")
		
		depth[symbol.deep] = "  ".repeat(symbol.deep) + symbol.name
		
		if i == len(symbols)-1 or symbols.keys()[i+1] > l:
			editor.select_symbol_line(sindex)
			depth.resize(symbol.deep+1)
			hint_tooltip = "[%s]\n%s" % [editor.get_localized_path(file_path), depth.join("\n")]
			break

func _input(e):
	if not editor.is_plugin_active():
		return
	
	if not visible or not in_focus or not mouse_inside:
		return
	
	# show current position in heirarchy as editor hint
	if e is InputEventMouseButton and not e.pressed:
		_update_selected_line()
	
	if e is InputEventMouseButton and not e.pressed and e.control:
		var line:String = get_line(cursor_get_line())
		
		# click link
		var ca = line.find("(")
		var cb = line.find_last(")")
		if ca != -1 and cb != -1:
			var a:int = cursor_get_column()
			var b:int = cursor_get_column()
			if ca < a and cb >= b:
				while a > 0 and not line[a] in "(": a -= 1
				while b <= len(line) and not line[b] in ")": b += 1
				var file = line.substr(a+1, b-a-1)
				var link = file_path.get_base_dir().plus_file(file)
				editor.open_file(link)
				editor.select_file(link)
	
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
		
		if e.scancode == KEY_U: selection_uppercase()
		if e.scancode == KEY_L: selection_lowercase()
		if e.scancode == KEY_O: selection_capitalize()
		if e.scancode == KEY_P: selection_variable()

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
		update_symbols()
		update_heading()
		
		var cl = cursor_get_line()
		var cc = cursor_get_column()
		var fl
		var fc
		var tl
		var tc
		var had_selection = false
		
		if is_selection_active():
			had_selection = true
			fl = get_selection_from_line()
			fc = get_selection_from_column()
			tl = get_selection_to_line()
			tc = get_selection_to_column()
			
			grab_focus()
			grab_click_focus()
		
		yield(get_tree(), "idle_frame")
		
		cursor_set_line(cl)
		cursor_set_column(cc)
		
		if had_selection:
			select(fl, fc, tl, tc)
		
		grab_focus()
		grab_click_focus()
		

func goto_line(line:int):
	# force scroll to bottom so selected line will be at top
	cursor_set_line(get_line_count())
	cursor_set_line(line)
	_update_selected_line()

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
				pass
			
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
	
	editor._file_symbols_updated(file_path)

func close():
	if modified:
		if not editor.popup_unsaved.visible:
			var _e
			_e = editor.popup_unsaved.connect("confirmed", self, "_popup", ["confirm_close"], CONNECT_ONESHOT)
			_e = editor.popup_unsaved.connect("custom_action", self, "_popup", [], CONNECT_ONESHOT)
#			_e = editor.popup_unsaved.connect("hide", self, "_popup", ["cancel"], CONNECT_ONESHOT)
			editor.popup_unsaved.show()
	else:
		editor._close_file(file_path)

func _popup(msg):
	match msg:
		"confirm_close":
			editor._close_file(file_path)
		"save_and_close":
			save_file()
			editor._close_file(file_path)
	editor.popup_unsaved.disconnect("confirmed", self, "_popup")
	editor.popup_unsaved.disconnect("custom_action", self, "_popup")

func load_file(path:String):
	file_path = path
	if path != "":
		text = editor.load_file(path)
	update_colors()
	update_name()
	
func update_colors():
	clear_colors()
	helper = editor.get_extension_helper(file_path)
	helper.apply_colors(editor, self)

func _created_nonexisting(fp:String):
	file_path = fp
	modified = false
	update_name()
	update_symbols()

func save_file():
	if file_path == "":
		editor.popup_create_file(editor.current_directory, text, funcref(self, "_created_nonexisting"))
	
	else:
		if modified:
			if not file_path.begins_with(editor.current_directory):
				var err_msg = "can't save to %s" % file_path
				push_error(err_msg)
				editor.console.err(err_msg)
				return
			
			modified = false
			editor.save_file(file_path, text)
			update_name()
			update_symbols()

func update_name():
	var n:String
	
	if file_path == "":
		n = "*UNSAVED"
	
	else:
		n = file_path.get_file().split(".", true, 1)[0]
		if temporary: n = "?" + n
		if modified: n = "*" + n
	
	if len(n) > 12:
		n = n.substr(0, 9) + "..."
	
	editor.tab_parent.set_tab_title(get_index(), n)
	editor.tab_parent.get_tab_control(get_index()).hint_tooltip = file_path
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

