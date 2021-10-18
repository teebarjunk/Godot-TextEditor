tool
extends Control
class_name TE_TextEditor

const FONT:DynamicFont = preload("res://addons/text_editor/fonts/font.tres")

const FONT_R:DynamicFont = preload("res://addons/text_editor/fonts/font_r.tres")
const FONT_B:DynamicFont = preload("res://addons/text_editor/fonts/font_b.tres")
const FONT_I:DynamicFont = preload("res://addons/text_editor/fonts/font_i.tres")
const FONT_BI:DynamicFont = preload("res://addons/text_editor/fonts/font_bi.tres")

const PATH_TRASH:String = "res://.trash"
const PATH_STATE:String = "res://.text_editor_state.json"

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
		hidden=false
	}
}

var color_text:Color = Color.white
var color_comment:Color = Color.white.darkened(.6)
var color_symbol:Color = Color.deepskyblue
var color_tag:Color = Color.yellow
var color_var:Color = Color.orange
var color_varname:Color = Color.white.darkened(.25)

onready var test_button:Node = $c/c/c/test
onready var tab_parent:TabContainer = $c/div1/div2/c/c/tab_container
onready var tab_prefab:Node = $file_editor
onready var popup:ConfirmationDialog = $popup
onready var popup_unsaved:ConfirmationDialog = $popup_unsaved
onready var file_dialog:FileDialog = $file_dialog
onready var line_edit:LineEdit = $c/div1/div2/c/line_edit
onready var menu_file:MenuButton = $c/c/c/file_button
onready var menu_view:MenuButton = $c/c/c/view_button
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
	popup_file.add_item("New Folder", 200)
	popup_file.add_separator()
	popup_file.add_item("Open last closed", 300)
	_e = popup_file.connect("id_pressed", self, "_menu_file")
	
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
	popup_view_file.add_check_item("Hidden", 0)
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
	
	load_state()
	update_checks()
	set_directory()

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

func save_state():
	var state:Dictionary = {
		"save_version": "1",
		"font_size": FONT.size,
		"tabs": {},
		"selected": get_selected_file(),
		"show": show,
		"tags": tags,
		"tag_counts": tag_counts,
		"tags_enabled": tags_enabled,
		"exts_enabled": exts_enabled,
		
		"file_list": file_list,
		
		"div1": $c/div1.split_offset,
		"div2": $c/div1/div2.split_offset
	}
	for tab in get_all_tabs():
		state.tabs[tab.file_path] = tab.get_state()
	
	TE_Util.save_json(PATH_STATE, state)
	emit_signal("state_saved")

func load_state():
	var state:Dictionary = TE_Util.load_json(PATH_STATE)
	if not state:
		return
	
	var selected
	for file_path in state.tabs:
		var tab = _open_file(file_path)
		tab.set_state(state.tabs[file_path])
		if file_path == state.selected:
			selected = tab
	
	_load_property(state, "show", true)
	
	update_checks()
	
	_load_property(state, "file_list")
	_load_property(state, "tag_counts")
	_load_property(state, "tags_enabled")
	_load_property(state, "exts_enabled")
	
	$c/div1.split_offset = state.get("div1", $c/div1.split_offset)
	$c/div1/div2.split_offset = state.get("div2", $c/div1/div2.split_offset)
	
	emit_signal("state_loaded")
	
	yield(get_tree(), "idle_frame")
	if selected:
		emit_signal("file_selected", selected.file_path)
	

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

func _input(e):
	if not is_plugin_active():
		return
	
	if e is InputEventMouseButton and e.control:
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

func _menu_file(id):
	match id:
		100: popup_create_file() # "New File"
		200: popup_create_dir() # "New Folder"
		300: open_last_file() # "Open last closed"

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
	# hidden files
	if index == 0:
		show.file.hidden = not show.file.hidden
		popup_view_file.set_item_checked(index, show.file.hidden)
	
	# main extensions
	else:
		var text = popup_view_file.get_item_text(index)
		var ext = text.substr(2)
		if ext in exts_enabled:
			exts_enabled[ext] = not exts_enabled[ext]
			popup_view_file.set_item_checked(index, exts_enabled[ext])
	
	refresh_files()
	save_state()

func _file_dialog_file(file_path:String):
	match file_dialog.get_meta("mode"):
		"create_file": create_file(file_path)
		"create_dir": create_dir(file_path)

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

func popup_create_file(dir:String=current_directory):
	file_dialog.mode = FileDialog.MODE_SAVE_FILE
	file_dialog.current_dir = dir
	file_dialog.window_title = "Create File"
	file_dialog.current_path = "new_file.txt"
	file_dialog.filters = FILE_FILTERS
	file_dialog.set_meta("mode", "create_file")
	file_dialog.show()

func popup_create_dir(dir:String=current_directory):
	file_dialog.mode = FileDialog.MODE_OPEN_DIR
	file_dialog.current_dir = dir
	file_dialog.window_title = "Create Folder"
	file_dialog.current_path = "New Folder"
	file_dialog.set_meta("mode", "create_dir")
	file_dialog.show()

func create_file(file_path:String):
	var f:File = File.new()
	if f.open(file_path, File.WRITE) == OK:
		f.store_string("")
		f.close()
		refresh_files()
		open_file(file_path)
		select_file(file_path)
	else:
		var err_msg = "couldnt create %s" % file_path
		console.err(err_msg)
		push_error(err_msg)

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
		if child.file_path == file_path:
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
	if remember:
		closed.append(file_path)
	
	var tab = get_tab(file_path)
	tab_parent.remove_child(tab)
	tab.queue_free()
	emit_signal("file_closed", file_path)

func _open_file(file_path:String):
	var tab = tab_prefab.duplicate()
	tab.visible = true
	tab.editor = self
	tab_parent.add_child(tab)
	tab.set_owner(self)
	tab.load_file(file_path)
	return tab

func is_allowed_extension(file_path:String) -> bool:
	var ext = get_extension(file_path)
	return ext in MAIN_EXTENSIONS

func open_file(file_path:String, temporary:bool=false):
	var tab = get_tab(file_path)
	if tab:
		return tab
	
	elif not File.new().file_exists(file_path):
		push_error("no file %s" % file_path)
		return null
	
	elif not is_allowed_extension(file_path):
		push_error("can't open %s" % file_path)
		return null
	
	else:
		tab = _open_file(file_path)
		if temporary:
			tab.temporary = true
		else:
			opened.append(file_path)
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
		print("can't unrecyle")
	
func recycle(file_path:String):
	if file_path.begins_with(PATH_TRASH):
		push_error("can't recycle recycled.")
		return
	
	var tab = get_tab(file_path)
	
	var time = str(OS.get_system_time_secs())
	var old_path:String = file_path
	var d:Directory = Directory.new()
	
	# is dir?
	var base_name = file_path.get_file()
	var new_dir = PATH_TRASH.plus_file(time)
	var new_path = new_dir.plus_file(base_name)
	
	if not d.dir_exists(PATH_TRASH):
		var _err = d.make_dir(PATH_TRASH)
	
	var _err = d.make_dir(new_dir)
	d.rename(file_path, new_path)
	save_file(new_dir.plus_file(".old_path"), old_path)
	save_file(new_dir.plus_file(".new_path"), new_path)
	
	refresh_files()
	
	if tab:
		tab_parent.remove_child(tab)
		tab.queue_free()
	
		if opened:
			select_file(opened[-1])

func rename_file(old_path:String, new_path:String):
	if old_path == new_path or not old_path or not new_path:
		return
	
	if File.new().file_exists(new_path):
		push_error("can't rename %s to %s. file already exists." % [old_path, new_path])
		return
	
	var selected = get_selected_file()
	if Directory.new().rename(old_path, new_path) == OK:
		refresh_files()
		if selected == old_path:
			_selected_file_changed(new_path)
		emit_signal("file_renamed", old_path, new_path)
	
	else:
		push_error("couldn't rename %s to %s." % [old_path, new_path])

func select_file(file_path:String):
	if not File.new().file_exists(file_path):
		push_error("no file %s" % file_path)
		return
	
	if not is_allowed_extension(file_path):
		return
	
	var temp = get_temporary_tab()
	if temp:
		if temp.file_path == file_path:
			temp.temporary = false
		else:
			temp.close()
	
	if not is_opened(file_path):
		open_file(file_path, true)
	
	# select current tab
	tab_parent.current_tab = get_tab(file_path).get_index()
	_selected_file_changed(file_path)

func set_directory(path:String=current_directory):
#	var gpath = ProjectSettings.globalize_path(path)
#	var dname = gpath.get_file()
	console.msg("Set " + path)
	
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
	if fname.begins_with("."):
		if not show.file.hidden: return false
	
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
		open=old_last_dir.get("open", true) }
	last_dir[id] = info
	
	var fname = dir.get_next()
	
	while fname:
		var file_path = dir.get_current_dir().plus_file(fname)
		console.msg(file_path)
		
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

func get_extension_helper(file_path:String) -> TE_ExtensionHelper:
	var ext:String = get_extension(file_path).replace(".", "_")
	var ext_path:String = "res://addons/text_editor/ext/ext_%s.gd" % ext
	var script = load(ext_path)
	if script:
		return script.new()
	
	console.err("no helper %s" % ext_path)
	return load("res://addons/text_editor/ext/TE_ExtensionHelper.gd").new()
