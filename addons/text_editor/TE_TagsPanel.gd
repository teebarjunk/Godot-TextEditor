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
	
	# hint
	theme = Theme.new()
	theme.set_font("font", "TooltipLabel", editor.FONT_R)
	
	call_deferred("_redraw")

func _clicked(args:Array):
	var tag = args[0]
	var was_enabled = editor.is_tag_enabled(tag)
	
	if not Input.is_key_pressed(KEY_CONTROL):
		editor.tags_enabled.clear()
	
	editor.enable_tag(tag, not was_enabled)

#func sort_tags(tags:Dictionary):
#	var sorter:Array = []
#	for tag in tags:
#		sorter.append([tag, tags[tag]])
#
#	sorter.sort_custom(self, "_sort_tags")
#
#	tags.clear()
#	for item in sorter:
#		tags[item[0]] = item[1]
#	return tags
#
#func _sort_tags(a, b):
#	return a[0] < b[0]

func _redraw():
	var tab = editor.get_selected_tab()
	var tags = editor.tags
	var tab_tags = {} if not tab else tab.tags
	
#	sort_tags(tags)
	
	if not tags:
		set_bbcode("[color=#%s][i][center]*No tags*" % [Color.webgray.to_html()])
		
	else:
		var t:PoolStringArray = PoolStringArray()
		var count_color1 = Color.tomato.to_html()
		var count_color2 = Color.tomato.darkened(.75).to_html()
		for tag in tags:
			var count = editor.tags[tag]
			var enabled = editor.is_tag_enabled(tag)
			
			var x = tag
			var color = editor.color_text
			var dim = 0.75
			
			if tag in tab_tags:
				color = editor.color_tag
				x = b(x)
				dim = 0.6
				
			if enabled:
				x = x
			else:
				x = clr(x, color.darkened(dim))
			
			t.append(meta(x, [tag], "%s x%s" % [tag, count] ))
		
		set_bbcode("[center]" + t.join(" "))
