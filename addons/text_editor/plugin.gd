tool
extends EditorPlugin

const TEPanel:PackedScene = preload("res://addons/text_editor/TextEditor.tscn")
var panel:Node

func get_plugin_name(): return "Text"
func get_plugin_icon(): return get_editor_interface().get_base_control().get_icon("Font", "EditorIcons")
func has_main_screen(): return true

func _enter_tree():
	panel = TEPanel.instance()
	panel.plugin = self
	panel.plugin_hint = true
	get_editor_interface().get_editor_viewport().add_child(panel)
	make_visible(false)

func _exit_tree():
	if panel:
		panel.queue_free()

func make_visible(visible):
	if panel:
		panel.visible = visible


