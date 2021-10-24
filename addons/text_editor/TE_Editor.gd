tool
extends Control
class_name TE_Editor

const FONT:DynamicFont = preload("res://addons/text_editor/fonts/font.tres")

const FONT_R:DynamicFont = preload("res://addons/text_editor/fonts/font_r.tres")
const FONT_B:DynamicFont = preload("res://addons/text_editor/fonts/font_b.tres")
const FONT_I:DynamicFont = preload("res://addons/text_editor/fonts/font_i.tres")
const FONT_BI:DynamicFont = preload("res://addons/text_editor/fonts/font_bi.tres")

const DNAME_TRASH:String = ".trash"
const FNAME_STATE:String = ".text_editor_state.json"

const MAIN_EXTENSIONS:PoolStringArray = PoolStringArray([
	"txt", "md", "json", "csv", "cfg", "ini", "yaml"
])
const INTERNAL_EXTENSIONS:PoolStringArray = PoolStringArray([
	"gd", "tres", "tscn", "import", "gdignore", "gitignore"
])
const FILE_FILTERS:PoolStringArray = PoolStringArray([
	"*.txt ; Text",
	"*.md ; Markdown",
	"*.json ; JSON",
	"*.csv ; Comma Seperated Values",
	"*.cfg ; Config",
	"*.ini ; Config",
	"*.yaml ; YAML",
])

signal updated_file_list()
signal file_opened(file_path)
signal file_closed(file_path)
signal file_selected(file_path)
signal file_saved(file_path)
signal file_renamed(old_path, new_path)
signal symbols_updated()
signal tags_updated()
signal save_files()
signal state_saved()
signal state_loaded()

signal selected_symbol_line(symbol_index)

var plugin = null
var plugin_hint:bool = false

var show:Dictionary = {
	dir={
		empty=true,
		hidden=true,
		gdignore=true,
		
		addons=false,
		git=false,
		import=false,
		trash=false
	},
	file={
		hidden=false,
		extensionless=false
	}
}

var color_text:Color = Color.white
var color_background:Color = Color.transparent#Color.white.darkened(.85)
var color_comment:Color = Color.white.darkened(.6)
var color_symbol:Color = Color.deepskyblue
var color_tag:Color = Color.yellow
var color_var:Color = Color.orange
var color_varname:Color = color_text.darkened(.25)

onready var test_button:Node = $c/c/c/test
onready var tab_parent:TabContainer = $c/div1/div2/c/c/tab_container
onready var tab_prefab:Node = $file_editor
onready var popup:ConfirmationDialog = $popup
onready var popup_unsaved:ConfirmationDialog = $popup_unsaved
onready var file_dialog:FileDialog = $file_dialog
onready var line_edit:LineEdit = $c/div1/div2/c/line_edit
onready var menu_file:MenuButton = $c/c/c/file_button
onready var menu_view:MenuButton = $c/c/c/view_button
onready var word_wrap:CheckBox = $c/c/c/word_wrap
onready var console:RichTextLabel = $c/div1/div2/c/c/meta_tabs/console
var popup_file:PopupMenu
var popup_view:PopupMenu
var popup_view_dir:PopupMenu = PopupMenu.new()
var popup_view_file:PopupMenu = PopupMenu.new()

var current_directory:String = "res://"
var file_list:Dictionary = {}
var dir_paths:Array = []
var file_paths:Array = []

var symbols:Dictionary = {}
var tags:Array = []
var tags_enabled:Dictionary = {}
var tag_counts:Dictionary = {}
var exts_enabled:Dictionary = {}

var opened:Array = []
var closed:Array = []

func _ready():
	console.info("active: %s" % is_plugin_active())
	
	if not is_plugin_active():
		return
	
	if OS.has_feature("standalone"):
		current_directory = OS.get_executable_path().get_base_dir()
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	console.info("current dir: %s" % current_directory)
	# not needed when editor plugin
#	get_tree().set_auto_accept_quit(false)
	
	var _e
	_e = test_button.connect("pressed", self, "_debug_pressed")
	test_button.add_font_override("font", FONT_R)
	
	# popup unsaved
	popup_unsaved.get_ok().text = "Ok"
	popup_unsaved.get_cancel().text = "Cancel"
	var btn = popup_unsaved.add_button("Save and Close", false, "save_and_close")
	btn.modulate = Color.yellowgreen
	btn.connect("pressed", popup_unsaved, "hide")
	TE_Util.dig(popup_unsaved, self, "_apply_fonts")
	
	# menu
	menu_file.add_font_override("font", FONT_R)
	popup_file = menu_file.get_popup()
	popup_file.clear()
	popup_file.add_font_override("font", FONT_R)
	popup_file.add_item("New File", 100)
	popup_file.add_separator()
	popup_file.add_item("Open last closed", 300)
	_e = popup_file.connect("index_pressed", self, "_menu_file")
	
	# view
	menu_view.add_font_override("font", FONT_R)
	popup_view = menu_view.get_popup()
	popup_view.clear()
	popup_view.add_font_override("font", FONT_R)
	
	# view/dir
	popup_view_dir.clear()
	popup_view_dir.set_name("Directories")
	popup_view_dir.add_font_override("font", FONT_R)
	popup_view_dir.add_check_item("Hidden", hash("Hidden"))
	popup_view_dir.add_check_item("Empty", hash("Empty"))
	popup_view_dir.add_check_item(".gdignore", hash(".gdignore"))
	popup_view_dir.add_separator()
	popup_view_dir.add_check_item("addons/", hash("addons/"))
	popup_view_dir.add_check_item(".import/", hash(".import/"))
	popup_view_dir.add_check_item(".git/", hash(".git/"))
	popup_view_dir.add_check_item(".trash/", hash(".trash/"))
	
	popup_view.add_child(popup_view_dir)
	popup_view.add_submenu_item("Directories", "Directories")
	_e = popup_view_dir.connect("index_pressed", self, "_menu_view_dir")
	
	# view/file
	popup_view_file.clear()
	popup_view_file.set_name("Files")
	popup_view_file.add_font_override("font", FONT_R)
	popup_view_file.add_check_item("Hidden")
	popup_view_file.add_check_item("Extensionless")
	popup_view_file.set_item_checked(0, show.file.hidden)
	
	popup_view_file.add_separator()
	for i in len(MAIN_EXTENSIONS):
		var ext = MAIN_EXTENSIONS[i]
		exts_enabled[ext] = true
		popup_view_file.add_check_item("*." + ext, i+2)
		popup_view_file.set_item_checked(i+2, true)
	
	popup_view_file.add_separator()
	for i in len(INTERNAL_EXTENSIONS):
		var ext = INTERNAL_EXTENSIONS[i]
		var id = i+len(MAIN_EXTENSIONS)+3
		exts_enabled[ext] = false
		popup_view_file.add_check_item("*." + ext, id)
		popup_view_file.set_item_checked(id, false)
	
	popup_view.add_child(popup_view_file)
	popup_view.add_submenu_item("Files", "Files")
	_e = popup_view_file.connect("index_pressed", self, "_menu_view_file")
	
	# file dialog
	_e = file_dialog.connect("file_selected", self, "_file_dialog_file")
	file_dialog.add_font_override("title_font", FONT_R)
	TE_Util.dig(file_dialog, self, "_apply_fonts")
	
	# tab control
	_e = tab_parent.connect("tab_changed", self, "_tab_changed")
	
	# word wrap
	_e = word_wrap.connect("pressed", self, "_toggle_word_wrap")
	word_wrap.add_font_override("font", FONT_R)
	
	load_state()
	update_checks()
	set_directory()

func _toggle_word_wrap():
	set_word_wrap(word_wrap.pressed)

func set_word_wrap(ww:bool):
	tab_prefab.set_wrap_enabled(ww)
	for tab in get_all_tabs():
		tab.set_wrap_enabled(ww)

func select_symbol_line(line:int):
	emit_signal("selected_symbol_line", line)

func update_checks():
	# Directories
	popup_view_dir.set_item_checked(0, show.dir.hidden)
	popup_view_dir.set_item_checked(1, show.dir.empty)
	popup_view_dir.set_item_checked(2, show.dir.gdignore)
	#
	popup_view_dir.set_item_checked(4, show.dir.addons)
	popup_view_dir.set_item_checked(5, show.dir.import)
	popup_view_dir.set_item_checked(6, show.dir.git)
	popup_view_dir.set_item_checked(7, show.dir.trash)

	# Files
	popup_view_file.set_item_checked(0, show.file.hidden)
	#
	for i in len(MAIN_EXTENSIONS):
		var ext = MAIN_EXTENSIONS[i]
	#
	for i in len(INTERNAL_EXTENSIONS):
		var ext = INTERNAL_EXTENSIONS[i]
		var id = i+len(MAIN_EXTENSIONS)+3

func get_localized_path(file_path:String):
	assert(file_path.begins_with(current_directory))
	var out:String = file_path.substr(len(current_directory))
	if out.begins_with("/"):
		return out.substr(1)
	return out

func get_globalized_path(file_path:String):
	return current_directory.plus_file(file_path)

func save_state():
	var state:Dictionary = {
		"save_version": "1",
		"font_size": FONT.size,
		"font_size_ui": FONT_R.size,
		"tabs": {},
		"selected": get_selected_file(),
		"word_wrap": word_wrap.pressed,
		"show": show,
		"tags": tags,
		"tag_counts": tag_counts,
		"tags_enabled": tags_enabled,
		"exts_enabled": exts_enabled,
		"shortcuts": shortcuts,
		
		"file_list": file_list,
		
		"div1": $c/div1.split_offset,
		"div2": $c/div1/div2.split_offset,
		"div3": $c/div1/div2/c/c.split_offset,
		"div4": $c/div1/div2/c2/c.split_offset
	}
	var ws = OS.get_window_size()
	state["window_size"] = [ws.x, ws.y]
	
	for tab in get_all_tabs():
		state.tabs[get_localized_path(tab.file_path)] = tab.get_state()
	
	TE_Util.save_json(current_directory.plus_file(FNAME_STATE), state)
	emit_signal("state_saved")

func _fix_tint(d:Dictionary):
	if "tint" in d:
		var c = d.tint.split_floats(",")
		d.tint = Color(c[0], c[1], c[2], c[3])

func load_state():
	var state:Dictionary = TE_Util.load_json(current_directory.plus_file(FNAME_STATE))
	if not state:
		return
	
	# word wrap
	var ww = state.get("word_wrap", word_wrap)
	word_wrap.pressed = ww
	set_word_wrap(ww)
	
	var selected_file:String
	for file_path in state.tabs:
		var st = state.tabs[file_path]
		file_path = get_globalized_path(file_path)
		var tab = _open_file(file_path)
		tab.set_state(st)
		if file_path == state.selected:
			selected_file = file_path
	
	_load_property(state, "show", true)
	
	update_checks()
	
	FONT.size = state.get("font_size", FONT.size)
	
	var font_size_ui = state.get("font_size_ui", FONT_R.size)
	for f in [FONT_R, FONT_B, FONT_I, FONT_BI]:
		f.size = font_size_ui
	
	TE_Util.dig(state.file_list, self, "_fix_tint")
	
	_load_property(state, "file_list")
	_load_property(state, "tag_counts")
	_load_property(state, "tags_enabled")
	_load_property(state, "exts_enabled")
	_load_property(state, "shortcuts")
	
	# dividers
	$c/div1.split_offset = state.get("div1", $c/div1.split_offset)
	$c/div1/div2.split_offset = state.get("div2", $c/div1/div2.split_offset)
	$c/div1/div2/c/c.split_offset = state.get("div3", $c/div1/div2/c/c.split_offset)
	$c/div1/div2/c2/c.split_offset = state.get("div4", $c/div1/div2/c2/c.split_offset)
	
	# window size
	if "window_size" in state:
		var ws = state.window_size
		OS.set_window_size(Vector2(ws[0], ws[1]))
	
	emit_signal("state_loaded")
	
	yield(get_tree(), "idle_frame")
	if selected_file:
		select_file(selected_file)
#	if selected_tab:
#		emit_signal("file_selected", selected_tab.file_path)

func _load_property(state:Dictionary, property:String, merge:bool=false):
	if property in state and typeof(state[property]) == typeof(self[property]):
		if merge:
			_merge(self[property], state[property])
		else:
			self[property] = state[property]

func _merge(target:Dictionary, patch:Dictionary):
	for k in patch:
		if patch[k] is Dictionary:
			if not k in target:
				target[k] = {}
			_merge(target[k], patch[k])
		else:
			target[k] = patch[k]

func _exit_tree():
	save_state()

func is_plugin_active():
	if not Engine.editor_hint:
		return true
	
	return plugin_hint and visible

var shortcuts:Dictionary = {}
func _input(e):
	if not is_plugin_active():
		return
	
	if e is InputEventKey and e.pressed and e.control:
		# tab to next
		if e.scancode == KEY_TAB:
			if e.shift:
				tab_parent.prev()
			else:
				tab_parent.next()
			get_tree().set_input_as_handled()
		
		# save files
		elif e.scancode == KEY_S:
			save_files()
			get_tree().set_input_as_handled()
		
		# close file
		elif e.scancode == KEY_W:
			if e.shift:
				open_last_file()
			else:
				var sel_tab = get_selected_tab()
				if sel_tab != null:
					sel_tab.close()
			
			get_tree().set_input_as_handled()
		
		# create new file
		elif e.scancode == KEY_N:
			open_file("", true)
			get_tree().set_input_as_handled()
	
		# shortcuts
		elif e.scancode >= KEY_0 and e.scancode <= KEY_9:
			if e.shift:
				var sf = get_selected_file()
				if sf:
					shortcuts[str(e.scancode)] = sf
					console.msg("shortcut %s: %s" % [e.scancode, sf])
			
			else:
				if str(e.scancode) in shortcuts:
					var sf = shortcuts[str(e.scancode)]
					open_file(sf)
					select_file(sf)
			
			get_tree().set_input_as_handled()
	
	if e is InputEventMouseButton and e.control:
		# ui font
		if e.shift:
			if e.button_index == BUTTON_WHEEL_DOWN:
				for f in [FONT_B, FONT_BI, FONT_R, FONT_I]:
					f.size = int(max(8, f.size - 1))
				get_tree().set_input_as_handled()
			
			elif e.button_index == BUTTON_WHEEL_UP:
				for f in [FONT_B, FONT_BI, FONT_R, FONT_I]:
					f.size = int(min(64, f.size + 1))
				get_tree().set_input_as_handled()
		
		# text font
		else:
			if e.button_index == BUTTON_WHEEL_DOWN:
				FONT.size = int(max(8, FONT.size - 1))
				get_tree().set_input_as_handled()
			
			elif e.button_index == BUTTON_WHEEL_UP:
				FONT.size = int(min(64, FONT.size + 1))
				get_tree().set_input_as_handled()

func _apply_fonts(n:Node):
	if n is Control:
		if n.has_font("font"):
			n.add_font_override("font", FONT_R)

func _menu_file(index:int):
	var text = popup_file.get_item_text(index)
	match text:
		"New File": popup_create_file() # "New File"
		"Open last closed": open_last_file() # "Open last closed"

func _menu_view_dir(index:int):
	var text = popup_view_dir.get_item_text(index)
	match text:
		"Hidden":
			show.dir.hidden = not show.dir.hidden
			popup_view_dir.set_item_checked(index, show.dir.hidden)
		"Empty":
			show.dir.empty = not show.dir.empty
			popup_view_dir.set_item_checked(index, show.dir.empty)
		".gdignore":
			show.dir.gdignore = not show.dir.gdignore
			popup_view_dir.set_item_checked(index, show.dir.gdignore)
		
		"addons/":
			show.dir.addons = not show.dir.addons
			popup_view_dir.set_item_checked(index, show.dir.addons)
		".import/":
			show.dir.import = not show.dir.import
			popup_view_dir.set_item_checked(index, show.dir.import)
		".git/":
			show.dir.git = not show.dir.git
			popup_view_dir.set_item_checked(index, show.dir.git)
		".trash/":
			show.dir.trash = not show.dir.trash
			popup_view_dir.set_item_checked(index, show.dir.trash)
	
	refresh_files()
	save_state()

func _menu_view_file(index:int):
	var text = popup_view_file.get_item_text(index)
	match text:
		"Hidden":
			show.file.hidden = not show.file.hidden
			popup_view_file.set_item_checked(index, show.file.hidden)
		
		"Extensionless":
			show.file.extensionless = not show.file.extensionless
			popup_view_file.set_item_checked(index, show.file.extensionless)
		
		# file extensions
		_:
			var ext = text.substr(2)
			if ext in exts_enabled:
				exts_enabled[ext] = not exts_enabled[ext]
				popup_view_file.set_item_checked(index, exts_enabled[ext])
			else:
				print("no %s in %s" % [ext, exts_enabled])
	
	refresh_files()
	save_state()

func _file_dialog_file(file_path:String):
	match file_dialog.get_meta("mode"):
		"create_file":
			var text = file_dialog.get_meta("text")
			create_file(file_path, text)
		
		"create_dir":
			create_dir(file_path)

var tab_index:int = -1
func _tab_changed(index:int):
	tab_index = index
	var node = tab_parent.get_child(index)
	if node:
		_selected_file_changed(get_selected_file())
	else:
		_selected_file_changed("")

var last_selected_file:String = ""
func _selected_file_changed(file_path:String):
	if file_path != last_selected_file:
		last_selected_file = file_path
		emit_signal("file_selected", last_selected_file)

func is_tag_enabled(tag:String) -> bool:
	return tags_enabled.get(tag, false)

func enable_tag(tag:String, enabled:bool=true):
	tags_enabled[tag] = enabled
	tags.clear()
	for t in tags_enabled:
		if tags_enabled[t]:
			tags.append(t)
	emit_signal("tags_updated")

func is_tagged_or_visible(file_tags:Array) -> bool:
	if not len(tags):
		return true
	for t in tags:
		if not t in file_tags:
			return false
	return true

func is_tagged(file_path:String) -> bool:
	var tab = get_tab(file_path)
	if tab:
		return is_tagged_or_visible(tab.tags.keys())
	return false

func is_tagging() -> bool:
	return len(tags) > 0

func popup_create_file(dir:String=current_directory, text:String="", callback:FuncRef=null):
	file_dialog.mode = FileDialog.MODE_SAVE_FILE
	file_dialog.current_dir = dir
	file_dialog.window_title = "Create File"
	file_dialog.current_path = "new_file.md"
	file_dialog.filters = FILE_FILTERS
	file_dialog.set_meta("mode", "create_file")
	file_dialog.set_meta("text", text)
	file_dialog.set_meta("callback", callback)
	file_dialog.show()
	yield(get_tree(), "idle_frame")
	file_dialog.get_line_edit().grab_click_focus()
	file_dialog.get_line_edit().grab_focus()

func create_file(file_path:String, text:String=""):
	var f:File = File.new()
	if f.open(file_path, File.WRITE) == OK:
		f.store_string(text)
		f.close()
		refresh_files()
		
		if file_dialog.has_meta("callback"):
			var fr:FuncRef = file_dialog.get_meta("callback")
			fr.call_func(file_path)
			file_dialog.set_meta("callback", null)
		
		open_file(file_path)
		
		return true
	else:
		var err_msg = "couldnt create %s" % file_path
		console.err(err_msg)
		push_error(err_msg)
		return false

func create_dir(file_path:String):
	var d:Directory = Directory.new()
	if file_path and file_path.begins_with(current_directory) and not d.file_exists(file_path):
		print("creating folder \"%s\"" % file_path)
		d.make_dir(file_path)
		refresh_files()
		
func _debug_pressed():
	set_directory()

func save_files():
	emit_signal("save_files")

func get_selected_file() -> String:
	var node = get_selected_tab()
	return node.file_path if node else ""

func get_tab(file_path:String) -> TextEdit:
	for child in tab_parent.get_children():
		if child is TextEdit and child.file_path == file_path:
			return child
	return null

func get_selected_tab() -> TextEdit:
	var i = tab_parent.current_tab
	if i >= 0 and i < tab_parent.get_child_count():
		return tab_parent.get_child(i) as TextEdit
	return null

func get_temporary_tab() -> TextEdit:
	for child in tab_parent.get_children():
		if child.temporary:
			return child
	return null

func load_file(file_path:String) -> String:
	return TE_Util.load_text(file_path)

func save_file(file_path:String, text:String):
	var f:File = File.new()
	var _err = f.open(file_path, File.WRITE)
	f.store_string(text)
	f.close()
	emit_signal("file_saved", file_path)

func open_last_file():
	if closed:
		var file_path = closed.pop_back()
		open_file(file_path)
		select_file(file_path)

func close_selected():
	var tab = get_selected_tab()
	if tab:
		tab.close()
	else:
		print("cant close")

func close_file(file_path:String):
	var tab = get_tab(file_path)
	if tab:
		tab.close()

func _close_file(file_path, remember:bool=true):
	if remember and file_path:
		closed.append(file_path)
	
	var tab:Node = get_tab(file_path)
	tab_parent.remove_child(tab)
	tab.queue_free()
	
	if file_path:
		emit_signal("file_closed", file_path)
	
	# force select a file
	yield(get_tree(), "idle_frame")
	var fp = get_selected_file()
	if fp:
		select_file(fp)

func _open_file(file_path:String):
	var tab = tab_prefab.duplicate()
	tab.name = "tab"
	tab.visible = true
	tab.editor = self
	tab_parent.add_child(tab)
	tab.set_owner(self)
	tab.load_file(file_path)
	return tab

func is_allowed_extension(file_path:String) -> bool:
	var file = file_path.get_file()
	if not "." in file and show.file.extensionless:
		return true
	
	var ext = get_extension(file)
	return ext in MAIN_EXTENSIONS

func open_file(file_path:String, temporary:bool=false):
	var tab = get_tab(file_path)
	if tab:
		return tab
	
	elif not File.new().file_exists(file_path) and not file_path == "":
		push_error("no file %s" % file_path)
		return null
	
	elif not is_allowed_extension(file_path) and not file_path == "":
		push_error("can't open %s" % file_path)
		return null
	
	else:
		tab = _open_file(file_path)
		if temporary:
			tab.temporary = true
		else:
			opened.append(file_path)
		
		# select it
		tab_parent.current_tab = tab.get_index()
		
		emit_signal("file_opened", file_path)
		return tab

func is_opened(file_path:String) -> bool:
	return get_tab(file_path) != null

func is_selected(file_path:String) -> bool:
	return get_selected_file() == file_path

func unrecycle(file_path:String):
	var op = file_path.plus_file(".old_path")
	var np = file_path.plus_file(".new_path")
	var d:Directory = Directory.new()
	if d.file_exists(op) and d.file_exists(np):
		var old_path:String = TE_Util.load_text(np)
		var new_path:String = TE_Util.load_text(op)
		d.rename(old_path, new_path)
		d.remove(op)
		d.remove(np)
		d.remove(file_path)
		refresh_files()
	else:
		var err_msg = "can't unrecyle %s" % file_path
		push_error(err_msg)
		console.err(err_msg)

func is_trash_path(file_path:String) -> bool:
	var path_trash:String = current_directory.plus_file(DNAME_TRASH)
	return file_path.begins_with(path_trash) and file_path != path_trash

func recycle(file_path:String, is_file:bool):
	
	if not is_file:
		print("TODO: close all open windows")
	
	var path_trash:String = current_directory.plus_file(DNAME_TRASH)
	
	if file_path.begins_with(path_trash):
		var err_msg = "can't recycle recycled %s" % file_path
		push_error(err_msg)
		console.err(err_msg)
		return
	
	var tab = get_tab(file_path)
	
	var time = str(OS.get_system_time_secs())
	var old_path:String = file_path
	var d:Directory = Directory.new()
	
	# is dir?
	var base_name = file_path.get_file()
	var new_dir = path_trash.plus_file(time)
	var new_path = new_dir.plus_file(base_name)
	
	if not d.dir_exists(path_trash):
		var err = d.make_dir(path_trash)
		if err != OK:
			err("can't make dir %s" % path_trash)
			return
	
	var err = d.make_dir(new_dir)
	if err != OK:
		err("can't make dir %s" % new_dir)
		return
	
	err = d.rename(file_path, new_path)
	if err != OK:
		err("can't rename %s to %s" % [file_path, new_path])
		return
	
	save_file(new_dir.plus_file(".old_path"), old_path)
	save_file(new_dir.plus_file(".new_path"), new_path)
	
	refresh_files()
	
	if tab:
		tab_parent.remove_child(tab)
		tab.queue_free()
	
		if opened:
			select_file(opened[-1])

func err(err_msg:String):
	push_error(err_msg)
	console.err(err_msg)

func rename_file(old_path:String, new_path:String):
	if old_path == new_path or not old_path or not new_path:
		return
	
	if File.new().file_exists(new_path):
		var err_msg = "can't rename %s to %s. file already exists." % [old_path, new_path]
		push_error(err_msg)
		console.err(err_msg)
		return
	
	var was_selected = old_path == get_selected_file()
	if Directory.new().rename(old_path, new_path) == OK:
		refresh_files()
		emit_signal("file_renamed", old_path, new_path)
		if was_selected:
			_selected_file_changed(new_path)
	
	else:
		var err_msg = "couldn't rename %s to %s." % [old_path, new_path]
		push_error(err_msg)
		console.err(err_msg)

func select_file(file_path:String):
	if not File.new().file_exists(file_path):
		push_error("no file %s" % file_path)
		return
	
	if not is_allowed_extension(file_path):
		return
	
	if is_opened(file_path):
		var tab = get_tab(file_path)
		if tab.temporary:
			tab.temporary = false
	
	else:
		var temp = get_temporary_tab()
		if temp != null:
			tab_parent.remove_child(temp)
			temp.queue_free()
		
		open_file(file_path, true)
	
	# select current tab
	tab_parent.current_tab = get_tab(file_path).get_index()
	_selected_file_changed(file_path)

func set_directory(path:String=current_directory):
	current_directory = path
	file_dialog.current_dir = path
	refresh_files()

func _file_symbols_updated(file_path:String):
	var tg = get_tab(file_path).tags
	tags_enabled.clear()
	for tag in tg:
		if not tag in tags_enabled:
			tags_enabled[tag] = false
	
	tag_counts.clear()
	for child in get_all_tabs():
		for t in child.tags:
			if not t in tag_counts:
				tag_counts[t] = child.tags[t]
			else:
				tag_counts[t] += child.tags[t]
	
	emit_signal("symbols_updated")

func get_all_tabs() -> Array:
	return tab_parent.get_children()

func refresh_files():
	var old_file_list = file_list.duplicate(true)
	file_list.clear()
	dir_paths.clear()
	file_paths.clear()
	var dir = Directory.new()
	var err = dir.open(current_directory)
	if err == OK:
		_scan_dir("", current_directory, dir, file_list, old_file_list.get("", {}))
		emit_signal("updated_file_list")
	else:
		var err_msg = "error trying to load %s: %s" % [current_directory, err]
		push_error(err_msg)
		console.err(err_msg)
		
func show_dir(fname:String, base_dir:String) -> bool:
	if not show.dir.gdignore and File.new().file_exists(base_dir.plus_file(".gdignore")):
		return false
	
	if fname.begins_with("."):
		if not show.dir.hidden: return false
		if not show.dir.import and fname == ".import": return false
		if not show.dir.git and fname == ".git": return false
		if not show.dir.trash and fname == ".trash": return false
	else:
		if not show.dir.addons and fname == "addons": return false
	
	return true

func show_file(fname:String) -> bool:
	# hidden
	if fname.begins_with("."):
		if not show.file.hidden: return false
	# extensionless
	if not "." in fname:
		return show.file.extensionless
	
	var ext = get_extension(fname)
	return exts_enabled.get(ext, false)

func _scan_dir(id:String, path:String, dir:Directory, last_dir:Dictionary, old_last_dir:Dictionary):
	var _e = dir.list_dir_begin(true, false)
	var a_dirs_and_files = {}
	var a_files = []
	var a_dirs = []
	var info = {
		file_path=path,
		all=a_dirs_and_files,
		files=a_files,
		dirs=a_dirs,
		show=true,
		open=old_last_dir.get("open", true),
		tint=old_last_dir.get("tint", Color.white)
	}
	last_dir[id] = info
	
	var fname = dir.get_next()
	
	while fname:
		var file_path = dir.get_current_dir().plus_file(fname)
		
		if dir.current_is_dir():
			if show_dir(fname, file_path):
				var sub_dir = Directory.new()
				sub_dir.open(file_path)
				_scan_dir(fname, file_path, sub_dir, a_dirs_and_files, old_last_dir.get("all", {}).get(fname, {}))
		
		else:
			if show_file(fname):
				a_dirs_and_files[fname] = file_path
		
		fname = dir.get_next()
	
	dir.list_dir_end()
	
	for p in a_dirs_and_files:
		if a_dirs_and_files[p] is Dictionary:
			a_dirs.append(p)
			dir_paths.append(a_dirs_and_files[p].file_path)
		else:
			a_files.append(a_dirs_and_files[p])
			file_paths.append(a_dirs_and_files[p])
	
	sort_on_ext(a_dirs)
	sort_on_ext(a_files)
	
	if id and not (show.dir.empty or a_files):
		info.show = false
	
	return info

func sort_on_ext(items:Array):
	var sorted = []
	for a in items:
		var k = a.get_file()
		if "." in k:
			k = k.split(".", true, 1)
			k = k[1] + k[0]
		sorted.append([k, a])
	sorted.sort_custom(self, "_sort_on_ext")
	for i in len(items):
		items[i] = sorted[i][1]
	return items

func _sort_on_ext(a, b):
	return a[0] < b[0]

static func get_extension(file_path:String) -> String:
	var file = file_path.get_file()
	if "." in file:
		return file.split(".", true, 1)[1]
	return ""

var complained_ext:Array = []

func get_extension_helper(file_path:String) -> TE_ExtensionHelper:
	var ext:String = get_extension(file_path).replace(".", "_")
	var ext_path:String = "res://addons/text_editor/ext/ext_%s.gd" % ext
	if ext in ["cfg", "csv", "ini", "json", "md", "yaml"]:
		return load(ext_path).new()
	
	# only complain once
	if not ext in complained_ext:
		complained_ext.append(ext)
		console.err("no format helper for '%s' files" % ext)
	
	return load("res://addons/text_editor/ext/TE_ExtensionHelper.gd").new()
