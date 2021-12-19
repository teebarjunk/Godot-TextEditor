tool
extends Resource
class_name TE_ExtensionHelper

var symbols:Dictionary = {}

func get_tab() -> String:
	return "	"

func generate_meta(t:TextEdit, r:RichTextLabel):
	var chars = TE_Util.commas(len(t.text))
	var words = TE_Util.commas(len(t.text.split(" ", false)))
	var lines = TE_Util.commas(len(TE_Util.split_many(t.text, ".?!\n", false)))
	var bytes = TE_Util.file_size(t.file_path)
	
	r.set_bbcode(r.table([
		["chars", "words", "lines", "bytes"],
		[chars, words, lines, bytes]
	]))

func toggle_comment(t:TextEdit, head:String="", tail:String=""):
	var wasnt_selected:bool = false
	var cursor_l
	var cursor_c
	
	if not t.is_selection_active():
		var c = t.cursor_get_column()
		t.insert_text_at_cursor(head + tail)
		t.cursor_set_column(c + len(head))
		return
#		var l = t.cursor_get_line()
#		var lt = t.get_line(l)
#		wasnt_selected = lt.strip_edges() == ""
#		cursor_l = t.cursor_get_line()
#		cursor_c = t.cursor_get_column()
#		var s = len(lt) - len(lt.strip_edges(true, false))
#		t.select(l, s, l, len(t.get_line(l)))
	
#	if not t.is_selection_active():
#		return
	
	var l1 = t.get_selection_from_line()
	var c1 = t.get_selection_from_column()
	var old = t.get_selection_text()
	var new
	
	if TE_Util.is_wrapped(old, head, tail):
		new = TE_Util.unwrap(old, head, tail)
	else:
		new = TE_Util.wrap(old, head, tail)
	
	t.insert_text_at_cursor(new)
	
	if wasnt_selected:
		t.deselect()
		t.cursor_set_line(cursor_l)
		t.cursor_set_column(cursor_c+len(head))
	
	else:
		var l = new.split("\n")
		var l2 = l1 + len(l)-1
		var c2 = c1 + len(l[-1])
		t.select(l1, c1, l2, c2)

func add_symbol(line:int=-1, deep:int=0, name:String="") -> Dictionary:
	var symbol = { deep=deep, name=name, tags=[] }
	symbols[line] = symbol
	return symbol

func get_symbols(t:String) -> Dictionary:
	symbols = {}
	return symbols

#func get_symbol_names(s:Dictionary):
#	var out = []
#	for k in s:
#		if k != -1:
#			out.append(s[k].name)
#	return out
	
func get_tag_counts(s:Dictionary) -> Dictionary:
	var out = {}
	for k in s:
		for tag in s[k].tags:
			if not tag in out:
				out[tag] = 1
			else:
				out[tag] += 1
	return out

func apply_colors(e, t:TextEdit):
	t.add_color_override("font_color", e.color_text)
	t.add_color_override("number_color", e.color_var)
	t.add_color_override("member_variable_color", e.color_var)
