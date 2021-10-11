tool
extends RichTextLabel

var editor:TextEditor

func _ready():
	add_font_override("normal_font", editor.FONT_R)
	add_font_override("bold_font", editor.FONT_B)
	add_font_override("italics_font", editor.FONT_I)
	add_font_override("bold_italics_font", editor.FONT_BI)

func _process(_delta):
	set_global_position(get_global_mouse_position())

func _input(e):
	if e is InputEventMouseButton:
		if (e.button_index == BUTTON_LEFT and not e.pressed) or (e.button_index == BUTTON_RIGHT and e.pressed):
			queue_free()
