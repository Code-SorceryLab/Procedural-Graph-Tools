class_name TimelineTabView
extends MarginContainer

signal snapshot_selected(index: int)

var _step_list: ItemList
var _btn_first: Button
var _btn_prev: Button
var _btn_next: Button
var _btn_last: Button

var _snapshot_count: int = 0
var _current_index: int = -1

func _init() -> void:
	name = "Timeline"
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	
	var vcr_container = VBoxContainer.new()
	vcr_container.add_theme_constant_override("separation", 5)
	
	var header = Label.new()
	header.text = "Rasterization Steps"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vcr_container.add_child(header)
	
	_step_list = ItemList.new()
	_step_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_step_list.item_selected.connect(func(idx): snapshot_selected.emit(idx))
	vcr_container.add_child(_step_list)
	
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	_btn_first = Button.new(); _btn_first.text = "|<"
	_btn_prev = Button.new(); _btn_prev.text = "< Prev"
	_btn_next = Button.new(); _btn_next.text = "Next >"
	_btn_last = Button.new(); _btn_last.text = ">|"
	
	_btn_first.pressed.connect(func(): snapshot_selected.emit(0))
	_btn_prev.pressed.connect(func(): snapshot_selected.emit(_current_index - 1))
	_btn_next.pressed.connect(func(): snapshot_selected.emit(_current_index + 1))
	_btn_last.pressed.connect(func(): snapshot_selected.emit(_snapshot_count - 1))
	
	btn_row.add_child(_btn_first)
	btn_row.add_child(_btn_prev)
	btn_row.add_child(_btn_next)
	btn_row.add_child(_btn_last)
	vcr_container.add_child(btn_row)
	
	add_child(vcr_container)
	set_buttons_active(false)

func add_snapshot(step_name: String) -> void:
	_step_list.add_item(step_name)
	_snapshot_count += 1

func clear() -> void:
	_step_list.clear()
	_snapshot_count = 0
	_current_index = -1
	set_buttons_active(false)

func select_index(idx: int) -> void:
	_current_index = idx
	_step_list.select(idx)
	_step_list.ensure_current_is_visible()
	set_buttons_active(true) 

func set_buttons_active(active: bool) -> void:
	_btn_first.disabled = not active or _current_index <= 0
	_btn_prev.disabled = not active or _current_index <= 0
	_btn_next.disabled = not active or _current_index >= _snapshot_count - 1
	_btn_last.disabled = not active or _current_index >= _snapshot_count - 1
