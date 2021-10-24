tool
extends Node2D

export(String, MULTILINE) var text:String

func _draw():
	var words = PoolStringArray()
	for word in text.split("\n"):
		word = TE_Util._sanitize_word(word)
		if word:
			words.append("\"%s\"" % word)
	print("[%s]" % words.join(","))
