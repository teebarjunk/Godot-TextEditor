tool
extends TE_RichTextLabel

onready var editor:TextEditor = owner

func _ready():
	var _e
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = editor.connect("file_saved", self, "_file_saved")
	_e = connect("resized", self, "_resized")

func _resized():
	add_constant_override("table_hseparation", int(rect_size.x / 6.0))

func _unhandled_key_input(e):
	if e.scancode == KEY_M and e.pressed:
		visible = not visible

func _file_selected(_file_path:String):
	yield(get_tree(), "idle_frame")
	_redraw()
	
func _file_saved(_file_path:String):
	_redraw()

func _redraw():
	var tab = editor.get_selected_tab()
	if tab:
		tab.helper.generate_meta(tab, self)
