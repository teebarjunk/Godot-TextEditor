tool
extends TabContainer

onready var editor:TE_Editor = owner

func _ready():
	if not editor.is_plugin_active():
		return
	
	set_visible(false)
	add_font_override("font", editor.FONT_R)

func _unhandled_key_input(e):
	if not editor.is_plugin_active():
		return
	
	if e.control and e.pressed:
		match e.scancode:
			# show this menu
			KEY_M:
				set_visible(not get_parent().visible)
				get_tree().set_input_as_handled()
			
			# find menu
			KEY_F:
				set_visible(true)
				select_tab($search)
				$search/rte.select()

func set_visible(v:bool):
	get_parent().visible = v

func select_tab(tab:Node):
	current_tab = tab.get_index()

func show_image(file_path:String):
	get_parent().visible = true
	select_tab($image)
	$image/image.texture = TE_Util.load_image(file_path)
