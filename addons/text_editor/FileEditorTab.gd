extends TextEdit

onready var tabs:TabContainer = get_parent()
onready var editor:TextEditor = get_parent().owner

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

func _ready():
	var _e
	_e = editor.connect("save_files", self, "save_file")
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = editor.connect("file_renamed", self, "_file_renamed")
	_e = connect("text_changed", self, "text_changed")
	add_font_override("font", editor.FONT)
	get_menu().add_font_override("font", editor.FONT)

func _file_renamed(old_path:String, new_path:String):
	if old_path == file_path:
		file_path = new_path
		update_name()

func _input(e):
	if not visible:
		return
	
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
	if p and p == file_path:
		grab_focus()
		update_symbols()

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
	
	var _e = TE_Util.sort(tags, true)
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
	var f:File = File.new()
	var _err = f.open(path, File.READ)
	text = f.get_as_text()
	f.close()
	update_name()
	
	# update colors
	clear_colors()
	
	helper = TextEditor.get_extension_helper(file_path)
	helper.apply_colors(editor, self)
	print("helper ", helper)

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
	
	tabs.set_tab_title(get_index(), n)

func needs_save() -> bool:
	return modified or not File.new().file_exists(file_path)

