tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

var hscrolls:Dictionary = {}

func _ready():
	var _e
	_e = editor.connect("symbols_updated", self, "_redraw")
	_e = editor.connect("tags_updated", self, "_redraw")
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = get_v_scroll().connect("value_changed", self, "_scrolling")
	
	add_font_override("normal_font", editor.FONT_R)
	add_font_override("bold_font", editor.FONT_B)
	add_font_override("italics_font", editor.FONT_I)
	add_font_override("bold_italics_font", editor.FONT_BI)
	
	call_deferred("_redraw")

func _file_selected(file_path:String):
	yield(get_tree(), "idle_frame")
	get_v_scroll().value = hscrolls.get(file_path, 0)

func _scrolling(v):
	hscrolls[editor.get_selected_file()] = get_v_scroll().value

func _clicked(args:Array):
	var te:TextEdit = editor.get_selected_tab()
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
		
		for line_index in symbols:
			if line_index == -1:
				continue # special file chapter
			var symbol_info = symbols[line_index]
			var deep = symbol_info.deep
			var space = "" if not deep else clr("-".repeat(deep), Color.white.darkened(.75))
			var cl = Color.white
			
			if deep == 0:
				cl = editor.color_symbol
				if symbol_info.name.begins_with("*") and symbol_info.name.ends_with("*"):
					cl = TE_Util.hue_shift(cl, -.33)
				elif symbol_info.name.begins_with('"') and symbol_info.name.ends_with('"'):
					cl = TE_Util.hue_shift(cl, .33)
			
			if not editor.is_tagged_or_visible(symbol_info.tags):
				cl = cl.darkened(.7)
			
			elif deep >= 1:
				cl = cl.darkened(.33 * (deep-1))
			
			var tags = "" if not symbol_info.tags else PoolStringArray(symbol_info.tags).join(", ")
			t.append(clr(meta(space + symbol_info.name, [symbol_info, line_index], tags), cl))
		
		set_bbcode(t.join("\n"))
