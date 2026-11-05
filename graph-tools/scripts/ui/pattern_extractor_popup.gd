class_name PatternExtractorPopup
extends Window

# --- DATA ---
var _target_graph: Graph
var _extracted_patterns: Dictionary = {}

var _editor_ref: GraphEditor 
var _active_mode: GraphPatternExtractor.ExtractMode

# --- UI REFS ---
var opt_mode: OptionButton
var spin_depth: SpinBox
var chk_rotations: CheckBox
var chk_reflections: CheckBox
var btn_extract: Button
var btn_save: Button
var btn_close: Button
var grid_container: GridContainer
var lbl_status: Label
var file_dialog: FileDialog

func _init() -> void:
	title = "Graph Pattern Extractor"
	size = Vector2i(900, 600)
	
	# We want it to act like a modal, preventing interaction with the editor behind it
	transient = true
	exclusive = true
	
	# Main split (Horizontal)
	var hbox_main = HBoxContainer.new()
	hbox_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox_main)
	
	# ==========================================================================
	# LEFT PANEL: SETTINGS
	# ==========================================================================
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 250
	# Add a bit of padding to the left panel
	left_panel.add_theme_constant_override("separation", 10)
	
	var margin_left = MarginContainer.new()
	margin_left.add_theme_constant_override("margin_left", 10)
	margin_left.add_theme_constant_override("margin_top", 10)
	margin_left.add_theme_constant_override("margin_bottom", 10)
	margin_left.add_child(left_panel)
	hbox_main.add_child(margin_left)
	
	var lbl_title = Label.new()
	lbl_title.text = "Extraction Parameters"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(lbl_title)
	left_panel.add_child(HSeparator.new())
	
	# Mode Selection
	var lbl_mode = Label.new()
	lbl_mode.text = "Target Engine:"
	left_panel.add_child(lbl_mode)
	
	opt_mode = OptionButton.new()
	opt_mode.add_item("Topological Grammar (Structure)")
	opt_mode.add_item("Semantic WFC (Tags/Rules)")
	left_panel.add_child(opt_mode)
	
	# Depth
	var hbox_depth = HBoxContainer.new()
	var lbl_depth = Label.new()
	lbl_depth.text = "Hierarchy Depth:"
	lbl_depth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	spin_depth = SpinBox.new()
	spin_depth.min_value = 1
	spin_depth.max_value = 5
	spin_depth.value = 1
	
	hbox_depth.add_child(lbl_depth)
	hbox_depth.add_child(spin_depth)
	left_panel.add_child(hbox_depth)
	
	# Permutations
	chk_rotations = CheckBox.new()
	chk_rotations.text = "Extract Rotations (90/180/270)"
	left_panel.add_child(chk_rotations)
	
	chk_reflections = CheckBox.new()
	chk_reflections.text = "Extract Reflections (Flip)"
	left_panel.add_child(chk_reflections)
	
	left_panel.add_child(HSeparator.new())
	
	# Execution
	btn_extract = Button.new()
	btn_extract.text = "▶ Run Extraction"
	btn_extract.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	btn_extract.pressed.connect(_on_run_extraction_pressed)
	left_panel.add_child(btn_extract)
	
	lbl_status = Label.new()
	lbl_status.text = "Ready."
	lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_status.add_theme_font_size_override("font_size", 12)
	left_panel.add_child(lbl_status)
	
	# Push the action buttons to the bottom of the left panel
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(spacer)
	
	# Manual Action Buttons (Save/Close)
	btn_save = Button.new()
	btn_save.text = "Apply Changes"
	btn_save.pressed.connect(_on_save_requested)
	left_panel.add_child(btn_save)
	
	btn_close = Button.new()
	btn_close.text = "Close"
	btn_close.pressed.connect(hide)
	left_panel.add_child(btn_close)
	
	hbox_main.add_child(VSeparator.new())
	
	# ==========================================================================
	# RIGHT PANEL: RESULTS GRID
	# ==========================================================================
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_main.add_child(right_panel)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(scroll)
	
	grid_container = GridContainer.new()
	grid_container.columns = 3 # 3 patterns per row
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_container)
	
	# Handle the 'X' button on the window frame natively
	close_requested.connect(hide)
	
	# [NEW] Setup the FileDialog
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.add_filter("*.json", "Pattern Dictionary")
	file_dialog.title = "Save Pattern Dictionary"
	file_dialog.use_native_dialog = true 
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	hide()

func open(editor: GraphEditor) -> void:
	_editor_ref = editor
	_target_graph = editor.graph
	
	_clear_grid()
	
	# Read the UI dropdown to determine which mode we are looking at
	_active_mode = GraphPatternExtractor.ExtractMode.TOPOLOGICAL
	if opt_mode.selected == 1:
		_active_mode = GraphPatternExtractor.ExtractMode.SEMANTIC
		
	# Check if the editor already has cached patterns for this mode
	var cached_patterns = {}
	if _active_mode == GraphPatternExtractor.ExtractMode.TOPOLOGICAL:
		cached_patterns = _editor_ref.extracted_topo_patterns
	else:
		cached_patterns = _editor_ref.extracted_semantic_patterns
		
	if not cached_patterns.is_empty():
		# Load the cache into the UI
		_rebuild_grid_from_cache(cached_patterns)
		lbl_status.text = "Loaded cached %s patterns from editor memory." % ["Topological", "Semantic"][_active_mode]
	else:
		lbl_status.text = "No cached patterns. Ready to extract from canvas."
		
	popup_centered()

# Helper to render cards from a pre-existing dictionary
func _rebuild_grid_from_cache(pattern_dict: Dictionary) -> void:
	if not pattern_dict.has("patterns"): return
	
	for p_data in pattern_dict["patterns"]:
		var card = PatternCard.new()
		grid_container.add_child(card)
		
		# We must deserialize the mini-graph from the cached JSON string
		var mini_graph = GraphSerializer.deserialize(p_data["graph_json"])
		
		card.setup(p_data["signature"], mini_graph, p_data["weight"])
		
		# If the user previously turned this pattern off, respect that
		card.chk_active.button_pressed = p_data.get("active", true)

func _clear_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()

func _on_run_extraction_pressed() -> void:
	if not _target_graph: return
	
	lbl_status.text = "Extracting patterns..."
	btn_extract.disabled = true
	_clear_grid()
	
	_active_mode = GraphPatternExtractor.ExtractMode.TOPOLOGICAL
	if opt_mode.selected == 1:
		_active_mode = GraphPatternExtractor.ExtractMode.SEMANTIC
		
	var depth = int(spin_depth.value)
	
	# Execute the Math
	var extracted_data = GraphPatternExtractor.extract_patterns(_target_graph, _active_mode, depth)
	
	for pattern in extracted_data:
		var card = PatternCard.new()
		grid_container.add_child(card)
		card.setup(pattern["signature"], pattern["graph"], pattern["frequency"])
		
	lbl_status.text = "Extraction complete! Found %d unique patterns. (Unsaved)" % extracted_data.size()
	btn_extract.disabled = false

# The "Apply" logic
func _on_save_requested() -> void:
	var final_dict = {
		"meta": {
			"version": "1.0",
			"type": "PatternDictionary",
			"mode": _active_mode,
			"timestamp": Time.get_datetime_string_from_system()
		},
		"patterns": []
	}
	
	var active_count = 0
	for child in grid_container.get_children():
		if child is PatternCard:
			var data = child.get_export_data()
			if not data.is_empty():
				final_dict["patterns"].append(data)
				if data.get("active", true): active_count += 1
				
	if final_dict["patterns"].is_empty():
		lbl_status.text = "Error: No patterns to apply!"
		return
		
	# Inject directly into the GraphEditor's memory!
	if _active_mode == GraphPatternExtractor.ExtractMode.TOPOLOGICAL:
		_editor_ref.extracted_topo_patterns = final_dict
	else:
		_editor_ref.extracted_semantic_patterns = final_dict
		
	lbl_status.text = "Successfully applied %d active patterns to editor memory!" % active_count
	#print(_editor_ref.extracted_topo_patterns)

func _on_file_selected(path: String) -> void:
	var json_str = JSON.stringify(_extracted_patterns, "\t")
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		lbl_status.text = "Successfully saved dictionary to:\n" + path.get_file()
	else:
		lbl_status.text = "Error: Failed to write file to " + path
