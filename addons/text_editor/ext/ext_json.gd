tool
extends TE_ExtensionHelper

func toggle_comment(t:TextEdit, head:String="/*", tail:String="*/"):
	return .toggle_comment(t, head, tail)

func get_symbols(t:String):
	var out = .get_symbols(t)
	var last = add_symbol()
	var lines = t.split("\n")
	var i = 0
	
	while i < len(lines):
		# symbols
		if "\": {" in lines[i]:
			var key = lines[i].split("\": {", true, 1)[0].rsplit("\"", true, 0)[1]
			var deep = max(0, len(lines[i]) - len(lines[i].strip_edges(true, false)) - 1)
			last = add_symbol(i, deep, key)
		
		elif '"#": "' in lines[i]:
			for tag in lines[i].split('"#": "', true, 1)[1].split('"', true, 1)[0].split("#"):
				tag = tag.strip_edges()
				if tag:
					last.tags.append(tag)
		
		elif '"tags": "' in lines[i]:
			for tag in lines[i].split('"tags": "', true, 1)[1].split('"', true, 1)[0].split("#"):
				tag = tag.strip_edges()
				if tag:
					last.tags.append(tag)
		
		i += 1
	
	return out

func apply_colors(e:TE_Editor, t:TextEdit):
	.apply_colors(e, t)
	
	# vars
	t.add_color_region(' "', '"', e.color_varname)
	t.add_color_region('"', '"', e.color_varname)
	t.add_keyword_color("true", e.color_var)
	t.add_keyword_color("false", e.color_var)
	t.add_keyword_color("null", e.color_var)
	
	# comments
#	t.add_color_region("/*", "*/", e.color_comment)
	t.add_color_region('\t"#"', ",", e.color_comment, false)
