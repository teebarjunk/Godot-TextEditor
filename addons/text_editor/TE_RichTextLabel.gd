extends RichTextLabel

onready var editor:TE_Editor = owner

var meta_items:Array = []
var meta_hovered:Array = []

class Table:
	var table_id:String
	var heading:Array = []
	var columns:Array = []
	var _sort_index:int
	var _sort_reverse:bool
	
	func _init(id:String):
		table_id = id
	
	func sort(index:int, reverse:bool):
		_sort_index = index
		_sort_reverse = reverse
		columns.sort_custom(self, "_sort")
	
	func output(rte:RichTextLabel):
		rte.push_table(len(heading))
		for i in len(heading):
			rte.push_cell()
			rte.push_bold()
			rte.push_meta("table|%s|%s" % [table_id, i])
			rte.add_text(heading[i])
			rte.pop()
			rte.pop()
			rte.pop()
		for i in len(columns):
			rte.push_cell()
			rte.add_text(str(columns[i]))
			rte.pop()
		rte.pop()

class RTE:
	var rte
	var s:String
	
	func start(st:String):
		s = st
		return self

	func clr(c:Color):
		s = "[color=#%s]%s[/color]" % [c.to_html(), s]
		return self
	
	func meta(type:String, meta, args=null):
		var index:int = len(rte.meta_items)
		rte.meta_items.append(meta)
		s = "[url=%s|%s]%s[/url]" % [type, index, s]
		return self
	
	func out():
		rte.append_bbcode(s)

func _ready():
	# hint
	theme = Theme.new()
	theme.set_font("font", "TooltipLabel", editor.FONT_R)
	
	add_font_override("normal_font", owner.FONT_R)
	add_font_override("bold_font", owner.FONT_B)
	add_font_override("italics_font", owner.FONT_I)
	add_font_override("bold_italics_font", owner.FONT_BI)
	
	var _e
	_e = connect("resized", self, "_resized")
	_e = connect("meta_clicked", self, "_meta_clicked")
	_e = connect("meta_hover_started", self, "_meta_hover_started")
	_e = connect("meta_hover_ended", self, "_meta_hover_ended")

func _resized():
	pass

func _clicked(_data):
	pass

func clear():
	.clear()
	meta_items.clear()

func table(rows) -> String:
	var cells = ""
	var clr = Color.white.darkened(.5).to_html()
	for i in len(rows):
		if i == 0:
			for item in rows[i]:
				cells += "[cell][b]%s[/b][/cell][/color]" % item
		else:
			for item in rows[i]:
				cells += "[cell][color=#%s]%s[/color][/cell]" % [clr, item]
	return "[center][table=%s]%s[/table][/center]" % [len(rows[0]), cells]

func b(t:String) -> String: return "[b]%s[/b]" % t
func i(t:String) -> String: return "[i]%s[/i]" % t
func u(t:String) -> String: return "[u]%s[/u]" % t
func clr(t:String, c:Color) -> String: return "[color=#%s]%s[/color]" % [c.to_html(), t]
func center(t:String): return "[center]%s[/center]" % t

func _meta_hover_started(meta):
	var info = meta_items[int(meta)]
	var hint = info[1]
	meta_hovered = info[0]
	if hint:
		hint_tooltip = hint

func _meta_hover_ended(_meta):
	meta_hovered = []
	hint_tooltip = ""

func _meta_clicked(meta):
	var info = meta_items[int(meta)]
	if info[0]:
		_clicked(info[0])

func add_meta(args:Array, hint:String) -> int:
	var index:int = len(meta_items)
	meta_items.append([args, hint])
	return index
	
func meta(t:String, args:Array=[], hint:String="") -> String:
	var index:int = add_meta(args, hint)
	return "[url=%s]%s[/url]" % [index, t]
