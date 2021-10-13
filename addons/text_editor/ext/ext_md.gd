tool
extends TE_ExtensionHelper

func toggle_comment(t:TextEdit, head:String="<!-- ", tail:String=" -->"):
	return .toggle_comment(t, head, tail)

func apply_colors(e:TextEditor, t:TextEdit):
	.apply_colors(e, t)
	
	var code:Color = lerp(e.color_text.darkened(.5), Color.yellowgreen, .5)
	
	t.add_keyword_color("true", e.color_var)
	t.add_keyword_color("false", e.color_var)
	
	# bold italic
	t.add_color_region("***", "***", Color.tomato.darkened(.3), false)
	# bold
	t.add_color_region("**", "**", Color.tomato, false)
	# italic
	t.add_color_region("*", "*", Color.tomato.lightened(.3), false)
	
	# quote
	t.add_color_region("> ", "", Color.white.darkened(.6), true)
	
	# comment
	t.add_color_region("<!--", "-->", e.color_comment, false)
	
	# headings
	var head = e.color_symbol
	t.add_color_region("# *", "*", head.darkened(.5), true)
	t.add_color_region("# \"", "\"", head.lightened(.5), true)
	t.add_color_region("# ", "", head, true)
	t.add_color_region("## ", "", head, true)
	t.add_color_region("### ", "", head, true)
	t.add_color_region("#### ", "", head, true)
	t.add_color_region("##### ", "", head, true)
	t.add_color_region("###### ", "", head, true)
	
	# url links
	t.add_color_region("[", ")", e.color_var.lightened(.5))
	
	# lists
	t.add_color_region("- [x", "]", Color.yellowgreen, false)
	t.add_color_region("- [", " ]", e.color_text.darkened(.6), false)
	
	# code blocks
	t.add_color_region("```", "```", code, false)
	t.add_color_region("~~~", "~~~", code, false)
	
	# strikeout
	t.add_color_region("~~", "~~", Color.tomato, false)
	
	# code
	t.add_color_region("`", "`", code, false)
	
	# at/mention
	t.add_color_region("@", " ", Color.yellowgreen, false)
	
#	t.add_color_region(": ", "", e.color_text.lightened(.4), true)
	
	# tables
	t.add_color_region("|", "", Color.tan, true)


func get_symbols(t:String) -> Dictionary:
	var out = .get_symbols(t)
	var last = add_symbol()
	var lines = t.split("\n")
	var i = 0
	
	while i < len(lines):
		# symbols
		if lines[i].begins_with("#"):
			var p = lines[i].split(" ", true, 1)
			var deep = len(p[0])-1
			var name = p[1].strip_edges()
			last = add_symbol(i, deep, name)
		
		# tags
		elif "<!-- #" in lines[i]:
			for tag in lines[i].split("<!-- #", true, 1)[1].split("-->", true, 1)[0].split("#"):
				tag = tag.strip_edges()
				if tag:
					last.tags.append(tag)
		
		i += 1
	
	return out
