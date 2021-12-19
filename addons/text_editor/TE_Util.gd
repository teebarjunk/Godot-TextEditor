class_name TE_Util

class Sorter:
	var d:Dictionary
	var a:Array = []
	
	func _init(dict:Dictionary):
		d = dict
		for k in d:
			a.append([k, d[k]])
	
	func on_keys(reverse:bool=false):
		a.sort_custom(self, "_sort_keys_rev" if reverse else "_sort_keys")
		return _out()
	
	func on_vals(reverse:bool=false):
		a.sort_custom(self, "_sort_vals_rev" if reverse else "_sort_vals")
		return _out()
		
	func _sort_keys(a, b): return a[0] > b[0]
	func _sort_keys_rev(a, b): return a[0] < b[0]
	func _sort_vals(a, b): return a[1] > b[1]
	func _sort_vals_rev(a, b): return a[1] < b[1]
	
	func _out() -> Dictionary:
		d.clear()
		for item in a:
			d[item[0]] = item[1]
		return d

static func sort_keys(d:Dictionary, reverse:bool=false): return Sorter.new(d).on_keys(reverse)
static func sort_vals(d:Dictionary, reverse:bool=false): return Sorter.new(d).on_vals(reverse)

static func count_words(text:String, counter:Dictionary, skip_words=null, stop_words:bool=true):
	var word_count:int = 0
	for sentence in text.split("."):
		for word in sentence.split(" "):
			word = _sanitize_word(word)
			if not word: continue
			if stop_words and word in TE_StopWords.STOP_WORDS: continue
			if skip_words and word in skip_words: continue
			
			word_count += 1
			
			if not word in counter:
				counter[word] = 1
			else:
				counter[word] += 1
	
	return word_count

static func _sanitize_word(word:String):
	var out = ""
	var has_letter = false
	
	for c in word.to_lower():
		if c in "abcdefghijklmnopqrstuvwxyz":
			out += c
			has_letter = true
		
		elif c in "-'0123456789":
			out += c
	
	if not has_letter:
		return ""
	
	if out.ends_with("'s"):
		return out.substr(0, len(out)-2)
	
	return out

static func to_var(s:String) -> String:
	return s.to_lower().replace(" ", "_")

static func load_text(path:String) -> String:
	var f:File = File.new()
	if f.file_exists(path):
		var err = f.open(path, File.READ)
		var out = f.get_as_text()
		f.close()
		return out
	push_error("no file at \"%s\"" % path)
	return ""

static func load_json(path:String, loud:bool=false) -> Dictionary:
	var f:File = File.new()
	if f.file_exists(path):
		f.open(path, File.READ)
		var out = JSON.parse(f.get_as_text()).result
		f.close()
		return out
	if loud:
		push_error("no json at \"%s\"" % path)
	return {}

static func load_image(path:String) -> ImageTexture:
	var f:File = File.new()
	if f.file_exists(path):
		var image:Image = Image.new()
		image.load(path)
		var texture:ImageTexture = ImageTexture.new()
		texture.create_from_image(image)
		return texture
	return null

static func save_json(path:String, data:Dictionary):
	var f:File = File.new()
	f.open(path, File.WRITE)
	f.store_string(JSON.print(data, "\t"))
	f.close()

static func is_wrapped(t:String, head:String, tail:String) -> bool:
	t = t.strip_edges()
	return t.begins_with(head) and t.ends_with(tail)

static func unwrap(t:String, head:String, tail:String, keep_white:bool=false) -> String:
	var stripped = t.strip_edges()
	stripped = stripped.substr(len(head), len(stripped)-len(head)-len(tail))
	if keep_white:
		var whead = get_whitespace_head(t)
		var wtail = get_whitespace_tail(t)
		return whead + stripped + wtail
	else:
		return t.substr(len(head), len(t)-len(head)-len(tail))

static func wrap(t:String, head:String, tail:String, keep_white:bool=false) -> String:
	if keep_white:
		var whead = get_whitespace_head(t)
		var wtail = get_whitespace_tail(t)
		return whead + head + t.strip_edges() + tail + wtail
	else:
		return head + t + tail

static func get_whitespace_head(t:String):
	var length = len(t) - len(t.strip_edges(true, false))
	return t.substr(0, length)

static func get_whitespace_tail(t:String):
	var length = len(t) - len(t.strip_edges(false, true))
	return t.substr(len(t)-length)

const _dig = {depth=0}

static func get_dig_depth() -> int:
	return _dig.depth

static func dig_for(d, property:String, value):
	var depth:int = 0
	if d is Dictionary:
		return _dig_for_dict(d, property, value, depth)
#	elif d is Node:
#		return _dig_for_node(d, propert, value, depth)
	return null

static func _dig_for_dict(d:Dictionary, property:String, value, depth:int):
	_dig.depth = depth
	if property in d and d[property] == value:
		return d
	for k in d:
		if d[k] is Dictionary:
			var got = _dig_for_dict(d[k], property, value, depth+1)
			if got != null:
				return got
	return null
#static func _dig_for_node(d:Node, f:FuncRef, depth:int):
#	_dig.depth = depth
#	f.call_func(d)
#	for i in d.get_child_count():
#		_dig_node(d.get_child(i), f, depth+1)

static func dig(d, obj:Object, fname:String):
	var f:FuncRef = funcref(obj, fname)
	var depth:int = 0
	if d is Dictionary:
		_dig_dict(d, f, depth)
	elif d is Node:
		_dig_node(d, f, depth)

static func _dig_dict(d:Dictionary, f:FuncRef, depth:int):
	_dig.depth = depth
	f.call_func(d)
	for k in d:
		if d[k] is Dictionary:
			_dig_dict(d[k], f, depth+1)

static func _dig_node(d:Node, f:FuncRef, depth:int):
	_dig.depth = depth
	f.call_func(d)
	for i in d.get_child_count():
		_dig_node(d.get_child(i), f, depth+1)

static func file_size(path:String) -> String:
	var f:File = File.new()
	if f.open(path, File.READ) == OK:
		var bytes = f.get_len()
		f.close()
		return String.humanize_size(bytes)
	return "-1"

static func hue_shift(c:Color, h:float) -> Color:
	return c.from_hsv(wrapf(c.h + h, 0.0, 1.0), c.s, c.v, c.a)

static func highlight(line:String, start:int, length:int, default_color:Color, highlight_color:Color) -> String:
	var head:String = line.substr(0, start)
	var midd:String = line.substr(start, length)
	var tail:String = line.substr(start + length)
	head = clr(head, default_color)
	midd = b(clr(midd, highlight_color))
	tail = clr(tail, default_color)
	return head + midd + tail

static func b(t:String) -> String: return "[b]%s[/b]" % t
static func clr(t:String, c:Color) -> String: return "[color=#%s]%s[/color]" % [c.to_html(), t]

#static func saturate(c:Color, s:float=1.0, v:float=1.0) -> Color:
#	return c.from_hsv(c.h, c.s * s, c.v * v, c.a)

#static func sort(d, reverse:bool=false):
#	return Dict.new(d).sort(reverse)
#
#static func sort_value(d:Dictionary, reverse:bool=false) -> Dictionary:
#	return Dict.new(d).sort_value(reverse)
#
#static func sort_on_ext(d:Dictionary, reverse:bool=false) -> Dictionary:
#	return Dict.new(d).sort_ext(reverse)

static func split_many(s:String, spliton:String, allow_empty:bool=true) -> PoolStringArray:
	var parts := PoolStringArray()
	var start := 0
	var i := 0
	while i < len(s):
		if s[i] in spliton:
			if allow_empty or start < i:
				parts.append(s.substr(start, i - start))
			start = i + 1
		i += 1
	if allow_empty or start < i:
		parts.append(s.substr(start, i - start))
	return parts

static func commas(number) -> String:
	number = str(number)
	var mod = len(number) % 3
	var out = ""
	for i in len(number):
		if i and i % 3 == mod:
			out += ","
		out += number[i]
	return out

#class Dict:
#	var sort_array:bool = false
#	var d:Dictionary
#	var a:Array
#	var sorter:Array = []
#	var i:int = 0
#
#	func _init(item):
#		if item is Array:
#			sort_array = true
#			a = item
#		else:
#			d = item
#
#	func _pop():
#		if sort_array:
#			for i in a: sorter.append(a)
#		else:
#			for k in d: sorter.append([k, d[k]])
#
#	func _unpop():
#		if sort_array:
#			for i in len(sorter): a[i] = sorter[i]
#			return a
#		else:
#			d.clear()
#			for i in a: d[i[0]] = i[1]
#			return d
#
#	func sort(reverse:bool=false):
#		_pop()
#		a.sort_custom(self, "_sort_reverse" if reverse else "_sort")
#		return _unpop()
#
#	func sort_value(reverse:bool=false):
#		_pop()
#		i = 1
#		a.sort_custom(self, "_sort_reverse" if reverse else "_sort")
#		return _unpop()
#
#	func sort_ext(reverse:bool=false):
#		if sort_array:
#			for x in a:
#				if "." in a:
#		for k in d:
#			if "." in k:
#				var p = k.split(".", true, 1)
#				p = p[1] + p[0]
#				a.append([k, d[k], p + "." + k])
#			else:
#				a.append([k, d[k], "." + k])
#		i = 2
#		a.sort_custom(self, "_sort_reverse" if reverse else "_sort")
#		return _unpop()
#
#	func _sort(a, b): return a[i] > b[i]
#	func _sort_reverse(a, b): return a[i] < b[i]
