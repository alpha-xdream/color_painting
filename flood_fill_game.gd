extends Node2D
class_name FloodFillGame

@export_range(2, 6) var color_count := 4          # 颜色种数
@export_range(10, 20) var grid_size := 10         # 10×10
@export_range(15, 50) var max_steps := 25

@onready var grid: GridContainer = $GridContainer
@onready var steps_lbl: Label = $UI/Steps
@onready var status_lbl: Label = $UI/Status
@onready var color_palette: VBoxContainer = $ColorPalette
@onready var restart: Button = $UI/Restart

@onready var save_dialog: FileDialog = $EditUI/SaveDialog
@onready var load_dialog: FileDialog = $EditUI/LoadDialog


const PALETTE = [
	Color("#118ab2"),
	Color("#ef476f"), 
	Color("#ffd166"),
	Color("#06d6a0"), 
	Color("#073b4c"), Color("#ffffff")
]

var cells: Array[ColorRect] = []
var board: Array[Array]  # board[y][x] = color_index
var pre_board: Array[Array]  # board[y][x] = color_index
var steps := 0
var game_over := false
var select_color_index := 0

func _ready():
	randomize()
	build_grid()
	update_ui()
	init_colors()
	update_edit_ui()
	save_dialog.file_selected.connect(_do_save)
	load_dialog.file_selected.connect(_do_load)

func build_grid():
	# 清空旧格子
	for c in grid.get_children():
		c.queue_free()
	cells.clear()

	grid.columns = grid_size
	# 创建 ColorRect
	for y in grid_size:
		for x in grid_size:
			var c := ColorRect.new()
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.size_flags_vertical   = Control.SIZE_EXPAND_FILL
			c.mouse_filter = Control.MOUSE_FILTER_STOP
			c.set_meta("pos", Vector2i(x, y))
			grid.add_child(c)
			c.gui_input.connect(_on_cell_clicked.bind(c))
			cells.append(c)
			
	if len(pre_board) == 0:
		# 随机染色
		board = []
		for y in grid_size:
			var row: Array[int] = []
			for x in grid_size:
				row.append(randi_range(0, color_count-1))
			board.append(row)
		pre_board = board.duplicate()
	else:
		board = pre_board.duplicate()
	redraw_board()

func redraw_board():
	var idx := 0
	for y in grid_size:
		for x in grid_size:
			var ci :int = board[y][x]
			cells[idx].color = PALETTE[ci]
			idx += 1

func _on_cell_clicked(event: InputEvent, cell: ColorRect) -> void:
	if game_over or not (event is InputEventMouseButton and event.pressed):
		return
	var pos: Vector2i = cell.get_meta("pos")
	var target_color :int= board[pos.y][pos.x]

	var new_color := select_color_index
	if new_color == target_color:
		return  # 同颜色，无效点击

	flood_fill(pos, target_color, new_color)
	steps += 1
	redraw_board()
	update_ui()
	check_win_lose()

func flood_fill(start: Vector2i, old: int, new: int) -> void:
	var stack := [start]
	while not stack.is_empty():
		var p = stack.pop_back()
		if p.x < 0 or p.x >= grid_size or p.y < 0 or p.y >= grid_size:
			continue
		if board[p.y][p.x] != old:
			continue
		board[p.y][p.x] = new
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.UP)
		stack.append(p + Vector2i.DOWN)

func check_win_lose() -> void:
	var first = board[0][0]
	var win := true
	for row in board:
		for c in row:
			if c != first:
				win = false
				break
		if not win:
			break

	if win:
		status_lbl.text = "胜利！"
		game_over = true
	elif steps >= max_steps:
		status_lbl.text = "失败！"
		game_over = true

func update_ui():
	steps_lbl.text = "步数: %d / %d" % [steps, max_steps]

func _on_restart_pressed() -> void:
	restart_current_level()
	
func restart_current_level():
	steps = 0
	game_over = false
	build_grid()
	update_ui()
	status_lbl.text = ""
	

func init_colors() -> void:
	for i in color_count:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(32,32)
		# --- 纯色背景 ---
		var style := StyleBoxFlat.new()
		style.bg_color             = PALETTE[i]
		style.border_width_top     = 1
		style.border_width_bottom  = 1
		style.border_width_left    = 1
		style.border_width_right   = 1
		style.border_color         = Color.BLACK
		style.corner_radius_top_left     = 4
		style.corner_radius_top_right    = 4
		style.corner_radius_bottom_left  = 4
		style.corner_radius_bottom_right = 4

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)   # 也可单独做高亮
		btn.add_theme_stylebox_override("pressed", style)
		
		var s := StyleBoxFlat.new()
		s.bg_color       = Color.TRANSPARENT
		s.border_width_top = 3
		s.border_width_bottom = 3
		s.border_width_left = 3
		s.border_width_right = 3
		s.border_color   = Color.GREEN_YELLOW
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		s.expand_margin_top    = 3
		s.expand_margin_bottom = 3
		s.expand_margin_left   = 3
		s.expand_margin_right  = 3
		btn.add_theme_stylebox_override("focus", s)
		
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.set_meta("color_idx", i)
		btn.pressed.connect(_on_color_changed.bind(i))
		color_palette.add_child(btn)

	
func _on_color_changed(idx: int) -> void:
	# 例如：把当前“笔刷”颜色记录到变量
	select_color_index = idx



# ========= 新增变量 =========
@onready var edit_ui: CanvasLayer = $EditUI
var edit_mode := false
var brush_color_edit := 0		  # 编辑模式下的笔刷颜色

# ========= 输入切换 =========
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # Esc 也可
		toggle_edit_mode()

func toggle_edit_mode() -> void:
	print("toggle_edit_mode 1111")
	edit_mode = !edit_mode
	print("toggle_edit_mode 222")
	
	if !edit_mode:
		pre_board = board.duplicate()
	update_edit_ui()

func update_edit_ui():
	edit_ui.visible = edit_mode
	set_process_input(edit_mode)		   # 让 _input 只在编辑模式接收
	if edit_mode:
		status_lbl.text = "编辑模式"
	else:
		restart_current_level()			# 退出编辑后重新随机一局或保留

# ========= 编辑模式下输入 =========
func _input(event: InputEvent) -> void:
	if not edit_mode: return

	var pos := get_viewport().get_mouse_position()
	var cell := _cell_at_pos(pos)
	if cell.x < 0: return

	# 左键循环颜色
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var old :int= board[cell.y][cell.x]
		var next := (old + 1) % color_count
		board[cell.y][cell.x] = next
		print("11111111", cell)
		redraw_board()

	# 右键批量填充（同色连通块）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var target :int= board[cell.y][cell.x]
		flood_fill(cell, target, brush_color_edit)
		redraw_board()

# 工具：把屏幕坐标 → 格子坐标
func _cell_at_pos(pos: Vector2) -> Vector2i:
	var local := grid.get_global_transform().affine_inverse() * pos
	var col := int(local.x / (grid.size.x / grid_size))
	var row := int(local.y / (grid.size.y / grid_size))
	if col < 0 or col >= grid_size or row < 0 or row >= grid_size:
		return Vector2i(-1, -1)
	return Vector2i(col, row)

# ========= 保存 / 读取 =========
func _on_save_pressed() -> void:
	save_dialog.popup_centered_ratio(0.4)

func _on_load_pressed() -> void:
	load_dialog.popup_centered_ratio(0.4)
	
# ---------- 实际保存 ----------
func _do_save(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	for row in board:
		file.store_line(",".join(row.map(str)))
	file.close()
	status_lbl.text = "已保存: %s" % path.get_file()

# ---------- 实际读取 ----------
func _do_load(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	var lines := file.get_as_text().split("\n", false)
	file.close()

	if lines.size() != grid_size:
		push_error("关卡尺寸不符"); return
	for y in grid_size:
		var cols := lines[y].split(",", true, 0)
		if cols.size() != grid_size:
			push_error("列数不符"); return
		for x in grid_size:
			board[y][x] = int(cols[x])
	pre_board = board.duplicate()
	redraw_board()
	status_lbl.text = "已加载: %s" % path.get_file()

func _on_clear_pressed() -> void:
	for y in grid_size:
		for x in grid_size:
			board[y][x] = 0
	redraw_board()

func _on_return_pressed() -> void:
	toggle_edit_mode()
