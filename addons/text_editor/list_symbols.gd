extends RichTextLabel

onready var editor:TextEditor = owner

func _ready():
	var _e
	_e = connect("meta_hover_started", self, "_hovered")
	_e = connect("meta_clicked", self, "_clicked")
	_e = editor.connect("symbols_updated", self, "_redraw")
	_e = editor.connect("tags_updated", self, "_redraw")
	
	add_font_override("normal_font", editor.FONT_R)
	add_font_override("bold_font", editor.FONT_B)
	add_font_override("italics_font", editor.FONT_I)
	add_font_override("bold_italics_font", editor.FONT_BI)

func _hovered(_id):
	pass

func _clicked(id):
	var p = id.split(":", true, 1)
	var i = int(p[1])
	match p[0]:
		"l":
			var te:TextEdit = editor.get_selected_tab()
			te.cursor_set_line(te.get_line_count()) # force scroll to bottom so selected line will be at top
			te.cursor_set_line(i)

func _redraw():
	var tab = editor.get_selected_tab()
	var symbols = {} if not tab else tab.symbols
	
	# no symbols
	if not symbols or len(symbols) == 1:
		set_bbcode("[color=#%s][i][center]*No symbols*" % [Color.webgray.to_html()])
	
	else:
		var t = PoolStringArray()
		
		for line_index in symbols:
			if line_index == -1:
				continue # special file chapter
			var symbol_info = symbols[line_index]
			var space = "" if not symbol_info.deep else "  ".repeat(symbol_info.deep)
			var tagged = editor.is_tagged_or_visible(symbol_info.tags)
			var clr = Color.white.darkened(0.0 if tagged else 0.75).to_html()
			t.append(space + "[color=#%s][url=l:%s]%s[/url][/color]" % [clr, line_index, symbol_info.name])
		
		set_bbcode(t.join("\n"))
