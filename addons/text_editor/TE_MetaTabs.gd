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
		get_parent().visible = not get_parent().visible
		get_tree().set_input_as_handled()

func show_image(file_path:String):
	get_parent().visible = true
	current_tab = $image.get_index()
	$image/image.texture = TE_Util.load_image(file_path)
