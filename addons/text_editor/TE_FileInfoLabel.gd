tool
extends Node

const DIM:Color = Color.webgray
const CLR:Color = Color.white

onready var editor:TE_Editor = owner
var tab:TextEdit = null
var typed:String = ""
var word_count:int = 0

func _ready():
	var _e
	yield(get_tree(), "idle_frame")
	_e = editor.tab_parent.connect("tab_changed", self, "_tab_changed")
	
	editor.override_fonts($l)
	editor.override_fonts($m)
	editor.override_fonts($r)

func _tab_changed(index:int):
	if tab and is_instance_valid(tab) and not tab.is_queued_for_deletion():
		tab.disconnect("cursor_changed", self, "_cursor_changed")
		tab = null
	
	var new_tab = editor.tab_parent.get_child(index)
	if tab == new_tab:
		return
	tab = new_tab
	var _e
	_e = tab.connect("cursor_changed", self, "_cursor_changed")
#	_e = tab.connect("text_changed", self, "_text_changed")
#
#func _text_changed():
##	print("text changed")
#	pass

func _input(event):
	if event is InputEventKey and event.pressed and tab and is_instance_valid(tab) and tab.has_focus():
		if not event.scancode == KEY_BACKSPACE:
			if char(event.scancode) in " .?!-":
				word_count += 1
				typed = ""
			else:
				typed += char(event.scancode)
			_cursor_changed()

func _cursor_changed():
	var l_lines:PoolStringArray = PoolStringArray()
	var m_lines:PoolStringArray = PoolStringArray()
	var r_lines:PoolStringArray = PoolStringArray()
	var l:RichTextLabel
	
	if tab.is_selection_active():
		var seltext:String = tab.get_selection_text()
		var words = {}
		var word_count:int = TE_Util.count_words(seltext, words, null, false)
		m_lines.append(kv("chars", len(seltext)))
		m_lines.append(kv("words", word_count))
		
		var l1 = tab.get_selection_from_line() + 1
		var l2 = tab.get_selection_to_line() + 1
		var c1 = tab.get_selection_from_column()
		var c2 = tab.get_selection_to_column()
		
		if l1 == l2:
			l_lines.append(kv("line", l1))
			l_lines.append(kv("char", "%s - %s" % [c1, c2]))
		
		else:
			l_lines.append(clr("line: ", DIM) + clr(str(l1), CLR) + clr(":", DIM) + clr(str(c1), CLR))
			l_lines.append(clr("->", Color.webgray))
			l_lines.append(clr("line: ", DIM) + clr(str(l2), CLR) + clr(":", DIM) + clr(str(c2), CLR))
			
			m_lines.append(kv("lines", abs(l2 - l1) + 1))
		
	else:
		l_lines.append(kv("line", tab.cursor_get_line() + 1))
		l_lines.append(kv("char", tab.cursor_get_column()))
	
	var depth = tab.get_line_symbols(tab.cursor_get_line())
	for i in len(depth):
		depth[i] = b(depth[i])
	r_lines.append(depth.join(clr("/", DIM)))
	
	m_lines.append(kv("typed", word_count))
	
	$l.set_bbcode(l_lines.join(" "))
	$m.set_bbcode("[center]" + m_lines.join(" "))
	$r.set_bbcode("[right]" +r_lines.join(" "))

func kv(k:String, v) -> String:
	var clr2 = Color.white
	if v is int:
		v = TE_Util.commas(v)
	return clr(k + ": ", DIM) + clr(str(v), clr2)

func b(t:String) -> String: return "[b]%s[/b]" % t
func i(t:String) -> String: return "[i]%s[/i]" % t
func u(t:String) -> String: return "[u]%s[/u]" % t
func clr(t:String, c:Color) -> String: return "[color=#%s]%s[/color]" % [c.to_html(), t]
