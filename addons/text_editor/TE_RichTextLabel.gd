extends RichTextLabel
class_name TE_RichTextLabel


func _ready():
	add_font_override("normal_font", owner.FONT_R)
	add_font_override("bold_font", owner.FONT_B)
	add_font_override("italics_font", owner.FONT_I)
	add_font_override("bold_italics_font", owner.FONT_BI)

func table(rows) -> String:
	var cells = ""
	var clr = Color.white.darkened(.5).to_html()
	for i in len(rows):
		if i == 0:
			for item in rows[i]:
				cells += "[cell][b]%s[/b][/cell][/color]" % item
		else:
			for item in rows[i]:
				cells += "[cell][color=#%s]%s[/color][/cell]" % [clr, item]
	return "[center][table=%s]%s[/table][/center]" % [len(rows[0]), cells]
