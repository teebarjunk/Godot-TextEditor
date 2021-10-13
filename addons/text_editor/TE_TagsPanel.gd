tool
extends RichTextLabel

onready var editor:TextEditor = owner

var tag_indices:Array = [] # safer to use int in [url=] than str.

func _ready():
	var _e
	_e = connect("meta_hover_started", self, "_hovered")
	_e = connect("meta_hover_ended", self, "_unhover")
	_e = connect("meta_clicked", self, "_clicked")
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

func _hovered(index):
	var tag = tag_indices[int(index)]
	var count = editor.tag_counts[tag]
	hint_tooltip = "%s x%s" % [tag, count]

func _unhover(t):
	hint_tooltip = ""

func _clicked(id):
	var tag = tag_indices[int(id)]
	editor.enable_tag(tag, not editor.is_tag_enabled(tag))

func sort_tags(tags:Dictionary):
	var sorter:Array = []
	for tag in tags:
		sorter.append([tag, tags[tag]])
	
	sorter.sort_custom(self, "_sort_tags")
	
	tags.clear()
	for item in sorter:
		tags[item[0]] = item[1]
	return tags

func _sort_tags(a, b):
	return a[0] < b[0]

func _redraw():
	var tab = editor.get_selected_tab()
	var tags = editor.tag_counts
	var tab_tags = {} if not tab else tab.tags
	
	sort_tags(tags)
	
	if not tags:
		set_bbcode("[color=#%s][i][center]*No tags*" % [Color.webgray.to_html()])
		
	else:
		var t:PoolStringArray = PoolStringArray()
		var count_color1 = Color.tomato.to_html()
		var count_color2 = Color.tomato.darkened(.75).to_html()
		for tag in tags:
			var count = editor.tag_counts[tag]
			var enabled = editor.is_tag_enabled(tag)
			
			var x = tag
#			if count > 1:
#				x = "[color=#%s][i]%s[/i][/color]%s" % [count_color1 if enabled else count_color2, count, tag]
#			else:
#				x = tag
			
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
