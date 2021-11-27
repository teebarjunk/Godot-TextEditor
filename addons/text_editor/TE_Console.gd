tool
extends "res://addons/text_editor/TE_RichTextLabel.gd"

func _ready():
	clear()

func msg(msg):
	append_bbcode(str(msg))
	newline()

func err(err):
	append_bbcode(clr(err, Color.tomato))
	newline()

func info(info):
	append_bbcode(clr(info, Color.aquamarine))
	newline()
