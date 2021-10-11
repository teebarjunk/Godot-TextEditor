class_name TE_Util

static func load_json(path:String) -> Dictionary:
	var f:File = File.new()
	if f.file_exists(path):
		f.open(path, File.READ)
		var out = JSON.parse(f.get_as_text()).result
		f.close()
		return out
	return {}

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

static func dig(d, obj:Object, fname:String):
	var f = funcref(obj, fname)
	if d is Dictionary:
		_dig_dict(d, f)
	elif d is Node:
		_dig_node(d, f)

static func _dig_dict(d:Dictionary, f:FuncRef):
	f.call_func(d)
	for k in d:
		if d[k] is Dictionary:
			_dig_dict(d[k], f)

static func _dig_node(d:Node, f:FuncRef):
	f.call_func(d)
	for i in d.get_child_count():
		_dig_node(d.get_child(i), f)

static func file_size(path:String) -> String:
	var f:File = File.new()
	if f.open(path, File.READ) == OK:
		var bytes = f.get_len()
		f.close()
		return String.humanize_size(bytes)
	return "-1"

static func sort(d:Dictionary, reverse:bool=false) -> Dictionary:
	return Dict.new(d).sort(reverse)

static func sort_value(d:Dictionary, reverse:bool=false) -> Dictionary:
	return Dict.new(d).sort_value(reverse)

static func sort_on_ext(d:Dictionary, reverse:bool=false) -> Dictionary:
	return Dict.new(d).sort_ext(reverse)

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

class Dict:
	var d:Dictionary
	var a:Array = []
	var i:int = 0
	
	func _init(dict:Dictionary):
		d = dict
		
	func _pop():
		for k in d: a.append([k, d[k]])
	
	func _unpop() -> Dictionary:
		d.clear()
		for i in a: d[i[0]] = i[1]
		return d
	
	func sort(reverse:bool=false) -> Dictionary:
		_pop()
		a.sort_custom(self, "_sort_reverse" if reverse else "_sort")
		return _unpop()
	
	func sort_value(reverse:bool=false) -> Dictionary:
		_pop()
		i = 1
		a.sort_custom(self, "_sort_reverse" if reverse else "_sort")
		return _unpop()
	
	func sort_ext(reverse:bool=false) -> Dictionary:
		for k in d:
			if "." in k:
				var p = k.split(".", true, 1)
				p = p[1] + p[0]
				a.append([k, d[k], p + "." + k])
			else:
				a.append([k, d[k], "." + k])
		i = 2
		a.sort_custom(self, "_sort_reverse" if reverse else "_sort")
		return _unpop()
	
	func _sort(a, b): return a[i] > b[i]
	func _sort_reverse(a, b): return a[i] < b[i]
