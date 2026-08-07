extends Node
class_name UILayoutController

@export_group("Target Panels")
@export var left_panel: Control
@export var right_panel: Control
@export var top_panel: Control

@export_group("Toggle Buttons")
@export var btn_toggle_left: Button
@export var btn_toggle_right: Button
@export var btn_toggle_top: Button

func _ready() -> void:
	# Yield for one frame to guarantee ConfigManager.load_config() has finished
	await get_tree().process_frame
	
	# 1. Apply saved states on bootup
	if left_panel: left_panel.visible = GraphSettings.UI_SHOW_LEFT_BAR
	if right_panel: right_panel.visible = GraphSettings.UI_SHOW_RIGHT_BAR
	if top_panel: top_panel.visible = GraphSettings.UI_SHOW_TOP_BAR

	# 2. Connect buttons and set initial text/icons
	if btn_toggle_left:
		btn_toggle_left.pressed.connect(_on_toggle_left)
		_update_btn_text(btn_toggle_left, left_panel.visible, "<", ">")
		
	if btn_toggle_right:
		btn_toggle_right.pressed.connect(_on_toggle_right)
		_update_btn_text(btn_toggle_right, right_panel.visible, ">", "<")
		
	if btn_toggle_top:
		btn_toggle_top.pressed.connect(_on_toggle_top)
		_update_btn_text(btn_toggle_top, top_panel.visible, "^", "v")

# --- INPUT HOTKEYS ---
func _input(event: InputEvent) -> void:
	# Press TAB to instantly toggle "Zen Mode"
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_toggle_zen_mode()
		get_viewport().set_input_as_handled()

# --- TOGGLE LOGIC ---
func _on_toggle_left() -> void:
	if not left_panel: return
	left_panel.visible = not left_panel.visible
	GraphSettings.UI_SHOW_LEFT_BAR = left_panel.visible
	_update_btn_text(btn_toggle_left, left_panel.visible, "<", ">")
	ConfigManager.save_config()

func _on_toggle_right() -> void:
	if not right_panel: return
	right_panel.visible = not right_panel.visible
	GraphSettings.UI_SHOW_RIGHT_BAR = right_panel.visible
	_update_btn_text(btn_toggle_right, right_panel.visible, ">", "<")
	ConfigManager.save_config()

func _on_toggle_top() -> void:
	if not top_panel: return
	top_panel.visible = not top_panel.visible
	GraphSettings.UI_SHOW_TOP_BAR = top_panel.visible
	_update_btn_text(btn_toggle_top, top_panel.visible, "^", "v")
	ConfigManager.save_config()

func _toggle_zen_mode() -> void:
	# If any panel is visible, hide them all. If all are hidden, show them all.
	var any_visible = false
	if left_panel and left_panel.visible: any_visible = true
	if right_panel and right_panel.visible: any_visible = true
	if top_panel and top_panel.visible: any_visible = true
	
	var target_state = not any_visible
	
	if left_panel: 
		left_panel.visible = target_state
		GraphSettings.UI_SHOW_LEFT_BAR = target_state
		if btn_toggle_left: _update_btn_text(btn_toggle_left, target_state, "<", ">")
		
	if right_panel: 
		right_panel.visible = target_state
		GraphSettings.UI_SHOW_RIGHT_BAR = target_state
		if btn_toggle_right: _update_btn_text(btn_toggle_right, target_state, ">", "<")
		
	if top_panel: 
		top_panel.visible = target_state
		GraphSettings.UI_SHOW_TOP_BAR = target_state
		if btn_toggle_top: _update_btn_text(btn_toggle_top, target_state, "^", "v")
		
	ConfigManager.save_config()

func _update_btn_text(btn: Button, is_open: bool, open_text: String, closed_text: String) -> void:
	if not btn: return
	btn.text = open_text if is_open else closed_text
