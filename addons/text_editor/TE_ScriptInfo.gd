tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

var chapter_info:Array = []
var sort_on:String = "words"
var sort_on_index:int = 1
var sort_reverse:Dictionary = { id=true, chaps=true, words=true, uwords=true, "%":true, modified=true }
var skip_words:PoolStringArray

func _ready():
	var btn = get_parent().get_node("update")
	btn.add_font_override("font", editor.FONT_R)
	
	var _e = btn.connect("pressed", self, "_update")

func _update():
	chapter_info.clear()
	
	# load block list
	var skip_list = editor.current_directory.plus_file("word_skip_list.txt")
	if File.new().file_exists(skip_list):
		skip_words = TE_Util.load_text(skip_list).replace("\n", " ").strip_edges().to_lower().split(" ")
	else:
		skip_words = PoolStringArray()
	
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

const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS = ["Januaray", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

const TIMES:Dictionary = {
	"second": 60,
	"minute": 60,
	"hour": 24,
	"day": INF
}
func get_time(t:int) -> String:
	for k in TIMES:
		if t < TIMES[k]:
			return "%s %s ago" % [t, k + ("" if t == 1 else "s")]
		t /= TIMES[k]
	return "???"

func _process_md(path:String):
	var lines = TE_Util.load_text(path).split("\n")
	var file_time = File.new().get_modified_time(path)
	var curr_time = OS.get_unix_time()
	var diff_time = curr_time - file_time
	var time_nice = get_time(diff_time)
	
	if false and diff_time > 9999999:
		time_nice = OS.get_datetime_from_unix_time(file_time)
		time_nice.weekday = WEEKDAYS[time_nice.weekday-1].substr(0, 3).to_lower()
		time_nice.month = MONTHS[time_nice.month-1].substr(0, 3).to_lower()
		time_nice.hour12 = str(time_nice.hour % 12)
		time_nice.ampm = "am" if time_nice.hour > 12 else "pm"
		time_nice = "{weekday} {month} {day}, {year} {hour12}:{minute}:{second}{ampm}".format(time_nice)
	
	var out = { path=path, line=0, id=editor.get_localized_path(path), modified=file_time, time_nice=time_nice, words=0, uwords={}, chaps=0, "%":0.0 }
	chapter_info.append(out)
	var i = 0
	while i < len(lines):
		# skip head meta
		if i == 0 and lines[i].begins_with("---"):
			i += 1
			while i < len(lines) and not lines[i].begins_with("---"):
				if ":" in lines[i]:
					var p = lines[i].split(":", true, 1)
					var k = p[0].strip_edges()
					var v = p[1].strip_edges()
					match k:
						"name":
							out.id = v
						
						"prog", "progress":
							out["%"] = float(v.replace("%", ""))
				
				i += 1
		
		# skip comments
		elif "<!--" in lines[i]:
			pass
		
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
			out.chaps += 1
		
		else:
			out.words += TE_Util.count_words(lines[i], out.uwords, skip_words)
		
		i += 1
	
	# sort word counts
	TE_Util.sort_vals(out.uwords)
	var words = PoolStringArray(out.uwords.keys())
	var words_top = words
	if len(words_top) > 16:
		words_top.resize(16)
	out.uwords = words_top.join(" ")
	
	var word_lines = [""]
	for word in words:
		if len(word_lines[-1]) >= 64:
			word_lines.append("")
		if word_lines[-1]:
			word_lines[-1] += " "
		word_lines[-1] += word
	out.uwords_all = PoolStringArray(word_lines).join("\n")
	
func _clicked(args):
	match args[0]:
		"sort_table":
			var key = args[1]
			if sort_on != key:
				sort_on = key
				sort_on_index = sort_reverse.keys().find(sort_on)
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
	var ch1 = lerp(c1, Color.yellowgreen, .5)
	var ch2 = lerp(c2, Color.yellowgreen, .5)
	
	var cols = ["id", "chaps", "words", "uwords", "%", "modified"]
	push_align(RichTextLabel.ALIGN_CENTER)
	push_table(len(cols))
	add_constant_override("table_hseparation", 8)
	
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
		var clrh = ch1 if i%2==0 else ch2
		
		# id
		push_cell()
		push_color(clrh if sort_on_index == 0 else clr)
		push_meta(add_meta(["goto", item.path, item.line], item.path + "\n" + item.uwords_all))
		add_text(item.id)
		pop()
		pop()
		pop()
		
		# chapters
		push_cell()
		push_color(clrh if sort_on_index == 1 else clr)
		add_text(TE_Util.commas(item.chaps))
		pop()
		pop()
		
		# word cound
		push_cell()
		push_color(clrh if sort_on_index == 2 else clr)
		add_text(TE_Util.commas(item.words))
		pop()
		pop()
		
		# unique words
		push_cell()
		push_color(clrh if sort_on_index == 3 else clr)
		add_text(item.uwords)
		pop()
		pop()
		
		# percent
		push_cell()
		push_color(clrh if sort_on_index == 4 else clr)
		add_text(str(int(item["%"])))
		pop()
		pop()
		
		# time
		push_cell()
		push_color(clrh if sort_on_index == 5 else clr)
		add_text(item.time_nice)
		pop()
		pop()
	
	pop()
	pop()
