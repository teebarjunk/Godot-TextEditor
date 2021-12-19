tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

onready var line_edit:LineEdit = get_parent().get_node("c/le")
onready var all_toggle:CheckBox = get_parent().get_node("c/all")
onready var case_toggle:CheckBox = get_parent().get_node("c/case")

var console_urls:Array = []
var last_search:String = ""

func _ready():
	var _e
	_e = line_edit.connect("text_entered", self, "_text_entered")
	
	# fix fonts
	line_edit.add_font_override("font", editor.FONT_R)
	all_toggle.add_font_override("font", editor.FONT_R)
	case_toggle.add_font_override("font", editor.FONT_R)

func select():
	line_edit.grab_focus()
	line_edit.grab_click_focus()
	line_edit.select_all()

func _clicked(args):
	match args[0]:
		"goto":
			var tab:TextEdit = editor.open_file(args[1])
			editor.select_file(args[1])
			yield(get_tree(), "idle_frame")
			# goto line
			var hfrom = int(args[2])
			var line = int(args[3])
			tab.goto_line(hfrom)
			tab.goto_line(line, false)
			# select area
			var from = int(args[4])
			var lenn = int(args[5])
			tab.select(line, from, line, from + lenn)
			tab.cursor_set_line(line)
			tab.cursor_set_column(from)

func _text_entered(search_for:String):
	last_search = search_for
	clear()
	var found:Dictionary = _search(search_for)
	var bbcode:PoolStringArray = PoolStringArray()
	var fpaths = found.keys()
	
	for k in len(fpaths):
		if k != 0:
			bbcode.append("")
		
		var file_path:String = fpaths[k]
		var l = clr("%s/%s " % [k+1, len(fpaths)], Color.orange) + clr(file_path.get_file(), Color.yellow)
		l = meta(l, ["goto", file_path, 0, 0, 0], file_path)
		bbcode.append(l)
		
		var all_found = found[file_path]
		for j in len(all_found):
			var result = found[file_path][j]
			var got_lines = result[0]
			var highlight_from = result[1]
			var line_index = result[2]
			var char_index = result[3]
			
			bbcode.append(clr("  %s/%s" % [j+1, len(all_found)], Color.orange))
			
			for i in len(got_lines):
				l = ""
				var highlight = got_lines[i][0]
				var lindex = got_lines[i][1]
				var ltext = got_lines[i][2]
				
				if highlight:
#					var line:String = ltext
#					var head:String = line.substr(0, char_index)
#					var midd:String = line.substr(char_index, len(search_for))
#					var tail:String = line.substr(char_index+len(search_for))
#					head = clr(head, Color.white.darkened(.25))
#					midd = b(clr(midd, Color.white))
#					tail = clr(tail, Color.white.darkened(.25))
					
					var h = TE_Util.highlight(ltext, char_index, len(search_for), Color.white.darkened(.25), Color.white)
					
					l = "\t" + clr(str(lindex) + ": ", Color.white.darkened(.25)) + h
				
				else:
					l = "\t" + clr(str(lindex) + ": ", Color.white.darkened(.65)) + clr(ltext, Color.white.darkened(.5))
				
				if l:
					l = meta(l, ["goto", file_path, highlight_from, line_index, char_index, len(search_for)])
					bbcode.append(l)
	
	set_bbcode(bbcode.join("\n"))



# get a list of files containging lines
func _search(search_for:String) -> Dictionary:
	var out = {}
	var search_for_l:String
	
	if case_toggle.pressed:
		search_for_l = search_for
	else:
		search_for_l = search_for.to_lower()
		
	var paths:Array
	
	# search all
	if all_toggle.pressed:
		paths = editor.file_paths
	
	# only search selected
	else:
		var sel = editor.get_selected_file()
		if not sel:
			var err_msg = "no file open to search"
			editor.console.err(err_msg)
			push_error(err_msg)
			return out
		
		else:
			paths = [sel]
	
	for path in paths:
		var lines = TE_Util.load_text(path).split("\n")
		for line_index in len(lines):
			var line:String = lines[line_index]
			
			# make lowercase, if case doesn't matter
			if not case_toggle.pressed:
				line = line.to_lower()
			
			# find index where result is found
			var char_index:int = line.find(search_for_l)
			if char_index != -1:
				if not path in out:
					out[path] = []
				
				var preview_lines = [[true, line_index, lines[line_index]]]
				var highlight_from:int = line_index
				
				# previous few lines before a blank
				for i in range(1, 3):
					if line_index-i >= 0:
						if not lines[line_index-i].strip_edges():
							break
						highlight_from = line_index-i
						preview_lines.push_front([false, line_index-i, lines[line_index-i]])
				
				# next few lines before a blank
				for i in range(1, 3):
					if line_index+i < len(lines):
						if not lines[line_index+i].strip_edges():
							break
						preview_lines.push_back([false, line_index+i, lines[line_index+i]])
				
				# lines, index in file, index in line
				out[path].append([preview_lines, highlight_from, line_index, char_index])
	
	return out
