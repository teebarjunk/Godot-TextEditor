tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

func _ready():
	var _e
	_e = editor.connect("symbols_updated", self, "_redraw")
	_e = editor.connect("tags_updated", self, "_redraw")
	
	add_font_override("normal_font", editor.FONT_R)
	add_font_override("bold_font", editor.FONT_B)
	add_font_override("italics_font", editor.FONT_I)
	add_font_override("bold_italics_font", editor.FONT_BI)
	
	call_deferred("_redraw")

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
			var cl = Color.deepskyblue if deep == 0 else Color.white
			
			if not editor.is_tagged_or_visible(symbol_info.tags):
				cl = cl.darkened(.7)
			
			elif deep >= 1:
				cl = cl.darkened(.33 * (deep-1))
			
			var tags = "" if not symbol_info.tags else PoolStringArray(symbol_info.tags).join(", ")
			t.append(clr(meta(space + symbol_info.name, [symbol_info, line_index], tags), cl))
		
		set_bbcode(t.join("\n"))
