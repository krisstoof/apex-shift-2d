extends Control

const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const PLAYER_SLOT_COUNT := 9
const STORAGE_SLOT_COUNT := 12
const MAX_STACK_SIZE := 20
const PRIMARY_ITEM_ORDER := ["wood", "stone", "fiber", "meat", "bone"]

var player_inventory: Variant
var storage_inventory: Variant
var storage_box: Node
var backdrop: ColorRect
var panel: PanelContainer
var player_grid: GridContainer
var storage_grid: GridContainer
var info_label: Label
var player_slots: Array[Control] = []
var storage_slots: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func setup(p_player_inventory: Variant, p_storage_inventory: Variant, p_storage_box: Node = null) -> void:
	player_inventory = p_player_inventory
	storage_inventory = p_storage_inventory
	storage_box = p_storage_box
	_connect_inventory_changed()
	refresh()


func open_storage_box() -> void:
	visible = true
	refresh()


func close_storage_box() -> void:
	visible = false


func refresh() -> void:
	_connect_inventory_changed()
	_refresh_panel()


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.35)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -382.0
	panel.offset_top = -232.0
	panel.offset_right = 382.0
	panel.offset_bottom = 232.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.94)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.75, 0.78, 0.72, 0.35)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title := Label.new()
	title.text = "Storage Box"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)

	var hint := Label.new()
	hint.text = "E / Esc"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 16)
	header.add_child(hint)

	var separator := HSeparator.new()
	root.add_child(separator)

	var grids := HBoxContainer.new()
	grids.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grids.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grids.add_theme_constant_override("separation", 16)
	root.add_child(grids)

	var player_box: Dictionary = _build_inventory_column("Player", 3, PLAYER_SLOT_COUNT)
	player_grid = player_box["grid"]
	player_slots = player_box["slots"]
	grids.add_child(player_box["container"])

	var storage_box_container: Dictionary = _build_inventory_column("Storage", 3, STORAGE_SLOT_COUNT)
	storage_grid = storage_box_container["grid"]
	storage_slots = storage_box_container["slots"]
	grids.add_child(storage_box_container["container"])

	info_label = Label.new()
	info_label.text = ""
	info_label.visible = false
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 14)
	root.add_child(info_label)


func _build_inventory_column(title_text: String, columns: int, slot_count: int) -> Dictionary:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	container.add_child(title)

	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	container.add_child(grid)

	var slots: Array[Control] = []
	for i in range(slot_count):
		var slot := _create_slot()
		slot.set_meta("slot_index", i)
		grid.add_child(slot)
		slots.append(slot)
	return {
		"container": container,
		"grid": grid,
		"slots": slots
	}


func _create_slot() -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(72, 72)
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.06, 0.07, 0.08, 0.92)
	slot_style.corner_radius_top_left = 6
	slot_style.corner_radius_top_right = 6
	slot_style.corner_radius_bottom_left = 6
	slot_style.corner_radius_bottom_right = 6
	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.border_color = Color(0.74, 0.77, 0.72, 0.32)
	slot_style.content_margin_left = 6.0
	slot_style.content_margin_right = 6.0
	slot_style.content_margin_top = 6.0
	slot_style.content_margin_bottom = 6.0
	slot.add_theme_stylebox_override("panel", slot_style)

	var container := Control.new()
	container.name = "Content"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(container)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(40, 40)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.position = Vector2(10, 6)
	container.add_child(icon)

	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = ""
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.position = Vector2(0, 42)
	count_label.size = Vector2(60, 22)
	container.add_child(count_label)

	slot.gui_input.connect(_on_slot_gui_input.bind(slot))
	return slot


func _connect_inventory_changed() -> void:
	if player_inventory != null and player_inventory.has_signal("inventory_changed"):
		var callable: Callable = Callable(self, "_on_inventory_changed")
		if not player_inventory.inventory_changed.is_connected(callable):
			player_inventory.inventory_changed.connect(callable)
	if storage_inventory != null and storage_inventory.has_signal("inventory_changed"):
		var storage_callable: Callable = Callable(self, "_on_inventory_changed")
		if not storage_inventory.inventory_changed.is_connected(storage_callable):
			storage_inventory.inventory_changed.connect(storage_callable)


func _on_inventory_changed() -> void:
	if visible:
		refresh()


func _on_slot_gui_input(event: InputEvent, slot: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var slot_index: int = int(slot.get_meta("slot_index", -1))
	if slot_index < 0:
		return
	if slot.get_parent() == player_grid:
		_transfer_slot(player_inventory, storage_inventory, slot_index)
	else:
		_transfer_slot(storage_inventory, player_inventory, slot_index)


func _transfer_slot(source_inventory: Variant, destination_inventory: Variant, slot_index: int) -> void:
	if source_inventory == null or destination_inventory == null:
		return
	if not source_inventory.has_method("get_slots"):
		return
	var slots: Variant = source_inventory.call("get_slots")
	if not (slots is Array):
		return
	var slot_data_array: Array = Array(slots)
	if slot_index < 0 or slot_index >= slot_data_array.size():
		return
	var slot_data: Variant = slot_data_array[slot_index]
	if not (slot_data is Dictionary):
		return
	var slot_dict := Dictionary(slot_data)
	var item_id := str(slot_dict.get("item_id", ""))
	var amount := int(slot_dict.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return
	var leftover := int(destination_inventory.call("add_item", item_id, amount))
	var moved := amount - leftover
	if moved > 0:
		source_inventory.call("remove_item", item_id, moved)
	if leftover > 0:
		_show_info("Inventory full")


func _refresh_panel() -> void:
	if info_label != null:
		info_label.visible = false
	_clear_slots(player_slots)
	_clear_slots(storage_slots)
	_fill_slots(player_slots, player_inventory, PLAYER_SLOT_COUNT)
	_fill_slots(storage_slots, storage_inventory, STORAGE_SLOT_COUNT)


func _fill_slots(slot_nodes: Array[Control], inventory: Variant, slot_limit: int) -> void:
	if inventory == null:
		return
	var visual_stacks: Array[Dictionary] = _build_visual_stacks(inventory)
	var shown_count: int = mini(visual_stacks.size(), slot_limit)
	for index in range(slot_limit):
		if index < visual_stacks.size():
			var stack: Dictionary = Dictionary(visual_stacks[index])
			_set_slot_item(slot_nodes[index], str(stack.get("item_id", "")), int(stack.get("count", 0)))
		else:
			_clear_slot(slot_nodes[index])
	if info_label != null and visual_stacks.size() > slot_limit:
		info_label.visible = true
		info_label.text = "+%d stack(s) not shown" % (visual_stacks.size() - shown_count)


func _build_visual_stacks(target_inventory: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var shown: Dictionary = {}
	for item_id in PRIMARY_ITEM_ORDER:
		var count := _get_inventory_count(target_inventory, item_id)
		if count > 0:
			_append_stacks(result, item_id, count)
			shown[item_id] = true
	for item_id in _get_all_inventory_item_ids(target_inventory):
		if shown.has(item_id):
			continue
		var count := _get_inventory_count(target_inventory, item_id)
		if count > 0:
			_append_stacks(result, item_id, count)
	return result


func _append_stacks(result: Array[Dictionary], item_id: String, count: int) -> void:
	var remaining := count
	while remaining > 0:
		var stack_count: int = mini(remaining, MAX_STACK_SIZE)
		result.append({
			"item_id": item_id,
			"count": stack_count
		})
		remaining -= stack_count


func _clear_slots(slot_nodes: Array[Control]) -> void:
	for slot in slot_nodes:
		_clear_slot(slot)


func _set_slot_item(slot: Control, item_id: String, count: int) -> void:
	if slot == null:
		return
	var icon: TextureRect = slot.get_node_or_null("Content/Icon")
	var count_label: Label = slot.get_node_or_null("Content/CountLabel")
	if icon != null:
		var icon_path := ITEM_DATABASE.get_icon_path(item_id)
		icon.texture = load(icon_path) if not icon_path.is_empty() else null
		icon.visible = true
	if count_label != null:
		count_label.text = "x%d" % count if count > 1 else ""
		count_label.visible = count > 1


func _clear_slot(slot: Control) -> void:
	if slot == null:
		return
	var icon: TextureRect = slot.get_node_or_null("Content/Icon")
	var count_label: Label = slot.get_node_or_null("Content/CountLabel")
	if icon != null:
		icon.texture = null
		icon.visible = false
	if count_label != null:
		count_label.text = ""
		count_label.visible = false


func _get_inventory_count(target_inventory: Variant, item_id: String) -> int:
	if target_inventory == null:
		return 0
	if target_inventory.has_method("get_amount"):
		return int(target_inventory.call("get_amount", item_id))
	if target_inventory.has_method("get_item_count"):
		return int(target_inventory.call("get_item_count", item_id))
	if target_inventory.has_method("get_count"):
		return int(target_inventory.call("get_count", item_id))
	if target_inventory is Dictionary:
		return int(Dictionary(target_inventory).get(item_id, 0))
	return 0


func _get_all_inventory_item_ids(target_inventory: Variant) -> Array[String]:
	var result: Array[String] = []
	if target_inventory == null:
		return result
	if target_inventory.has_method("get_all_items"):
		var items: Variant = target_inventory.call("get_all_items")
		if items is Dictionary:
			for key in Dictionary(items).keys():
				result.append(str(key))
			return result
	if target_inventory.has_method("get_slots"):
		var slots: Variant = target_inventory.call("get_slots")
		if slots is Array:
			for slot in Array(slots):
				if slot is Dictionary:
					var item_id: String = str(Dictionary(slot).get("item_id", ""))
					if not item_id.is_empty():
						result.append(item_id)
			return result
	if target_inventory is Dictionary:
		for key in Dictionary(target_inventory).keys():
			result.append(str(key))
	return result


func _show_info(text: String) -> void:
	if info_label == null:
		return
	info_label.text = text
	info_label.visible = true
