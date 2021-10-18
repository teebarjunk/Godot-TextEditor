tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

var chapter_info:Array = []
var sort_on:String = "words"
var sort_reverse:Dictionary = { id=false, words=false, unique=false }

func _ready():
	var _e
	_e = editor.connect("file_opened", self, "_update")
	_e = editor.connect("file_saved", self, "_update")

func _update(f):
	set_process(true)

func _process(_delta):
	chapter_info.clear()
	
	for path in editor.file_paths:
		var file = path.get_file()
		var ext = file.get_extension()
		match ext:
			"md": _process_md(path)
	
	_sort()
	_redraw()
	
	set_process(false)

func _chapter(path:String, line:int, id:String):
	chapter_info.append({ path=path, line=line, id=id, words=0, chars=0, unique=0 })

func _process_md(path:String):
	var lines = TE_Util.load_text(path).split("\n")
	_chapter(path, 0, "NOH")
	var i = 0
	while i < len(lines):
		# skip head meta
		if i == 0 and lines[i].begins_with("---"):
			i += 1
			while i < len(lines) and not lines[i].begins_with("---"):
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
			var id = lines[i].split(" ", true, 1)[1].strip_edges()
			_chapter(path, i, id)
		
		else:
			var words = lines[i].split(" ", false)
			var unique = []
			for word in words:
				var w = clean_word(word.to_lower())
				if w and not w in unique:
					unique.append(w)
			
			chapter_info[-1].words += len(words)
			chapter_info[-1].unique += len(unique)
		
		i += 1

func clean_word(w:String):
	var out = ""
	for c in w:
		if c in "abcdefghijklmnopqrstuvwxyz":
			out += c
	return out

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
			print(args)
			var tab = editor.open_file(args[1])
			editor.select_file(args[1])
			tab.goto_line(args[2])

func _sort():
	if sort_reverse[sort_on]:
		chapter_info.sort_custom(self, "_sort_chapters")
	else:
		chapter_info.sort_custom(self, "_sort_chapters_r")

func _sort_chapters(a, b): return a[sort_on] < b[sort_on]
func _sort_chapters_r(a, b): return a[sort_on] >= b[sort_on]

func _redraw():
	clear()
	
	var c1 = Color.white.darkened(.4)
	var c2 = Color.white.darkened(.3)
	
	push_align(RichTextLabel.ALIGN_CENTER)
	push_table(3)
	for id in ["id", "words", "unique"]:
		push_cell()
		push_bold()
		push_meta(add_meta(["sort_table", id], "sort on %s" % id))
		add_text(id)
		if sort_on == id:
			push_color(Color.white.darkened(.5))
			add_text(" ⯅" if sort_reverse[id] else " ⯆")
			pop()
		pop()
		pop()
		pop()
	
	for i in len(chapter_info):
		var item = chapter_info[i]
		
		if item.id == "NOH" and not item.words:
			continue
		
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
		for w in ["words", "unique"]:
			push_cell()
			push_color(clr)
			add_text(TE_Util.commas(item[w]))
			pop()
			pop()
	
	pop()
	pop()
