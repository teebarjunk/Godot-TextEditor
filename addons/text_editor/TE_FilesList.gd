tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

onready var file_popup:PopupMenu = $file_popup
onready var dir_popup:PopupMenu = $dir_popup

const DragLabel = preload("res://addons/text_editor/TE_DragLabel.gd")
var drag_label:RichTextLabel

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
			selected[1].tint = Color.gold
			_redraw()
		"Tint Red":
			selected[1].tint = Color.tomato
			_redraw()
		"Tint Blue":
			selected[1].tint = Color.deepskyblue
			_redraw()
		"Tint Green":
			selected[1].tint = Color.chartreuse
			_redraw()
		"Reset Tint":
			selected[1].tint = Color.white
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

const FOLDER:String = "🗀" # not visible in godot
func _draw_dir(dir:Dictionary, deep:int):
	var is_tagging = editor.is_tagging()
	var dimmest:float = .5 if is_tagging else 0.0
	
	var space = clr("┃ ".repeat(deep), Color.white.darkened(.8))
	var file:String = dir.file_path
	var head:String = "▼" if dir.open else "▶"
	head = clr(space+FOLDER+head, Color.white.darkened(.5))
	head += " " + b(file.get_file())
	var link:String = meta(head, ["d", dir], editor.get_localized_path(file))
	if editor.is_trash_path(file):
		link += " " + meta(clr("⬅", Color.yellowgreen), ["unrecycle", dir], file)
	lines.append(clr(link, dir.tint.darkened(dimmest)))
	
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
			var color = dir.tint
			head = "┣╸" if i != last else "┗╸"
			
			if "readme" in file.to_lower():
				head = "🛈"
			
#			if is_selected or is_opened:
#				head = "● "
#
#			elif is_opened:
#				head = "○ "
			
			head = clr(head, Color.white.darkened(.5 if is_opened else .75))
			
			if is_tagging:
				if editor.is_tagged(file_path):
					file = b(file)
					
				else:
					color = color.darkened(dimmest)
			else:
				pass
					
			file = clr(file, color)
			ext = "" if not ext else clr("." + ext, Color.white.darkened(.65))
			
			var line = file + ext
			
			if is_selected:
				line = u(line)
			
#			if is_opened:
#				line = b(line)
			
			lines.append(meta(space + head + line, ["f", file_path], editor.get_localized_path(file_path)))
