tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

var chapter_info:Array = []
var sort_on:String = "words"
var sort_reverse:Dictionary = { id=false, words=false, chaps=false, "%":false }

func _ready():
	var btn = get_parent().get_node("update")
	btn.add_font_override("font", editor.FONT_R)
	
	var _e = btn.connect("pressed", self, "_update")

func _update():
	chapter_info.clear()
	
	for path in editor.file_paths:
		var file = path.get_file()
		var ext = file.get_extension()
		match ext:
			"md": _process_md(path)
	
	# clear empty
	for i in range(len(chapter_info)-1, -1, -1):
		var info = chapter_info[i]
		if not info.words:
			chapter_info.remove(i)
	
	_sort()
	_redraw()

func _chapter(path:String, line:int, id:String):
	if not id:
		id = "???"
	chapter_info.append({ path=path, line=line, id=id, words=0, chaps=0, "%":0.0 })
	
func _process_md(path:String):
	var lines = TE_Util.load_text(path).split("\n")
	var is_entire_file:bool = false
	
	_chapter(path, 0, "(Noname)")
	var i = 0
	while i < len(lines):
		# skip head meta
		if i == 0 and lines[i].begins_with("---"):
			is_entire_file = true
			i += 1
			while i < len(lines) and not lines[i].begins_with("---"):
				if lines[i].begins_with("name: "):
					chapter_info[-1].id = lines[i].split("name: ", true, 1)[1]
				
				elif lines[i].begins_with("progress: "):
					chapter_info[-1]["%"] = float(lines[i].split("progress: ", true, 1)[1].replace("%", ""))
				elif lines[i].begins_with("prog: "):
					chapter_info[-1]["%"] = float(lines[i].split("prog: ", true, 1)[1].replace("%", ""))
				
				i += 1
		
		# skip code blocks
		elif lines[i].begins_with("~~~") or lines[i].begins_with("```"):
			var head = lines[i].substr(0, 3)
			i += 1
			while i < len(lines) and not lines[i].begins_with(head):
				i += 1
		
		# heading
		elif lines[i].begins_with("#"):
			var p = lines[i].split(" ", true, 1)
			var id = lines[i].split(" ", true, 1)
			var deep = len(id[0])
			id = "???" if len(id) == 1 else id[1].strip_edges()
			if deep == 1 and not is_entire_file:
				_chapter(path, i, id)
			else:
				chapter_info[-1].chaps += 1
		
		else:
			var words = lines[i].split(" ", false)
			chapter_info[-1].words += len(words)
		
		i += 1

func _clicked(args):
	match args[0]:
		"sort_table":
			var key = args[1]
			if sort_on != key:
				sort_on = key
			else:
				sort_reverse[key] = not sort_reverse[key]
			
			_sort()
			_redraw()
		
		"goto":
			var tab = editor.open_file(args[1])
			editor.select_file(args[1])
			tab.goto_line(args[2])

func _sort():
	if sort_reverse[sort_on]:
		chapter_info.sort_custom(self, "_sort_chapters_r")
	else:
		chapter_info.sort_custom(self, "_sort_chapters")

func _sort_chapters(a, b):
	return a[sort_on] < b[sort_on]

func _sort_chapters_r(a, b):
	return a[sort_on] > b[sort_on]

func _redraw():
	clear()
	
	var c1 = Color.white.darkened(.4)
	var c2 = Color.white.darkened(.3)
	var cols = ["id", "words", "chaps", "%"]
	push_align(RichTextLabel.ALIGN_CENTER)
	push_table(len(cols))
	for id in cols:
		push_cell()
		push_bold()
		push_meta(add_meta(["sort_table", id], "sort on %s" % id))
		add_text(id)
		if sort_on == id:
			push_color(Color.greenyellow.darkened(.25))
			add_text(" ⯅" if sort_reverse[id] else " ⯆")
			pop()
		else:
			push_color(Color.white.darkened(.7))
			add_text(" ⯅" if sort_reverse[id] else " ⯆")
			pop()
		pop()
		pop()
		pop()
	
	for i in len(chapter_info):
		var item = chapter_info[i]
		var clr = c1 if i%2==0 else c2
		
		# id
		push_cell()
		push_color(clr)
		push_meta(add_meta(["goto", item.path, item.line], item.path))
		add_text(item.id)
		pop()
		pop()
		pop()
		
		# word cound
		for x in ["words", "chaps"]:
			push_cell()
			push_color(clr)
			add_text(TE_Util.commas(item[x]))
			pop()
			pop()
		
		# percent
		push_cell()
		push_color(clr)
		add_text(str(int(item["%"])))
		pop()
		pop()
	
	pop()
	pop()
