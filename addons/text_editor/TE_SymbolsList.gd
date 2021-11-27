tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

var hscrolls:Dictionary = {}
var selected_line:int = 0
var current_file:String = ""

var filter:String = ""
export var p_filter:NodePath

func _ready():
	var _e
	_e = editor.connect("symbols_updated", self, "_redraw")
	_e = editor.connect("tags_updated", self, "_redraw")
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = editor.connect("file_closed", self, "_file_closed")
	_e = editor.connect("file_renamed", self, "_file_renamed")
	_e = editor.connect("selected_symbol_line", self, "_selected_symbol_line")
	_e = get_v_scroll().connect("value_changed", self, "_scrolling")
	
	var le:LineEdit = get_node(p_filter)
	_e = le.connect("text_changed", self, "_filter_changed")
	le.add_font_override("font", editor.FONT_R)
	
	add_font_override("normal_font", editor.FONT_R)
	add_font_override("bold_font", editor.FONT_B)
	add_font_override("italics_font", editor.FONT_I)
	add_font_override("bold_italics_font", editor.FONT_BI)
	
	call_deferred("_redraw")

func _filter_changed(t:String):
	filter = t.to_lower()
	_redraw()

func _selected_symbol_line(line:int):
	selected_line = clamp(line, 0, get_line_count())
	scroll_to_line(clamp(line-1, 0, get_line_count()-1))
	_redraw()

func _file_selected(file_path:String):
	current_file = file_path
	yield(get_tree(), "idle_frame")
	get_v_scroll().value = hscrolls.get(file_path, 0)

func _file_renamed(old:String, new:String):
	current_file = new
	yield(get_tree(), "idle_frame")
	_redraw()

func _file_closed(file_path:String):
	if file_path == current_file:
		current_file = ""
		_redraw()

func _scrolling(v):
	hscrolls[editor.get_selected_file()] = get_v_scroll().value

func _clicked(args:Array):
	var te:TextEdit = editor.get_selected_tab()
	
	# select entire symbol block?
	if Input.is_key_pressed(KEY_CONTROL):
		var tab = editor.get_selected_tab()
		var symbols = {} if not tab else tab.symbols
		var line_index:int = args[1]
		var symbol_index:int = symbols.keys().find(line_index)
		var next_line:int
		
		# select sub symbol blocks?
		if not Input.is_key_pressed(KEY_SHIFT):
			var deep = symbols[line_index].deep
			
			while symbol_index < len(symbols)-1 and symbols.values()[symbol_index+1].deep > deep:
				symbol_index += 1
		
		if symbol_index == len(symbols)-1:
			next_line = tab.get_line_count()-1
		
		else:
			next_line = symbols.keys()[symbol_index+1]-1
		
		tab.select(line_index, 0, next_line, len(tab.get_line(next_line)))
		te.goto_line(line_index)
	
	else:
		te.goto_line(args[1])

func _redraw():
	var tab = editor.get_selected_tab()
	var symbols = {} if not tab else tab.symbols
	var spaces = PoolStringArray([
		"- ",
		"  - ",
		"    - "
	])
	var colors = PoolColorArray([
		Color.white,
		Color.white.darkened(.25),
		Color.white.darkened(.5)
	])
	
	# no symbols
	if not symbols or len(symbols) == 1:
		set_bbcode("[color=#%s][i][center]*No symbols*" % [Color.webgray.to_html()])
	
	else:
		var t = PoolStringArray()
		var i = -1
		for line_index in symbols:
			i += 1
			if line_index == -1:
				continue # special file chapter
			
			var symbol_info = symbols[line_index]
			var deep = symbol_info.deep
			var space = "" if not deep else clr("-".repeat(deep), Color.white.darkened(.75))
			var cl = Color.white
			
			if filter and not filter in symbol_info.name.to_lower():
				continue
			
			if symbol_info.name.begins_with("*") and symbol_info.name.ends_with("*"):
				cl = editor.get_symbol_color(deep, -.33)
			
			elif symbol_info.name.begins_with('"') and symbol_info.name.ends_with('"'):
				cl = editor.get_symbol_color(deep, .33)
			
			else:
				cl = editor.get_symbol_color(deep)
			
			if not editor.is_tagged_or_visible(symbol_info.tags):
				cl = cl.darkened(.7)
			
			var tags = "" if not symbol_info.tags else PoolStringArray(symbol_info.tags).join(", ")
			var text = clr(meta(space + symbol_info.name, [symbol_info, line_index], tags), cl)
			if i == selected_line:
				text = b(u(text))
			
			t.append(text)
		
		set_bbcode(t.join("\n"))
