tool
extends TE_ExtensionHelper

func get_tab() -> String:
	return "  "

func _is_commented(lines) -> bool:
	for i in len(lines):
		if not lines[i].strip_edges():
			continue
		if not lines[i].strip_edges(true, false).begins_with("# "):
			return false
	return true

func toggle_comment(t:TextEdit, head:String="", tail:String=""):
	if not t.is_selection_active():
		var l = t.cursor_get_line()
		var lt = t.get_line(l)
		var s = len(lt) - len(lt.strip_edges(true, false))
		t.select(l, s, l, len(t.get_line(l)))
	
	var l1 = t.get_selection_from_line()
	var c1 = t.get_selection_from_column()
	var old = t.get_selection_text()
	var new = old.split("\n")
	
	if _is_commented(new):
		for i in len(new):
			if "# " in new[i]:
				var p = new[i].split("# ", true, 1)
				new[i] = p[0] + p[1]
	else:
		for i in len(new):
			if not new[i].strip_edges():
				continue
			var space = TE_Util.get_whitespace_head(new[i])
			new[i] = space + "# " + new[i].strip_edges(true, false)
	
	new = new.join("\n")
	
	t.insert_text_at_cursor(new)
	var l = new.split("\n")
	var l2 = l1 + len(l)-1
	var c2 = c1 + len(l[-1])
	t.select(l1, c1, l2, c2)
	
	return [old, new]

func apply_colors(e:TE_Editor, t:TextEdit):
	.apply_colors(e, t)
	
	# strings
	t.add_color_region('"', '"', e.color_var)
	# bools
	t.add_keyword_color("true", e.color_var)
	t.add_keyword_color("false", e.color_var)
	
	# null
	t.add_keyword_color("~", e.color_var)
	
	# array element
	t.add_color_region("- ", "", e.color_text.darkened(.25), true)
	
	# comments
	t.add_color_region("#", "", e.color_comment, true)


func get_symbols(t:String) -> Dictionary:
	var out = .get_symbols(t)
	var last = add_symbol()
	var lines = t.split("\n")
	var i = 0
	
	while i < len(lines):
		# find objects to use as symbols
		if ":" in lines[i]:
			var p = lines[i].split(":", true, 1)
			var r = p[1].strip_edges()
			if not r or r.begins_with("{") or r.begins_with("#"):
				var name = p[0].strip_edges()
				var deep = max(0, len(lines[i]) - len(lines[i].strip_edges(true, false)))
				last = add_symbol(i, deep, name)
		
		# find tags inside comments
		if "# " in lines[i]:
			var p = lines[i].split("# ", true, 1)
			if p[0].count("\"") % 2 != 0:
				pass
			
			elif "#" in p[1]:
				for tag in p[1].split("#", true, 1)[1].split("#"):
					tag = tag.strip_edges()
					if tag:
						last.tags.append(tag)
		
		elif '"#": "' in lines[i]:
			for tag in lines[i].splti('"#": "', true, 1)[1].split('"', true, 1)[0].split("#"):
				tag = tag.strip_edges()
				if tag:
					last.tags.append(tag)
		
		i += 1
	
	return out
