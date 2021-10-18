tool
extends TE_ExtensionHelper

func apply_colors(e:TE_Editor, t:TextEdit):
	.apply_colors(e, t)
	# symbols
	t.add_color_region("[", "]", e.color_symbol, false)
	
	# string
	t.add_color_region('"', '"', e.color_var, false)
	
	# comment
	t.add_color_region(';', '', e.color_comment, true)

func get_symbols(t:String) -> Dictionary:
	var out = .get_symbols(t)
	var last = add_symbol()
	var lines = t.split("\n")
	var i = 0
	
	while i < len(lines):
		# symbols
		if lines[i].begins_with("["):
			var name = lines[i].split("[", true, 1)[1].split("]", true, 1)[0]
			last = add_symbol(i, 0, name)
		
		# tags
		elif lines[i].begins_with(";") and "#" in lines[i]:
			for t in lines[i].substr(1).split("#"):
				t = t.strip_edges()
				if t:
					last.tags.append(t)
		
		i += 1
	
	return out
