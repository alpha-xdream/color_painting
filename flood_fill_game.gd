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


const PALETTE = [
	Color("#118ab2"),
	Color("#ef476f"), 
	Color("#ffd166"),
	Color("#06d6a0"), 
	Color("#073b4c"), Color("#ffffff")
]

var cells: Array[ColorRect] = []
var board: Array[Array]  # board[y][x] = color_index
var steps := 0
var game_over := false
var select_color_index := 0

func _ready():
	randomize()
	build_grid()
	update_ui()
	init_colors()

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
			
	# 随机染色
	board = []
	for y in grid_size:
		var row: Array[int] = []
		for x in grid_size:
			row.append(randi_range(0, color_count-1))
		board.append(row)
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
