tool
extends TabContainer

onready var editor:TE_Editor = owner

func _ready():
	if not editor.is_plugin_active():
		return
	
	add_font_override("font", editor.FONT_R)

func _unhandled_key_input(e):
	if not editor.is_plugin_active():
		return
	
	# Ctrl + M = meta tabs
	if e.scancode == KEY_M and e.control and e.pressed:
		visible = not visible
		get_tree().set_input_as_handled()
