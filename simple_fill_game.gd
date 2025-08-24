extends Node2D

class SimpleNode:
	var color: int
	var links: Array[SimpleNode] = []
	var cells: Array[Vector2i] = []      # 额外记录所有格子坐标，方便调试
	var circle: Circle
		# 去重添加
	func add_links_unique(new_links: Array[SimpleNode]):
		for n in new_links:
			if n != self and not links.has(n):
				links.append(n)
	func links_unique_check():
		var seen := {}
		var new_links: Array[SimpleNode] = []
		for n in links:
			if n != self and not seen.has(n):
				seen[n] = true
				new_links.append(n)
		links = new_links

const PALETTE = [
	Color("#118ab2"),
	Color("#ef476f"), 
	Color("#ffd166"),
	Color("#06d6a0"), 
	Color("#073b4c"), Color("#ffffff")
]

@onready var load_dialog: FileDialog = $EditUI/LoadDialog
@onready var color_palette: VBoxContainer = $EditUI/ColorPalette
@onready var steps_lbl: Label = $EditUI/Steps


var color_count := 4          # 颜色种数
var board: Array[Array]  # board[y][x] = color_index
var grid_size:= Vector2i(10, 8)

var steps :int
var loaded_file: String

var nodes: Array[SimpleNode]
const CIRCLE = preload('res://circle.tscn')
const LINE = preload('res://line.tscn')
@onready var circles_root := Node2D.new()
@onready var lines_root   := Node2D.new()
var group := ButtonGroup.new()
var select_color_index: int

# 当前被拖拽的节点
var dragging_node: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_dialog.file_selected.connect(_do_load)
	add_child(lines_root)
	add_child(circles_root)
	_do_load(r"E:\work\godot_project\color_painting\Data\2.txt")
	set_process_input(true)
	init_colors()

func init_colors() -> void:
	for i in color_count:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.focus_mode = Control.FOCUS_CLICK
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
		btn.toggled.connect(_on_color_toggled.bind(i))
		color_palette.add_child(btn)
	var btns = group.get_buttons()
	group.get_buttons()[0].button_pressed = true
	group.get_buttons()[0].grab_focus()

func _on_color_toggled(pressed: bool, color_idx: int) -> void:
	if pressed:
		select_color_index = color_idx

func _input(event: InputEvent) -> void:
	# 左键染色
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		var hit := _pick_node(pos)
		if hit and hit is Node2D:	  # 也可额外 is_in_group("draggable")
			for node in nodes:
				if node.circle == hit:
					flood_merge(node, select_color_index, nodes)
					break
					
	# 拾取节点
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var pos := get_global_mouse_position()
		var hit := _pick_node(pos)
		if hit and hit is Node2D:	  # 也可额外 is_in_group("draggable")
			dragging_node = hit
			drag_offset   = hit.global_position - pos

	# 放下节点
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		dragging_node = null

	# 鼠标移动：实时更新节点位置
	elif dragging_node and event is InputEventMouseMotion:
		dragging_node.global_position = get_global_mouse_position() + drag_offset
		# 吃掉事件防止穿透
		get_viewport().set_input_as_handled()
		
# 用物理射线检测当前鼠标下的 Node2D（高速移动也不丢）
func _pick_node(pos: Vector2) -> Node2D:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collision_mask = 0xFFFFFFFF
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var result := space.intersect_point(params, 1)
	if result.size() > 0:
		# 返回第一个碰撞到的 Node2D
		return result[0].collider as Node2D
	return null

# 全局函数：染色并合并
func flood_merge(node: SimpleNode, new_color: int, all_nodes: Array[SimpleNode]) -> void:
	if node.color == new_color:
		return  # 同色无需处理

	steps += 1
	update_ui()
	node.color = new_color
	node.circle.set_color(PALETTE[new_color])

	# 收集所有要合并的邻居（同色、已连通）
	var to_merge: Array[SimpleNode] = []
	_collect_same_color_neighbors(node, node.color, to_merge)

	if to_merge.is_empty():
		return

	# 1. 合并 cells
	for m in to_merge:
		node.cells.append_array(m.cells)

	# 2. 合并 links（去重）
	for m in to_merge:
		node.links.erase(m)
		node.add_links_unique(m.links)

	# 3. 把被合并节点的 links 指向新的唯一节点
	for m in to_merge:
		for peer in m.links:
			if peer == node or to_merge.has(peer):
				continue
			# 把原来连到 m 的边，改成连到 node
			var idx = peer.links.find(m)
			if idx != -1:
				peer.links[idx] = node
				node.add_links_unique([peer])

	# 4. 从全局列表移除 & 销毁
	for m in to_merge:
		all_nodes.erase(m)
		m.circle.queue_free()   # 如果 SimpleNode 是 Node

	# 5. 清理自环
	node.links.erase(node)
	for n in nodes:
		n.links_unique_check()
		
	respawn_lines()

func _collect_same_color_neighbors(root: SimpleNode, target_color: int, out: Array[SimpleNode]) -> void:
	for link in root.links:
		if link.color == target_color:
			out.append(link)
	#var visited := {}
	#var stack := root.links.duplicate()
	#while not stack.is_empty():
		#var n = stack.pop_back()
		#if visited.has(n) or n.color != target_color:
			#continue
		#visited[n] = true
		#out.append(n)
		#stack.append_array(n.links)
		
func _on_load_pressed() -> void:
	load_dialog.popup_centered_ratio(0.4)

func _do_load(path: String) -> void:
	loaded_file = path
	do_load(path)
	
func do_load(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	var lines := file.get_as_text().split("\n", false)
	file.close()

	#grid_size = lines.size()
	steps = 0
	board = []
	for y in grid_size.y:
		board.append([])
		var cols := lines[y].split(",", true, 0)
		if cols.size() != grid_size.x:
			push_error("列数不符"); return
		for x in grid_size.x:
			board[y].append(int(cols[x]))
			
	nodes = board_to_nodes(board, grid_size)
	print("共 %d 个同色连通块" % nodes.size())
	for n in nodes:
		print("颜色 %d，格子数 %d" % [n.color, n.cells.size()])
	spawn_circles_and_lines(nodes, 64)   # 32 像素一格
	update_ui()

# 输入：board[y][x] = color_index
# 返回：Array[SimpleNode]  每个元素是一个连通块
func board_to_nodes(board: Array[Array], size: Vector2i) -> Array[SimpleNode]:
	var visited: Array[Array] = []
	for y in size.y:
		var new = []
		visited.append(new)
		for x in size.x:
			new.append(false)

	var nodes: Array[SimpleNode] = []

	# 四方向
	var DIR := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	for y in size.y:
		for x in size.x:
			if visited[y][x]:
				continue
			# 新连通块
			var node := SimpleNode.new()
			node.color = board[y][x]

			# BFS 收集所有同色邻居
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			visited[y][x] = true

			while not queue.is_empty():
				var p :Vector2i= queue.pop_front()
				node.cells.append(p)

				for d in DIR:
					var np :Vector2i= p + d
					if np.x < 0 or np.x >= size.x or np.y < 0 or np.y >= size.y:
						continue
					if not visited[np.y][np.x] and board[np.y][np.x] == node.color:
						visited[np.y][np.x] = true
						queue.append(np)

			nodes.append(node)

	# 建立 links（两块相邻且颜色相同就连一条无向边）
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			#if nodes[i].color != nodes[j].color:
				#continue
			# 任意一对坐标是否曼哈顿相邻
			for a in nodes[i].cells:
				for b in nodes[j].cells:
					if (a.x == b.x && absi(a.y-b.y)==1) || (a.y == b.y && absi(a.x-b.x)==1):
						if not nodes[i].links.has(nodes[j]):
							nodes[i].links.append(nodes[j])
							nodes[j].links.append(nodes[i])

	return nodes


# 输入：simple_nodes 来自 board_to_nodes()
# cell_size: 单格像素大小（例如 32）
func spawn_circles_and_lines(simple_nodes: Array[SimpleNode], cell_size: int) -> void:
	# 先清空旧实例
	for i in range(circles_root.get_child_count()):
		circles_root.get_child(i).queue_free()
	for i in range(lines_root.get_child_count()):
		lines_root.get_child(i).queue_free()

	var screenCenter = Vector2(370, 180) # get_viewport().get_visible_rect().get_center()
	# 1. 创建圆圈
	for sn in simple_nodes:
		var c := CIRCLE.instantiate()
		var center := Vector2.ZERO
		# 质心坐标 = 所有格子坐标的平均 * 像素尺寸
		#for cell in sn.cells:
			#center += Vector2(cell) + Vector2(0.5, 0.5)
		#center /= sn.cells.size()
		
		center = sn.cells[0]
		center *= cell_size
		c.global_position = center + screenCenter
		c.set_meta("simple_node", sn)   # 方便反向查找
		circles_root.add_child(c)
		c.set_color(PALETTE[sn.color])
		sn.circle = c

	# 2. 创建连线（无向图，防止重复）
	spawn_lines(simple_nodes)
	
func spawn_lines(simple_nodes: Array[SimpleNode]):
	var done: Dictionary = {}
	for sn in simple_nodes:
		for peer in sn.links:
			var id = min(sn.get_instance_id(), peer.get_instance_id())
			var id2 = max(sn.get_instance_id(), peer.get_instance_id())
			var key := "%d_%d" % [id, id2]
			if done.has(key):
				continue
			done[key] = true
			var line := LINE.instantiate()
			line.LinkA = sn.circle
			line.LinkB = peer.circle
			lines_root.add_child(line)

func respawn_lines():
	for i in range(lines_root.get_child_count()):
		lines_root.get_child(i).queue_free()
	spawn_lines(nodes)

func update_ui():
	steps_lbl.text = "步数: %d" % steps


func _on_restart_button_up() -> void:
	if loaded_file != null:
		do_load(loaded_file)
