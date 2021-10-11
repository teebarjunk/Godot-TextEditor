tool
extends Control
class_name TextEditor

const FONT:DynamicFont = preload("res://addons/text_editor/fonts/font.tres")

const FONT_R:DynamicFont = preload("res://addons/text_editor/fonts/font_r.tres")
const FONT_B:DynamicFont = preload("res://addons/text_editor/fonts/font_b.tres")
const FONT_I:DynamicFont = preload("res://addons/text_editor/fonts/font_i.tres")
const FONT_BI:DynamicFont = preload("res://addons/text_editor/fonts/font_bi.tres")

const MAIN_EXTENSIONS:PoolStringArray = PoolStringArray([
	"txt", "md", "json", "csv", "cfg", "ini", "yaml"
])
const INTERNAL_EXTENSIONS:PoolStringArray = PoolStringArray([
	"gd", "import", "gdignore", "gitignore"
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

var plugin = null
var plugin_hint:bool = false

# hide dirs
var show_dir_empty:bool = true
var show_dir_hidden:bool = true
var show_dir_gdignore:bool = true
#
var show_dir_git:bool = false
var show_dir_import:bool = false
var show_dir_trash:bool = false
# hide files
var show_file_hidden:bool = true

var color_text:Color = Color.white
var color_comment:Color = Color.white.darkened(.6)
var color_symbol:Color = Color.deepskyblue
var color_var:Color = Color.orange
var color_varname:Color = Color.white.darkened(.25)

onready var test_button:Node = $c/c/c/test
onready var tab_parent:TabContainer = $c/c3/c/c/tab_container
onready var tab_prefab:Node = $file_editor
onready var popup:ConfirmationDialog = $popup
onready var popup_unsaved:ConfirmationDialog = $popup_unsaved
onready var file_dialog:FileDialog = $file_dialog
onready var line_edit:LineEdit = $c/c3/c/c/line_edit
onready var menu_file:MenuButton = $c/c/c/file_button
var ext_menu:PopupMenu = PopupMenu.new()
var hide_menu:PopupMenu = PopupMenu.new()

signal updated_file_list()
signal file_opened(file_path)
signal file_closed(file_path)
signal file_selected(file_path)
signal file_saved(file_path)
signal file_renamed(old_path, new_path)
signal symbols_updated()
signal tags_updated()
signal save_files()

var current_directory:String = "res://"
var dirs:Array = []
var file_list:Dictionary = {}
#var ext_counts:Dictionary = {}
var symbols:Dictionary = {}
var tags:Array = []
var tags_enabled:Dictionary = {}
var tag_counts:Dictionary = {}
var exts_enabled:Array = []

var opened:Array = []
var closed:Array = []

func _ready():
	if not is_plugin_active():
		return
	
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
	var p:PopupMenu = menu_file.get_popup()
	p.clear()
	p.add_font_override("font", FONT_R)
	p.add_item("New File")
	_e = p.connect("index_pressed", self, "_menu_file")
	
	# hide
	hide_menu.clear()
	hide_menu.set_name("Directories")
	hide_menu.add_font_override("font", FONT_R)
	hide_menu.add_check_item("Hidden", 0)
	hide_menu.add_check_item("Empty", 1)
	hide_menu.add_check_item(".gdignore", 2)
	hide_menu.set_item_checked(0, show_dir_hidden)
	hide_menu.set_item_checked(1, show_dir_gdignore)
	hide_menu.set_item_checked(2, show_dir_empty)
	hide_menu.add_separator()
	hide_menu.add_check_item(".ignore/", 4)
	hide_menu.add_check_item(".git/", 5)
	hide_menu.add_check_item(".trash/", 6)
	
	p.add_child(hide_menu)
	p.add_submenu_item("Directories", "Directories")
	_e = hide_menu.connect("index_pressed", self, "_menu_hide")
	
	# hide extensions
	ext_menu.clear()
	ext_menu.set_name("Files")
	ext_menu.add_font_override("font", FONT_R)
	ext_menu.add_check_item("Hidden", 0)
	ext_menu.set_item_checked(0, show_file_hidden)
	
	ext_menu.add_separator()
	for i in len(MAIN_EXTENSIONS):
		var ext = MAIN_EXTENSIONS[i]
		ext_menu.add_check_item("*." + ext, i+2)
		ext_menu.set_item_checked(i+2, true)
		exts_enabled.append(ext)
	
	ext_menu.add_separator()
	for i in len(INTERNAL_EXTENSIONS):
		var ext = INTERNAL_EXTENSIONS[i]
		var id = i+len(MAIN_EXTENSIONS)+3
		ext_menu.add_check_item("*." + ext, id)
		ext_menu.set_item_checked(id, false)
	
	p.add_child(ext_menu)
	p.add_submenu_item("Files", "Files")
	_e = ext_menu.connect("index_pressed", self, "_menu_extension")
	
	# file dialog
	_e = file_dialog.connect("file_selected", self, "_file_dialog_file")
	file_dialog.add_font_override("title_font", FONT_R)
	TE_Util.dig(file_dialog, self, "_apply_fonts")
	
	# tab control
	_e = tab_parent.connect("tab_changed", self, "_tab_changed")
	
	#
	tab_parent.add_font_override("font", FONT_R)
	
	set_directory()

# not needed when an editor plugin
#func _notification(what):
#	match what:
#		MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
#			for tab in get_all_tabs():
#				if tab.modified:
#					popup.show()
#					return
#			get_tree().quit()

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

func _menu_file(a):
	match menu_file.get_popup().items[a]:
		"New File": popup_create_file()

func _menu_hide(index:int):
	match index:
		0:
			show_dir_hidden = not show_dir_hidden
			hide_menu.set_item_checked(index, show_dir_hidden)
		1:
			show_dir_empty = not show_dir_empty
			hide_menu.set_item_checked(index, show_dir_empty)
		2:
			show_dir_gdignore = not show_dir_gdignore
			hide_menu.set_item_checked(index, show_dir_gdignore)
		
		4:
			show_dir_import = not show_dir_import
			hide_menu.set_item_checked(index, show_dir_import)
		4:
			show_dir_git = not show_dir_git
			hide_menu.set_item_checked(index, show_dir_git)
		5:
			show_dir_trash = not show_dir_trash
			hide_menu.set_item_checked(index, show_dir_trash)
	
	refresh_files()

func _menu_extension(index:int):
	# hidden files
	if index == 0:
		show_file_hidden = not show_file_hidden
		ext_menu.set_item_checked(index, show_file_hidden)
	
	# main extensions
	elif index-2 < len(MAIN_EXTENSIONS):
		var ext = MAIN_EXTENSIONS[index-2]
		var toggled = ext in exts_enabled
		if toggled:
			exts_enabled.erase(ext)
		elif not ext in exts_enabled:
			exts_enabled.append(ext)
		ext_menu.set_item_checked(index, not toggled)
		refresh_files()
	
	# internal extensions
	elif index-3-len(MAIN_EXTENSIONS) < len(INTERNAL_EXTENSIONS):
		var ext = INTERNAL_EXTENSIONS[index-3-len(MAIN_EXTENSIONS)]
		var toggled = ext in exts_enabled
		if toggled:
			exts_enabled.erase(ext)
		elif not ext in exts_enabled:
			exts_enabled.append(ext)
		ext_menu.set_item_checked(index, not toggled)
		refresh_files()

func _file_dialog_file(file_path:String):
	match file_dialog.get_meta("mode"):
		"create": create_file(file_path)

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
	return tags_enabled[tag]

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
	if not len(tags):
		return true
	var tab = get_tab(file_path)
	if tab:
		return is_tagged_or_visible(tab.tags.keys())
	return false

func popup_create_file(dir:String="res://"):
	file_dialog.set_meta("mode", "create")
	file_dialog.current_dir = dir
	file_dialog.current_path = "new_file.txt"
	file_dialog.window_title = "Create File"
	file_dialog.mode = FileDialog.MODE_SAVE_FILE
	file_dialog.filters = FILE_FILTERS
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
		push_error("couldnt create %s" % file_path)

func _debug_pressed():
	set_directory()

func _unhandled_key_input(e:InputEventKey):
	if not e.pressed:
		return
	
	if e.control:
		# save
		if e.scancode == KEY_S:
			emit_signal("save_files")
		
		# close/unclose tab
		elif e.scancode == KEY_W:
			if e.shift:
				open_last_file()
			else:
				close_selected()
		
		elif e.scancode == KEY_R:
			sort_files()
		
		else:
			return
	
	get_tree().set_input_as_handled()

func sort_files():
	TE_Util.dig(file_list, self, "_sort")
	emit_signal("updated_file_list")

func _sort(dir:Dictionary):
	return TE_Util.sort_on_ext(dir)

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
	print("open last closed")
	print(closed)
	print(opened)
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

func open_file(file_path:String, temporary:bool=false):
	var tab = get_tab(file_path)
	if tab:
		return tab
	
	else:
		tab = tab_prefab.duplicate()
		tab.visible = true
		tab.editor = self
		tab_parent.add_child(tab)
		tab.set_owner(self)
		tab.load_file(file_path)
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

func recycle_file(file_path:String):
	var old_base:String = file_path.substr(len("res://")).get_base_dir()
	var p = file_path.get_file().split(".", true, 1)
	var old_name:String = p[0]
	var old_ext:String = p[1]
	var tab = get_tab(file_path)
	
	var new_file = "%s_%s.%s" % [old_name, OS.get_system_time_secs(), old_ext]
	var new_path:String = "res://.trash".plus_file(old_base).plus_file(new_file)
	
	# create directory
	var new_dir = new_path.get_base_dir()
	if Directory.new().make_dir_recursive(new_dir) != OK:
		print("couldn't remove %s" % file_path)
		return
	
	# save recovery information
	var trash_info = TE_Util.load_json("res://.trash_info.json")
	trash_info[new_path] = file_path
	TE_Util.save_json("res://.trash_info.json", trash_info)
	
	# remove by renaming
	rename_file(file_path, new_path)
	print("Send to " + new_path)
	
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
	var gpath = ProjectSettings.globalize_path(path)
	var dname = gpath.get_file()
	current_directory = path
	file_dialog.current_dir = path
	refresh_files()

func _file_symbols_updated(file_path:String):
	var tg = get_tab(file_path).tags
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
#	ext_counts.clear()
	dirs.clear()
	file_list.clear()
	var dir = Directory.new()
	if dir.open(current_directory) == OK:
		_scan_dir("", current_directory, dir, file_list)
	else:
		push_error("error trying to load %s." % current_directory)
	
	sort_files()

func show_dir(fname:String) -> bool:
	if not show_dir_gdignore and File.new().file_exists(fname.plus_file(".gdignore")):
		return false
	
	if fname.begins_with("."):
		if not show_dir_hidden: return false
		if not show_dir_import and fname == ".import": return false
		if not show_dir_git and fname == ".git": return false
		if not show_dir_trash and fname == ".trash": return false
	
	return true

func show_file(fname:String) -> bool:
	if fname.begins_with("."):
		if not show_file_hidden: return false
	
	var ext = get_extension(fname)
	return ext in exts_enabled

func _scan_dir(id:String, path:String, dir:Directory, last_dir:Dictionary):
	var _e = dir.list_dir_begin(true, false)
	dirs.append(path)
	var a_dirs_and_files = {}
	var a_files = []
	var a_dirs = []
	var info = { file_path=path, all=a_dirs_and_files, files=a_files, dirs=a_dirs, open=true }
	
	var fname = dir.get_next()
	
	while fname:
		var file_path = dir.get_current_dir().plus_file(fname)
		
		if dir.current_is_dir():
			if show_dir(fname):
				var sub_dir = Directory.new()
				sub_dir.open(file_path)
				_scan_dir(fname, file_path, sub_dir, a_dirs_and_files)
		
		else:
			if show_file(fname):
				a_dirs_and_files[fname] = file_path
		
		fname = dir.get_next()
	
	dir.list_dir_end()
	
	# is empty? ignore
	if id and not (show_dir_empty or a_dirs_and_files):
		return
	
	# add to last
	last_dir[id] = info
	
	if path == current_directory:
		print(JSON.print(info, "\t"))
	
	for p in a_dirs_and_files:
		if a_dirs_and_files[p] is Dictionary:
			a_dirs.append(p)
		else:
			a_files.append(p)

static func get_extension(file_path:String) -> String:
	var file = file_path.get_file()
	if "." in file:
		return file.split(".", true, 1)[1]
	return ""

static func get_extension_helper(file_path:String) -> TE_ExtensionHelper:
	var ext:String = get_extension(file_path).replace(".", "_")
	var ext_path:String = "res://addons/text_editor/ext/ext_%s.gd" % ext
	if File.new().file_exists(ext_path):
		return load(ext_path).new()
	return load("res://addons/text_editor/ext/TE_ExtensionHelper.gd").new()