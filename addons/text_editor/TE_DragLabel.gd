tool
extends RichTextLabel

var editor:TE_Editor
var click_pos:Vector2

func _init(text):
	set_bbcode(text)
	visible = false

func _ready():
	add_font_override("normal_font", editor.FONT_R)
	click_pos = get_global_mouse_position()
#	add_font_override("bold_font", editor.FONT_B)
#	add_font_override("italics_font", editor.FONT_I)
#	add_font_override("bold_italics_font", editor.FONT_BI)
	
	rect_size = editor.FONT_R.get_string_size(text)
	rect_size += Vector2(16, 16)

func _process(_delta):
	var mp = get_global_mouse_position()
	set_visible(mp.distance_to(click_pos) > 16.0)
	set_global_position(mp + Vector2(16, 8))

func _input(e):
	if e is InputEventMouseButton:
		if (e.button_index == BUTTON_LEFT and not e.pressed) or (e.button_index == BUTTON_RIGHT and e.pressed):
			queue_free()
