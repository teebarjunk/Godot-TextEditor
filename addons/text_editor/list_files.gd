extends RichTextLabel

onready var editor:TextEditor = owner
onready var popup:PopupMenu = $popup
onready var drag_label:RichTextLabel = $drag_label

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
#	_e = connect("meta_clicked", self, "_clicked")
	_e = connect("meta_hover_started", self, "_meta_entered")
	_e = connect("meta_hover_ended", self, "_meta_exited")
	
	# popup
	popup.add_item("Rename")
	popup.add_separator()
	popup.add_item("Remove")
	_e = popup.connect("index_pressed", self, "_popup")
	popup.add_font_override("font", TextEditor.FONT)
	
	for n in [self, drag_label]:
		n.add_font_override("normal_font", editor.FONT_R)
		n.add_font_override("bold_font", editor.FONT_B)
		n.add_font_override("italics_font", editor.FONT_I)
		n.add_font_override("bold_italics_font", editor.FONT_BI)
	
	set_process(false)

func _popup(index:int):
	var p = selected.split(":", true, 1)
	var type = p[0]
	var file = files[int(p[1])] if type == "f" else dirs[int(p[1])] if type == "d" else ""
	
	match popup.get_item_text(index):
		"Rename":
			var fname:String = selected.file_path.get_file()
			var i:int = fname.find(".")
			editor.line_edit.display(fname, self, "_renamed")
			editor.line_edit.select(0, i)
		
		"Remove":
			if type == "f":
				editor.recycle_file(file)
		
		_:
			selected = {}

func _renamed(new_file:String):
	var old_path:String = selected.file_path
	var old_file:String = old_path.get_file()
	if new_file != old_file:
		var new_path:String = old_path.get_base_dir().plus_file(new_file)
		editor.rename_file(old_path, new_path)
	selected = {}

func _process(_delta):
	var mp = get_global_mouse_position()
	if mp.distance_to(drag_start) > 16:
		drag_label.visible = true
	drag_label.set_global_position(mp)

func end_drag():
	dragging = ""
	drag_label.visible = false
	set_process(false)

func _input(e:InputEvent):
	if e is InputEventMouseButton and hovered:
		var m = hovered.split(":", true, 1)
		var type = m[0]
		var index = int(m[1])
		
		if e.button_index == BUTTON_LEFT:
			if e.pressed:
				dragging = hovered
				
				if type == "f":
					drag_label.set_bbcode(files[index].get_file())
#					drag_label.visible = true
					drag_start = get_global_mouse_position()
					set_process(true)
			
			else:
				if dragging and dragging != hovered:
					m = dragging.split(":", true, 1)
					var drag_type = m[0]
					var drag_index = int(m[1])
					if drag_type == "f" and type == "d":
						var dir:String = dirs[index].file_path
						var old_path:String = files[drag_index]
						var new_path:String = dir.plus_file(old_path.get_file())
						editor.rename_file(old_path, new_path)
				
				else:
					if type == "d":
						dirs[index].open = not dirs[index].open
						_redraw()
					
					elif type == "f":
						editor.select_file(files[index])
				
				end_drag()
				get_tree().set_input_as_handled()
				return
		
		elif e.button_index == BUTTON_RIGHT:
			if e.pressed:
				selected = hovered
				popup.set_global_position(get_global_mouse_position())
				popup.popup()
				get_tree().set_input_as_handled()
				return

	if e is InputEventMouseButton:
		if dragging and (e.button_index == BUTTON_LEFT and not e.pressed) or (e.button_index == BUTTON_RIGHT):
			end_drag()
			get_tree().set_input_as_handled()
			return
			

func _meta_entered(m): hovered = m

func _meta_exited(_m): hovered = ""

func _file_opened(_file_path:String): _redraw()
func _file_closed(_file_path:String): _redraw()
func _file_selected(_file_path:String): _redraw()
func _file_renamed(_op:String, _np:String): _redraw()

#func updated_file_list():
#	items.clear()
#	_updated_file_list(editor.file_list, 0)
#	redraw()

var lines:PoolStringArray = PoolStringArray()

func _redraw():
	lines = PoolStringArray()
	lines.append("[url=add_file:0][color=#%s]+[/color][/url]" % [Color.green.to_html()])
	dirs.clear()
	_draw_dir(editor.file_list[""], 0)
	set_bbcode(lines.join("\n"))

func clr(s:String, c:Color) -> String: return "[color=#%s]%s[/color]" % [c.to_html(), s]
func i(s:String) -> String: return "[i]%s[/i]" % s
func b(s:String) -> String: return "[b]%s[/b]" % s
func url(s:String, url:String) -> String: return "[url=%s]%s[/url]" % [url, s]

const FOLDER:String = "🗀" # not visible in godot
func _draw_dir(dir:Dictionary, deep:int):
	var space = clr("┃ ".repeat(deep), Color.white.darkened(.8))
	var file:String = dir.file_path
	var name:String = b(file.get_file())
	var head:String = "▼" if dir.open else "▶"
	var link:String = url("%s%s%s%s" % [space, FOLDER, head, name], "d:%s" % len(dirs))
	lines.append(clr(link, Color.white.darkened(.7)))
	dirs.append(dir)
#	var add = "[url=add_file:%s][color=#%s]+[/color][/url]" % [dindex, Color.green.to_html()]
#	name = "[color=#%s]%s[/color] %s" % [Color.darkslategray.to_html(), item.name, add]
	
	var sel = editor.get_selected_tab()
	sel = sel.file_path if sel else ""
	
	if dir.open:
		var i = 0
		var last = len(dir.files)-1
		for path in dir.files:
			var file_path = dir.files[path]
			# dir
			if file_path is Dictionary:
				_draw_dir(file_path, deep+1)
			
			# file
			else:
				file = path.get_file()
				var is_selected = file_path == sel
				head = "┣╸" if i != last else "┗╸"
				if is_selected:
					head = clr(head, Color.white.darkened(.5))
				else:
					head = clr(head, Color.white.darkened(.8))
				var p = file.split(".", true, 1)
				file = p[0]
				
				var color = Color.white if editor.is_tagged(file_path) else Color.white.darkened(.5)
				
				if editor.is_selected(file_path):
					file = clr(file, color)
				elif editor.is_opened(file_path):
					file = clr(file, color.darkened(.5))
				else:
					file = i(clr(file, color.darkened(.75)))
				
				var ext = clr(p[1], Color.white.darkened(.6))
				var line = space + head + file + "." + ext
				lines.append(url(line, "f:%s" % len(files)))
				files.append(file_path)
			i += 1
		
		
		
		# file
#		else:
#			var p = item.name.split(".", true, 1)
#			name = p[0]
#			var ext = p[1]
#			var clr = Color.white
#			var dim = .75
#
#			if editor.is_selected(item.file_path):
#				dim = 0.0
#
#			elif editor.is_open(item.file_path):
#				dim = .5
#
#			name = "[color=#%s]%s[/color]" % [clr.darkened(dim).to_html(), name]
#			name += "[color=#%s].%s[/color]" % [clr.darkened(.75).to_html(), ext]
#
#			var tab = editor.get_tab(item.file_path)
#			if tab and editor.is_tagged_or_visible(tab.tags.keys()):
#				name = "[b]%s[/b]" % name
#
#		var space = ""
#		if item.deep:
#			wide += item.deep * 2
#
#			if item.deep > 1:
#				space += "┃ " + "  ".repeat(int(max(0, item.deep-2)))
#			else:
#				space += "  ".repeat(int(max(0, item.deep-1)))
#
#			if item.last:
#				space += "┗╸"
#			else:
#				space += "┣╸"
#
#		space = "[color=#%s]%s[/color]" % [Color.darkslategray.to_html(), space]
#
#		# add extra space to make clicking easier
#		var extra = max(0, 16 - wide)
#		name += " ".repeat(extra)
#		text.append("%s[url=f:%s]%s[/url]" % [space, i, name])
#
#	set_bbcode(text.join("\n"))

#func _updated_file_list(data:Dictionary, deep:int):
#	var total = len(data)
#	var i = 0
#	for k in data:
#		if data[k] is Dictionary:
#			items.append({ last=i==total-1, type="D", name=k, file_path=data[k].file_path, deep=deep, open=true })
#			_updated_file_list(data[k].files, deep+1)
#		else:
#			items.append({ last=i==total-1, type="F", name=k, file_path=data[k], deep=deep })
#		i += 1
