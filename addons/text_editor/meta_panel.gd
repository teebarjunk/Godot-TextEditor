extends TE_RichTextLabel

onready var editor:TextEditor = owner

func _ready():
	var _e
	_e = editor.connect("file_selected", self, "_file_selected")
	_e = editor.connect("file_saved", self, "_file_saved")

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
	tab.helper.generate_meta(tab, self)
