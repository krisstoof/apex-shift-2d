extends Control

const ITEM_DATABASE := preload("res://scripts/items/item_database.gd")
const GRID_SLOT_COUNT := 9
const MAX_STACK_SIZE := 20
const PRIMARY_ITEM_ORDER := ["wood", "stone", "fiber", "meat", "bone"]

var inventory: Variant
var backdrop: ColorRect
var panel: PanelContainer
var inventory_grid: GridContainer
var info_label: Label
var slot_nodes: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func setup(target_inventory: Variant) -> void:
	refresh_from_inventory(target_inventory)


func open_inventory() -> void:
	visible = true
	refresh()


func close_inventory() -> void:
	visible = false


func toggle_inventory() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()


func refresh() -> void:
	refresh_from_inventory(inventory)


func refresh_from_inventory(target_inventory: Variant) -> void:
	inventory = target_inventory
	_connect_inventory_changed()
	_clear_slots()
	if inventory == null:
		return
	var visual_stacks := _build_visual_stacks()
	var shown_count: int = mini(visual_stacks.size(), GRID_SLOT_COUNT)
	for index in range(GRID_SLOT_COUNT):
		if index < visual_stacks.size():
			var stack: Dictionary = Dictionary(visual_stacks[index])
			_set_slot_item(slot_nodes[index], str(stack.get("item_id", "")), int(stack.get("count", 0)))
		else:
			_clear_slot(slot_nodes[index])
	info_label.visible = visual_stacks.size() > GRID_SLOT_COUNT
	if info_label.visible:
		info_label.text = "+%d stack(s) not shown" % (visual_stacks.size() - shown_count)


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.35)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -246.0
	panel.offset_top = -188.0
	panel.offset_right = 246.0
	panel.offset_bottom = 188.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.92)
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

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Inventory"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)

	var hint := Label.new()
	hint.text = "I / Esc"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 16)
	header.add_child(hint)

	var separator := HSeparator.new()
	vbox.add_child(separator)

	inventory_grid = GridContainer.new()
	inventory_grid.columns = 3
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_grid.add_theme_constant_override("h_separation", 10)
	inventory_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(inventory_grid)

	for i in range(GRID_SLOT_COUNT):
		var slot := _create_slot()
		inventory_grid.add_child(slot)
		slot_nodes.append(slot)

	info_label = Label.new()
	info_label.text = ""
	info_label.visible = false
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(info_label)


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

	return slot


func _connect_inventory_changed() -> void:
	if inventory == null:
		return
	if inventory.has_signal("inventory_changed"):
		var changed_callable: Callable = Callable(self, "_on_inventory_changed")
		if not inventory.inventory_changed.is_connected(changed_callable):
			inventory.inventory_changed.connect(changed_callable)


func _on_inventory_changed() -> void:
	if visible:
		refresh()


func _build_visual_stacks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var shown: Dictionary = {}
	for item_id in PRIMARY_ITEM_ORDER:
		var count := _get_inventory_count(item_id)
		if count > 0:
			_append_stacks(result, item_id, count)
			shown[item_id] = true
	for item_id in _get_all_inventory_item_ids():
		if shown.has(item_id):
			continue
		var count := _get_inventory_count(item_id)
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


func _clear_slots() -> void:
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


func _get_inventory_count(item_id: String) -> int:
	if inventory == null:
		return 0
	if inventory.has_method("get_amount"):
		return int(inventory.call("get_amount", item_id))
	if inventory.has_method("get_item_count"):
		return int(inventory.call("get_item_count", item_id))
	if inventory.has_method("get_count"):
		return int(inventory.call("get_count", item_id))
	if inventory is Dictionary:
		return int(Dictionary(inventory).get(item_id, 0))
	return 0


func _get_all_inventory_item_ids() -> Array[String]:
	var result: Array[String] = []
	if inventory == null:
		return result
	if inventory.has_method("get_all_items"):
		var items: Variant = inventory.call("get_all_items")
		if items is Dictionary:
			for key in Dictionary(items).keys():
				result.append(str(key))
			return result
	if inventory.has_method("get_slots"):
		var slots: Variant = inventory.call("get_slots")
		if slots is Array:
			for slot in Array(slots):
				if slot is Dictionary:
					var item_id: String = str(Dictionary(slot).get("item_id", ""))
					if not item_id.is_empty():
						result.append(item_id)
			return result
	if inventory is Dictionary:
		for key in Dictionary(inventory).keys():
			result.append(str(key))
	return result
