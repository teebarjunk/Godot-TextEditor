tool
extends LineEdit

onready var editor:TE_Editor = owner
var fr:FuncRef

func _ready():
	var _e
	_e = connect("text_entered", self, "_enter")
	_e = connect("focus_exited", self, "_lost_focus")
	
	add_font_override("font", editor.FONT_R)

func _unhandled_key_input(e):
	if not editor.is_plugin_active():
		return
	
	if visible and e.scancode == KEY_ESCAPE and e.pressed:
		fr = null
		hide()
		get_tree().set_input_as_handled()

func display(t:String, obj:Object, fname:String):
	text = t
	select_all()
	fr = funcref(obj, fname)
	show()
	call_deferred("grab_focus")

func _lost_focus():
	fr = null
	hide()

func _enter(t:String):
	if fr:
		fr.call_func(t)
	hide()
