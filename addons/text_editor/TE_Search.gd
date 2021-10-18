tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

onready var line_edit:LineEdit = get_parent().get_node("le")

var console_urls:Array = []
var last_search:String = ""

func _ready():
	var _e
	_e = line_edit.connect("text_entered", self, "_text_entered")
	
	line_edit.add_font_override("font", editor.FONT_R)

func _unhandled_key_input(e):
	if not editor.is_plugin_active():
		return
	
	# Ctrl + F to search
	if e.scancode == KEY_F and e.pressed and e.control:
		line_edit.grab_focus()
		line_edit.grab_click_focus()
		get_parent().get_parent().show()
		get_parent().get_parent().current_tab = get_index()
		get_tree().set_input_as_handled()

func _clicked(args):
	match args[0]:
		"goto":
			var tab = editor.open_file(args[1])
			editor.select_file(args[1])
			tab.goto_line(int(args[2]))

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
		l = meta(l, ["goto", file_path, 0], file_path)
		bbcode.append(l)
		
		for j in len(found[file_path]):
			var result = found[file_path][j]
			var got_lines = result[0]
			var line_index = result[1]
			var char_index = result[2]
			
			if j != 0:
				bbcode.append("\t" + clr("...", Color.gray))
			
			for i in len(got_lines):
				l = ""
				
				if i == 2:
					var line:String = got_lines[i]
					var head:String = line.substr(0, char_index)
					var midd:String = line.substr(char_index, len(search_for)+1)
					var tail:String = line.substr(char_index+len(search_for)+1)
					head = clr(head, Color.tomato.lightened(.5))
					midd = clr(midd, Color.tomato.darkened(.25))
					tail = clr(tail, Color.tomato.lightened(.5))
					l = "\t" + clr(str(line_index-2+i+1) + ": ", Color.tomato.lightened(.5)) + (head+midd+tail)
				
				elif line_index-2+i >= 0:
					l = "\t" + clr(str(line_index-2+i+1) + ": ", Color.gray) + got_lines[i]
				
				if l:
					l = meta(l, ["goto", file_path, line_index])
					bbcode.append(l)
	
	set_bbcode(bbcode.join("\n"))

# get a list of files containging lines
func _search(search_for:String) -> Dictionary:
	var found = {}
	var search_for_l = search_for.to_lower() # lowercase. TODO: match case
	for path in editor.file_paths:
		var lines = TE_Util.load_text(path).split("\n")
		for line_index in len(lines):
			var line:String = lines[line_index].to_lower()
			# find index where result is found
			var char_index:int = line.find(search_for_l)
			if char_index != -1:
				if not path in found:
					found[path] = []
				var preview_lines = PoolStringArray()
				var highlight_from:int = line_index
				# show surrounding 5 lines.
				for i in range(-2, 3):
					if line_index+i >= 0 and line_index+i < len(lines):
						preview_lines.append(lines[line_index+i])
					else:
						preview_lines.append("")
				# lines, index in file, index in line
				found[path].append([preview_lines, line_index, char_index])
	return found
