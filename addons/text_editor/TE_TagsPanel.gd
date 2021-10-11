tool
extends RichTextLabel

onready var editor:TextEditor = owner

var tag_indices:Array = [] # safer to use int in [url=] than str.

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
	
	call_deferred("_redraw")

func _hovered(_id):
	pass

func _clicked(id):
	var tag = tag_indices[int(id)]
	editor.enable_tag(tag, not editor.is_tag_enabled(tag))

func _redraw():
	var tab = editor.get_selected_tab()
	var tags = editor.tag_counts
	var tab_tags = {} if not tab else tab.tags
	
	TE_Util.sort_value(tags)
	
	if not tags:
		set_bbcode("[color=#%s][i][center]*No tags*" % [Color.webgray.to_html()])
		
	else:
		var t:PoolStringArray = PoolStringArray()
		var count_color1 = Color.tomato.to_html()
		var count_color2 = Color.tomato.darkened(.75).to_html()
		for tag in tags:
			var count = editor.tag_counts[tag]
			var enabled = editor.is_tag_enabled(tag)
			
			var x
			if count > 1:
				x = "[color=#%s][i]%s[/i][/color]%s" % [count_color1 if enabled else count_color2, count, tag]
			else:
				x = tag
			
			var color = editor.color_text
			var dim = 0.75
			
			if tag in tab_tags:
				color = editor.color_symbol
				x = "[b]%s[/b]" % x
				dim = 0.6
				
			if enabled:
				x = x
			else:
				x = "[color=#%s]%s[/color]" % [color.darkened(dim).to_html(), x]
			
			x = "[url=%s]%s[/url]" % [len(tag_indices), x]
			t.append(x)
			tag_indices.append(tag)
		
		set_bbcode("[center]" + t.join(" "))
