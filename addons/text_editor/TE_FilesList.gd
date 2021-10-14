tool
extends RichTextLabel

onready var editor:TextEditor = owner
onready var file_popup:PopupMenu = $file_popup
onready var dir_popup:PopupMenu = $dir_popup

const DragLabel = preload("res://addons/text_editor/TE_DragLabel.gd")
var drag_label:RichTextLabel

var files:Array = []
var dirs:Array = []
var selected
var hovered:String = ""
var dragging:String = ""
var drag_start:Vector2


func _ready():
	var _e
	_e = editor.connect("updated_file_list", self, "_redraw")
	_e = editor.connect("tags_updated", self, "_redraw")
	_e = editor.connect("file_opened", self, "_file_opened")
	_e = editor.connect("file_closed", self, "_file_closed")
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = editor.connect("file_renamed", self, "_file_renamed")
	_e = connect("meta_hover_started", self, "_meta_entered")
	_e = connect("meta_hover_ended", self, "_meta_exited")
	
	# hint
	theme = Theme.new()
	theme.set_font("font", "TooltipLabel", editor.FONT_R)
	
	# file popup
	file_popup.clear()
	file_popup.rect_size = Vector2.ZERO
	file_popup.add_item("Rename")
	file_popup.add_separator()
	file_popup.add_item("Remove")
	_e = file_popup.connect("index_pressed", self, "_file_popup")
	file_popup.add_font_override("font", TextEditor.FONT)
	
	# dir popup
	dir_popup.clear()
	dir_popup.rect_size = Vector2.ZERO
	dir_popup.add_item("New File")
	dir_popup.add_item("New Folder")
	dir_popup.add_separator()
	dir_popup.add_item("Remove")
	_e = dir_popup.connect("index_pressed", self, "_dir_popup")
	dir_popup.add_font_override("font", TextEditor.FONT)
	
	add_font_override("normal_font", editor.FONT_R)
	add_font_override("bold_font", editor.FONT_B)
	add_font_override("italics_font", editor.FONT_I)
	add_font_override("bold_italics_font", editor.FONT_BI)

func _dir_popup(index:int):
	var p = _meta_to_file(selected)
	var type = p[0]
	var file = p[1]
	
	match dir_popup.get_item_text(index):
		"New File": editor.popup_create_file(file)
		"New Folder": editor.popup_create_dir(file)
		"Remove": editor.recycle(file)

func _file_popup(index:int):
	var p = _meta_to_file(selected)
	var type = p[0]
	var file = p[1]
	
	match file_popup.get_item_text(index):
		"Rename":
			var fname:String = file.get_file()
			var i:int = fname.find(".")
			editor.line_edit.display(fname, self, "_renamed")
			editor.line_edit.select(0, i)
		
		"Remove":
			if type == "f":
				editor.recycle(file)
		
		_:
			selected = {}

func _renamed(new_file:String):
	var p = _meta_to_file(selected)
	var type = p[0]
	var file = p[1]
	
	var old_path:String = file
	var old_file:String = old_path.get_file()
	if new_file != old_file:
		var new_path:String = old_path.get_base_dir().plus_file(new_file)
		editor.rename_file(old_path, new_path)
	selected = {}

func _input(e:InputEvent):
	if not editor.is_plugin_active():
		return
	
	if e is InputEventMouseButton and hovered:
		var p = _meta_to_file(hovered)
		var type = p[0]
		var file = p[1]
		
		if e.button_index == BUTTON_LEFT:
			
			if e.pressed:
				if type in ["f", "d"]:
					if file.begins_with(editor.PATH_TRASH):
						return # can't move recycling
					
					else:
						dragging = hovered
						
						drag_label = DragLabel.new(file.get_file())
						drag_label.editor = editor
						editor.add_child(drag_label)
			
			else:
				if dragging and dragging != hovered:
					var p2 = _meta_to_file(dragging)
					var drag_type = p2[0]
					var drag_file = p2[1]
					
					if type == "d":
						var dir:String = file
						var old_path:String = drag_file
						var new_path:String = dir.plus_file(old_path.get_file())
						editor.rename_file(old_path, new_path)
					
					dragging = ""
				
				else:
					match type:
						# toggle directory
						"d":
							p[2].open = not p[2].open
							_redraw()
						
						# unrecycle
						"unrecycle":
							editor.unrecycle(file)
						
						# select
						"f":
							editor.select_file(file)
				
			get_tree().set_input_as_handled()
		
		elif e.button_index == BUTTON_RIGHT:
			if e.pressed:
				selected = hovered
				match type:
					"d":
						dir_popup.set_global_position(get_global_mouse_position())
						dir_popup.popup()
					
					"f":
						file_popup.set_global_position(get_global_mouse_position())
						file_popup.popup()
				get_tree().set_input_as_handled()

func _meta_to_file(m:String):
	var p = m.split(":", true, 1)
	var type = p[0]
	var index = int(p[1])
	match type:
		"d", "unrecycle":
			return [type, dirs[index].file_path, dirs[index]]
		"f":
			return [type, files[index]]

func _meta_entered(m):
	hovered = m
	var f = _meta_to_file(m)
	match f[0]:
		"f", "d": hint_tooltip = f[1]
		"unrecycle": hint_tooltip = "Unrecycle %s" % f[1]

func _meta_exited(_m):
	hovered = ""
	hint_tooltip = ""

func _file_opened(_file_path:String): _redraw()
func _file_closed(_file_path:String): _redraw()
func _file_selected(_file_path:String): _redraw()
func _file_renamed(_op:String, _np:String): _redraw()

var lines:PoolStringArray = PoolStringArray()

func _redraw():
	lines = PoolStringArray()
	dirs.clear()
	files.clear()
	_draw_dir(editor.file_list[""], 0)
	set_bbcode(lines.join("\n"))

func clr(s:String, c:Color) -> String: return "[color=#%s]%s[/color]" % [c.to_html(), s]
func i(s:String) -> String: return "[i]%s[/i]" % s
func b(s:String) -> String: return "[b]%s[/b]" % s
func url(s:String, url:String) -> String: return "[url=%s]%s[/url]" % [url, s]

const FOLDER:String = "🗀" # not visible in godot
func _draw_dir(dir:Dictionary, deep:int):
	var is_tagging = editor.is_tagging()
	var dimmest:float = .5 if is_tagging else 0.0
	
	var space = clr("┃ ".repeat(deep), Color.white.darkened(.8))
	var file:String = dir.file_path
	var name:String = b(file.get_file())
	var head:String = "▼" if dir.open else "▶"
	var dir_index:int = len(dirs)
	var link:String = url(space+clr(FOLDER+head, Color.white.darkened(.5))+" "+name, "d:%s" % dir_index)
	if file.begins_with(editor.PATH_TRASH) and file.count("/") == 3:
		link += " " + url(clr("⬅", Color.yellowgreen), "unrecycle:%s" % dir_index)
	lines.append(clr(link, Color.white.darkened(dimmest)))
	dirs.append(dir)
	
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
			var p = file.split(".", true, 1)
			file = p[0]
			var ext = p[1]
			
			var is_selected = file_path == sel
			var is_opened = editor.is_opened(file_path)
			var color = Color.white
			head = "┣╸" if i != last else "┗╸"
			
			if "readme" in file.to_lower():
				head = "🛈"
			
			if is_selected:
				head = "● "
			
			elif is_opened:
				head = "○ "
			
			head = clr(head, Color.white.darkened(.5 if is_opened else .75))
			
			if is_tagging:
				if editor.is_tagged(file_path):
					file = b(file)
					
				else:
					color = color.darkened(dimmest)
			else:
				pass
					
			file = clr(file, color)
			ext = clr("." + ext, Color.white.darkened(.65))
			var line = space + head + file + ext
			lines.append(url(line, "f:%s" % len(files)))
			files.append(file_path)
