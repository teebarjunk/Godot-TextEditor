tool
extends TE_ExtensionHelper

func get_tab() -> String:
	return "    "

func apply_colors(e:TE_Editor, t:TextEdit):
	.apply_colors(e, t)
	
	for k in "label menu define default scene show with play return jump call".split(" "):
		t.add_keyword_color(k, e.color_symbol)
	
	# strings
	t.add_color_region('"', '"', e.color_var)
	# bools
	t.add_keyword_color("True", e.color_var)
	t.add_keyword_color("False", e.color_var)
	
	# comments
	t.add_color_region("#", "", e.color_comment, true)
	t.add_color_region("$ ", "", e.color_comment, true)

func get_symbols(t:String):
	var out = .get_symbols(t)
	var last = add_symbol()
	var lines = t.split("\n")
	var i = 0
	
	while i < len(lines):
		# symbols
		if lines[i].begins_with("label "):
			var key = lines[i].substr(len("label ")).strip_edges()
			key = key.substr(0, len(key)-1)
			last = add_symbol(i, 0, key)
			
		elif lines[i].begins_with("menu "):
			var key = lines[i].substr(len("menu ")).strip_edges()
			key = key.substr(0, len(key)-1)
			last = add_symbol(i, 0, key)
		
		# tags
		elif "#" in lines[i]:
			var p = lines[i].rsplit("#", true, 1)[1]
			if "#" in p:
				for tag in p.split("#"):
					last.tags.append(tag)
		
		i += 1
	
	return out
