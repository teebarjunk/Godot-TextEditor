tool
extends TE_ExtensionHelper

func generate_meta(t:TextEdit, r:RichTextLabel):
	.generate_meta(t, r)
	
	var i = 0
	var meta = {}
	var words = {}
	var word_count = 0
	var chaps = [{i=0, id="???", words={}, word_count=0 }]
	while i < t.get_line_count():
		var line = t.get_line(i)
		
		# get meta
		if i == 0 and line.begins_with("---"):
			i += 1
			while i < t.get_line_count() and not t.get_line(i).begins_with("---"):
				if ":" in t.get_line(i):
					var p = t.get_line(i).split(":", true, 1)
					var k = p[0].strip_edges()
					var v = p[1].strip_edges()
					meta[k] = v
					if k == "name":
						chaps[-1].id = v
				i += 1
		
		# ignore comments
		elif "<!--" in line:
			pass
		
		# ignore tables
		elif "|" in line:
			pass
		
		# ignore code
		elif line.begins_with("```") or line.begins_with("~~~"):
			var head = line.substr(0, 3)
			i += 1
			while i < t.get_line_count() and not t.get_line(i).begins_with(head):
				i += 1
		
		# get chapter info
		elif line.begins_with("#"):
			var id = line.split(" ", true, 1)[1].strip_edges()
			chaps.append({i=i, id=id, words={}, word_count=0 })
			
		else:
			var last = chaps[-1]
			last.word_count += TE_Util.count_words(line, last.words)
		
		i += 1
	
	# total words
	for chap in chaps:
		word_count += chap.word_count
		for word in chap.words:
			if not word in words:
				words[word] = chap.words[word]
			else:
				words[word] += chap.words[word]
		
		# sort
		TE_Util.sort_vals(chap.words)
	
	r.push_align(RichTextLabel.ALIGN_CENTER)
	r.push_table(4)
	for x in ["#", "id", "word %s" % word_count, "words"]:
		r.push_cell()
		r.push_bold()
		r.add_text(x)
		r.pop()
		r.pop()
	
	var index:int = 0
	for chap in chaps:
		
		if chap.id == "???" and not chap.word_count:
			continue
		
		index += 1
		
		
		
		r.push_cell()
		r.push_color(Color.webgray)
		r.add_text(str(index))
		r.pop()
		r.pop()
		
		r.push_cell()
		r.push_color(Color.webgray)
		r.add_text(chap.id)
		r.pop()
		r.pop()
		
		var div = 0 if not chap.word_count or not word_count else chap.word_count / float(word_count)
		div *= 100.0
		div = "%" + str(stepify(div, .1))
		r.push_cell()
		r.push_color(Color.webgray)
		r.add_text(str(chap.word_count))
		r.pop()
		r.push_color(Color.gray)
		r.add_text(" %s" % div)
		r.pop()
		r.pop()
		
		r.push_cell()
		r.push_color(Color.webgray)
		r.add_text(PoolStringArray(chap.words.keys()).join(" "))
		r.pop()
		r.pop()
		
	r.pop()
	r.pop()

func _sort(a, b):
	return a[1] > b[1]

func toggle_comment(t:TextEdit, head:String="<!-- ", tail:String=" -->"):
	return .toggle_comment(t, head, tail)

func apply_colors(e:TE_Editor, t:TextEdit):
	.apply_colors(e, t)
	
	var code:Color = lerp(Color.white.darkened(.5), Color.deepskyblue, .333)
	var quote:Color = lerp(e.color_text, e.color_symbol, .5)
	
	t.add_color_override("function_color", e.color_text)
	t.add_color_override("number_color", e.color_text)
	
#	t.add_keyword_color("true", e.color_var)
#	t.add_keyword_color("false", e.color_var)
	
	# bold italic
	t.add_color_region("***", "***", Color.tomato.darkened(.3), false)
	# bold
	t.add_color_region("**", "**", Color.tomato, false)
	# italic
	t.add_color_region("*", "*", Color.tomato.lightened(.3), false)
	
	# quote
	t.add_color_region("> ", "", quote, true)
	
	# comment
	t.add_color_region("<!--", "-->", e.color_comment, false)
	
	# non official markdown:
	# formatted
	t.add_color_region("{", "}", lerp(e.color_text, e.color_var, .5).darkened(.25), false)
#	t.add_color_region("[", "]", lerp(e.color_text, e.color_var, .5).darkened(.25), false)
#	t.add_color_region("(", ")", lerp(e.color_text, e.color_var, .5).darkened(.25), false)
	if false:
		# quote
		t.add_color_region('"', '"', quote, false)
		# brackets
		t.add_color_region('(', ')', quote, false)
	else:
		# url links
		t.add_color_region("![", ")", e.color_var.lightened(.5))
	
	# headings
	for i in range(1, 7):
		var h = "#".repeat(i)
		t.add_color_region("%s *" % h, "*", e.get_symbol_color(i-1, -.33), true)
		t.add_color_region("%s \"" % h, "\"", e.get_symbol_color(i-1, .33), true)
		t.add_color_region("%s " % h, "*", e.get_symbol_color(i-1), true)
	
	# lists
	t.add_color_region("- [x", "]", Color.yellowgreen, false)
	t.add_color_region("- [", " ]", e.color_text.darkened(.6), false)
	
	# code blocks
	t.add_color_region("```", "```", code, false)
	t.add_color_region("~~~", "~~~", code, false)
	t.add_color_region("---", "---", code, false)
	
	# strikeout
	t.add_color_region("~~", "~~", Color.tomato, false)
	
	# code
	t.add_color_region("`", "`", code, false)
	
	# at/mention
	t.add_color_region("@", " ", Color.yellowgreen, false)
	
	# tables
	t.add_color_region("|", "", Color.tan, true)

func get_symbols(t:String) -> Dictionary:
	var out = .get_symbols(t)
	var last = add_symbol()
	var lines = t.split("\n")
	var i = 0
	
	while i < len(lines):
		# initial meta data
		if i == 0 and lines[i].begins_with("---"):
			i += 1
			while i < len(lines) and not lines[i].begins_with("---"):
				if "tags: " in lines[i]:
					for tag in lines[i].split("tags: ", true, 1)[1].split("#"):
						tag = tag.strip_edges()
						if tag:
							last.tags.append(tag)
				
#				elif "name: " in lines[i]:
#					last.name = lines[i].split("name: ", true, 1)[1]
				
				i += 1
#			i += 1
		
		elif lines[i].begins_with("```") or lines[i].begins_with("~~~"):
			var head = lines[i].substr(0, 3)
			i += 1
			while i < len(lines) and not lines[i].begins_with(head):
				i += 1
		
		# symbols
		elif lines[i].begins_with("#"):
			var p = lines[i].split(" ", true, 1)
			var deep = len(p[0])-1
			var name = "???" if len(p) == 1 else p[1].strip_edges()
			last = add_symbol(i, deep, name)
		
		# tags
		elif "<!-- #" in lines[i]:
			for tag in lines[i].split("<!-- #", true, 1)[1].split("-->", true, 1)[0].split("#"):
				tag = tag.strip_edges()
				if tag:
					last.tags.append(tag)
		
		i += 1
	
	return out
