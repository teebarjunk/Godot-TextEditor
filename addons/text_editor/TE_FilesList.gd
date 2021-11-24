tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

onready var file_popup:PopupMenu = $file_popup
onready var dir_popup:PopupMenu = $dir_popup

const DragLabel = preload("res://addons/text_editor/TE_DragLabel.gd")
var drag_label:RichTextLabel

export var p_filter:NodePath
var filter:String = ""
var selected:Array = []
var dragging:Array = []
var drag_start:Vector2

func _ready():
	var _e
	_e = editor.connect("updated_file_list", self, "_redraw")
	_e = editor.connect("tags_updated", self, "_redraw")
	_e = editor.connect("file_opened", self, "_file_opened")
	_e = editor.connect("file_closed", self, "_file_closed")
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = editor.connect("file_renamed", self, "_file_renamed")
	
	var le:LineEdit = get_node(p_filter)
	_e = le.connect("text_changed", self, "_filter_changed")
	le.add_font_override("font", editor.FONT_R)
	
	# file popup
	file_popup.clear()
	file_popup.rect_size = Vector2.ZERO
	file_popup.add_item("Rename")
	file_popup.add_separator()
	file_popup.add_item("Remove")
	_e = file_popup.connect("index_pressed", self, "_file_popup")
	file_popup.add_font_override("font", editor.FONT)
	
	# dir popup
	dir_popup.clear()
	dir_popup.rect_size = Vector2.ZERO
	dir_popup.add_item("New File")
	dir_popup.add_separator()
	dir_popup.add_item("Remove")
	dir_popup.add_separator()
	dir_popup.add_item("Tint Yellow")
	dir_popup.add_item("Tint Red")
	dir_popup.add_item("Tint Blue")
	dir_popup.add_item("Tint Green")
	dir_popup.add_item("Reset Tint")
	_e = dir_popup.connect("index_pressed", self, "_dir_popup")
	dir_popup.add_font_override("font", editor.FONT)
	
	add_font_override("normal_font", editor.FONT_R)
	add_font_override("bold_font", editor.FONT_B)
	add_font_override("italics_font", editor.FONT_I)
	add_font_override("bold_italics_font", editor.FONT_BI)

func _filter_changed(t:String):
	filter = t
	_redraw()

func _dir_popup(index:int):
	var type = selected[0]
	var file = selected[1]
	if type == "d":
		file = file.file_path
	
	match dir_popup.get_item_text(index):
		"New File":
			editor.popup_create_file(file)
		
		"Remove":
			editor.recycle(file, type == "f")
		
		"Tint Yellow":
			selected[1].tint = "yellow"#Color.gold
			editor.emit_signal("dir_tint_changed", selected[1].file_path)
			_redraw()
		"Tint Red":
			selected[1].tint = "red"#Color.tomato
			editor.emit_signal("dir_tint_changed", selected[1].file_path)
			_redraw()
		"Tint Blue":
			selected[1].tint = "blue"#Color.deepskyblue
			editor.emit_signal("dir_tint_changed", selected[1].file_path)
			_redraw()
		"Tint Green":
			selected[1].tint = "green"#Color.chartreuse
			editor.emit_signal("dir_tint_changed", selected[1].file_path)
			_redraw()
		"Reset Tint":
			selected[1].tint = ""#Color.white
			editor.emit_signal("dir_tint_changed", selected[1].file_path)
			_redraw()

func _file_popup(index:int):
	var type = selected[0]
	var file = selected[1]
	if type == "d":
		file = file.file_path
	
	match file_popup.get_item_text(index):
		"Rename":
			var fname:String = file.get_file()
			var i:int = fname.find(".")
			editor.line_edit.display(fname, self, "_renamed")
			editor.line_edit.select(0, i)
		
		"Remove":
			if type == "f":
				editor.recycle(file, true)
		
		_:
			selected = []

func _renamed(new_file:String):
	var type = selected[0]
	var file = selected[1]
	
	var old_path:String = file
	var old_file:String = old_path.get_file()
	if new_file != old_file:
		var new_path:String = old_path.get_base_dir().plus_file(new_file)
		editor.rename_file(old_path, new_path)
	selected = []

func _input(e:InputEvent):
	if not editor.is_plugin_active():
		return
	
	if e is InputEventMouseButton and meta_hovered:
		var type = meta_hovered[0]
		var file = meta_hovered[1]
		
		if e.button_index == BUTTON_LEFT:
			if e.pressed:
				if type in ["f", "d"]:
					
					if type == "f" and Input.is_key_pressed(KEY_CONTROL):
						editor.file_data[file].open = not editor.file_data[file].open
						_redraw()
					
					else:
						var file_path = file if type == "f" else file.file_path
						
						# can't move recycling
						if editor.is_trash_path(file_path):
							return
						
						# select for drag
						else:
							dragging = meta_hovered
							
							drag_label = DragLabel.new(file_path.get_file())
							drag_label.editor = editor
							editor.add_child(drag_label)
			
			else:
				if type == "f" and Input.is_key_pressed(KEY_CONTROL):
					pass
				
				else:
					if dragging and dragging != meta_hovered:
						var drag_type = dragging[0]
						var drag_file = dragging[1]
						
						# dragged onto directory?
						if type == "d":
							var dir:String = file.file_path
							var old_path:String = drag_file if drag_type == "f" else drag_file.file_path
							var new_path:String = dir.plus_file(old_path.get_file())
							editor.rename_file(old_path, new_path)
						
						dragging = []
					
					else:
						match type:
							# toggle directory
							"d":
								file.open = not file.open
								_redraw()
							
							# unrecycle
							"unrecycle":
								editor.unrecycle(file.file_path)
							
							# select
							"f":
								editor.select_file(file)
							
							# select file symbol
							"fs":
								editor.select_file(file)
								var tab = editor.get_selected_tab()
								yield(get_tree(), "idle_frame")
								tab.goto_symbol(meta_hovered[2])
				
			get_tree().set_input_as_handled()
		
		elif e.button_index == BUTTON_RIGHT:
			if e.pressed:
				selected = meta_hovered
				match type:
					"d":
						dir_popup.set_global_position(get_global_mouse_position())
						dir_popup.popup()
					
					"f":
						file_popup.set_global_position(get_global_mouse_position())
						file_popup.popup()
				get_tree().set_input_as_handled()

func _file_opened(_file_path:String): _redraw()
func _file_closed(_file_path:String): _redraw()
func _file_selected(_file_path:String): _redraw()
func _file_renamed(_op:String, _np:String): _redraw()

var lines:PoolStringArray = PoolStringArray()

func _redraw():
	lines = PoolStringArray()
	_draw_dir(editor.file_list[""], 0)
	set_bbcode(lines.join("\n"))

func _dull_nonwords(s:String, clr:Color, dull:Color) -> String:
	var on = false
	var parts = []
	for c in s:
		on = c in "0123456789_-"
		if not parts or parts[-1][0] != on:
			parts.append([on, ""])
		parts[-1][1] += c
	var out = ""
	for p in parts:
		out += clr(p[1], dull if p[0] else clr)
	return out

const FOLDER:String = "🗀" # not visible in godot
func _draw_dir(dir:Dictionary, deep:int):
	var is_tagging = editor.is_tagging()
	var dimmest:float = .5 if is_tagging else 0.0
	var tint = editor.get_tint_color(dir.tint)
	var dull = Color.white.darkened(.65)
	var dull_tint = tint.darkened(.5)
	
	var space = clr("┃ ".repeat(deep), Color.white.darkened(.8))
	var file:String = dir.file_path
	var head:String = "▼" if dir.open else "▶"
	head = clr(space+FOLDER, Color.gold) + clr(head, Color.white.darkened(.5))
	head += " " + b(_dull_nonwords(file.get_file(), tint.darkened(0 if editor.is_dir_tagged(dir) else 0.5), dull))
	var link:String = meta(head, ["d", dir], editor.get_localized_path(file))
	if editor.is_trash_path(file):
		link += " " + meta(clr("⬅", Color.yellowgreen), ["unrecycle", dir], file)
	
	lines.append(link)
	
	var sel = editor.get_selected_tab()
	sel = sel.file_path if sel else ""
	
	if dir.open:
		# draw dirs
		for path in dir.dirs:
			var file_path = dir.all[path]
			if file_path is Dictionary and file_path.show:
				_draw_dir(file_path, deep+1)
		
		# draw files
		var last = len(dir.files)-1
		for i in len(dir.files):
			var file_path = dir.files[i]
			file = file_path.get_file()
			var p = [file, ""] if not "." in file else file.split(".", true, 1)
			file = p[0]
			var ext = p[1]
			
			var is_selected = file_path == sel
			var is_opened = editor.is_opened(file_path)
			var color = tint
			head = "┣╸" if i != last else "┗╸"
			
			var fname_lower = file.to_lower()
			
			if "readme" in fname_lower:
				head = "🛈"
			
			head = clr(head, Color.white.darkened(.5 if is_opened else .75))
			
			var bold = false
			if is_tagging:
				if editor.is_tagged(file_path):
					bold = true
				
				else:
					color = color.darkened(dimmest)
			else:
				pass
			
			file = _dull_nonwords(file, color, dull)
			
			if bold:
				file = b(file)
			
			ext = "" if not ext else clr("." + ext, dull)
			
			var line = file + ext
			
			if is_selected:
				line = u(line)
			
			var hint_path = editor.get_localized_path(file_path)
			var symbol_lines = []
			
			if not editor._scanning:
				var fdata = editor.file_data[file_path]
				var symbols = fdata.symbols.values()
				for j in range(1, len(symbols)):
					if fdata.open or filter:
						var sdata = symbols[j]
						var sname = sdata.name
						if filter and not filter in sname.to_lower():
							continue
						var s = "  ".repeat(sdata.deep) + clr("  %s) " % [j], dull) + clr(sname, dull_tint)
						var h = hint_path + " #" + sname
						symbol_lines.append(meta(space + s, ["fs", file_path, j], h))
			
			if symbol_lines or not (filter and not filter in fname_lower):
				lines.append(meta(space + head + line, ["f", file_path], hint_path))
				lines.append_array(symbol_lines)
