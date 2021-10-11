extends Node
class_name TextEditor

const FONT:DynamicFont = preload("res://addons/text_editor/fonts/font.tres")

const FONT_R:DynamicFont = preload("res://addons/text_editor/fonts/font_r.tres")
const FONT_B:DynamicFont = preload("res://addons/text_editor/fonts/font_b.tres")
const FONT_I:DynamicFont = preload("res://addons/text_editor/fonts/font_i.tres")
const FONT_BI:DynamicFont = preload("res://addons/text_editor/fonts/font_bi.tres")

const EXTENSIONS:PoolStringArray = PoolStringArray([
	"txt", "md", "json", "csv", "cfg", "ini", "yaml"
])
const FILE_FILTERS:PoolStringArray = PoolStringArray([
	"*.txt ; Text",
	"*.md ; Markdown",
	"*.json ; JSON",
	"*.csv ; Comma Seperated Values",
	"*.cfg ; Config",
	"*.ini ; Config",
	"*.yaml ; YAML"
])

var color_text:Color = Color.white
var color_comment:Color = Color.darkolivegreen
var color_symbol:Color = Color.white.darkened(.5)
var color_var:Color = Color.orange
var color_varname:Color = Color.white.darkened(.25)


onready var test_button:Node = $c/c/c/test
onready var tab_parent:TabContainer = $c/c3/c/c/tab_container
onready var tab_prefab:Node = $c/c3/c/c/tab_container/tab_prefab
onready var popup:ConfirmationDialog = $popup
onready var popup_unsaved:ConfirmationDialog = $popup_unsaved
onready var file_dialog:FileDialog = $file_dialog
onready var line_edit:LineEdit = $c/c3/c/c/line_edit
onready var menu_file:MenuButton = $c/c/c/file_button
var ext_menu:PopupMenu = PopupMenu.new()

signal updated_file_list()
signal file_opened(file_path)
signal file_closed(file_path)
signal file_selected(file_path)
signal file_saved(file_path)
signal file_renamed(old_path, new_path)
#signal file_symbols_updated(file_path)
signal symbols_updated()
signal tags_updated()
signal save_files()

var current_directory:String = ""
var dirs:Array = []
var file_list:Dictionary = {}
var ext_counts:Dictionary = {}
var symbols:Dictionary = {}
var tags:Array = []
var tags_enabled:Dictionary = {}
var tag_counts:Dictionary = {}
var exts_enabled:Array = []

var opened:Array = []
var closed:Array = []

func _ready():
	# not needed when editor plugin
#	get_tree().set_auto_accept_quit(false)
	
	var _e
	_e = test_button.connect("pressed", self, "_debug_pressed")
	
	# popup unsaved
	popup_unsaved.get_ok().text = "Ok"
	popup_unsaved.get_cancel().text = "Cancel"
	var btn = popup_unsaved.add_button("Save and Close", false, "save_and_close")
	btn.modulate = Color.yellowgreen
	btn.connect("pressed", popup_unsaved, "hide")
	TE_Util.dig(popup_unsaved, self, "_apply_fonts")
	
	# menu
	var p = menu_file.get_popup()
	p.add_font_override("font", FONT_R)
	p.add_item("New File")
	_e = p.connect("index_pressed", self, "_menu_file")
	
	# extensions
	ext_menu.set_name("Extensions")
	ext_menu.add_font_override("font", FONT_R)
	for i in len(EXTENSIONS):
		var ext = EXTENSIONS[i]
		ext_menu.add_check_item(ext, i)
		ext_menu.set_item_checked(i, true)
		exts_enabled.append(ext)
	p.add_child(ext_menu)
	p.add_submenu_item("Extensions", "Extensions")
	_e = ext_menu.connect("index_pressed", self, "_menu_extension")
	
	# file dialog
	_e = file_dialog.connect("file_selected", self, "_file_dialog_file")
	file_dialog.add_font_override("title_font", FONT_R)
	TE_Util.dig(file_dialog, self, "_apply_fonts")
	
	# tab control
	_e = tab_parent.connect("tab_changed", self, "_tab_changed")
	tab_parent.remove_child(tab_prefab)
	
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

func _input(e):
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

func _menu_extension(index:int):
	var ext = EXTENSIONS[index]
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
				print("open last tab")
				open_last_file()
			else:
				print("close tab ")
				close_selected()
		
		elif e.scancode == KEY_R:
			sort_files()
		
		else:
			return
	
	get_tree().set_input_as_handled()

func sort_files():
	TE_Util.dig(file_list, self, "_sort_files")
	emit_signal("updated_file_list")

func _sort_files(d:Dictionary):
	return TE_Util.sort_on_ext(d)

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
		closed.pop_back()

func close_selected():
	var file = get_selected_file()
	if file:
		close_file(file)

func close_file(file_path:String):
	var tab = get_tab(file_path)
	if tab:
		tab.close()

func _close_file(file_path, remember:bool=true):
	if remember:
		closed.append(opened.pop_back())
	
	var tab = get_tab(file_path)
	tab_parent.remove_child(tab)
	tab.queue_free()
	emit_signal("file_closed", file_path)
	
	if opened:
		select_file(opened[-1])

func open_file(file_path:String, temporary:bool=false):
	var tab = get_tab(file_path)
	if tab:
		return tab
	
	else:
		tab = tab_prefab.duplicate()
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

func set_directory(path:String="res://test_files"):
	var gpath = ProjectSettings.globalize_path(path)
	var dname = gpath.get_file()
	OS.set_window_title("%s (%s)" % [dname, gpath])
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
	ext_counts.clear()
	dirs.clear()
	file_list.clear()
	var dir = Directory.new()
	if dir.open(current_directory) == OK:
		_scan_dir("", current_directory, dir, file_list)
	else:
		push_error("error trying to load %s." % current_directory)
	
	sort_files()

func _scan_dir(id:String, path:String, dir:Directory, list:Dictionary):
	var _e = dir.list_dir_begin(true, false)
	dirs.append(path)
	var files = {}
	list[id] = { file_path=path, files=files, open=true }
	
	var fname = dir.get_next()
	
	while fname:
		if not fname.begins_with("."):
			var file_path = dir.get_current_dir().plus_file(fname)
			
			if dir.current_is_dir():
				# ignore folders with a .gdignore file.
				if not fname == ".import" and not File.new().file_exists(file_path.plus_file(".gdignore")):
					var sub_dir = Directory.new()
					sub_dir.open(file_path)
					_scan_dir(fname, file_path, sub_dir, files)
			
			else:
				# ignore .import files
				if not file_path.ends_with(".import"):
					var ext = get_extension(file_path)
					if ext in exts_enabled:
						files[fname] = file_path
						
						if not ext in ext_counts:
							ext_counts[ext] = 1
						else:
							ext_counts[ext] += 1
			
		fname = dir.get_next()
	dir.list_dir_end()

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
