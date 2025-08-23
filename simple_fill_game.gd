extends Node2D

class SimpleNode:
	var color: int
	var links: Array[SimpleNode] = []
	var cells: Array[Vector2i] = []      # 额外记录所有格子坐标，方便调试

const PALETTE = [
	Color("#118ab2"),
	Color("#ef476f"), 
	Color("#ffd166"),
	Color("#06d6a0"), 
	Color("#073b4c"), Color("#ffffff")
]

@onready var load_dialog: FileDialog = $EditUI/LoadDialog
var board: Array[Array]  # board[y][x] = color_index
var grid_size: int
var nodes: Array[SimpleNode]
var lines: Array
const CIRCLE = preload('res://circle.tscn')
const LINE = preload('res://line.tscn')
@onready var circles_root := Node2D.new()
@onready var lines_root   := Node2D.new()

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

func _input(event: InputEvent) -> void:
	# 左键按下：拾取节点
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var pos := get_global_mouse_position()
		var hit := _pick_node(pos)
		if hit and hit is Node2D:	  # 也可额外 is_in_group("draggable")
			dragging_node = hit
			drag_offset   = hit.global_position - pos

	# 左键松开：放下节点
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

func _on_load_pressed() -> void:
	load_dialog.popup_centered_ratio(0.4)
	
func _do_load(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	var lines := file.get_as_text().split("\n", false)
	file.close()

	grid_size = lines.size()
	for y in grid_size:
		board.append([])
		var cols := lines[y].split(",", true, 0)
		if cols.size() != grid_size:
			push_error("列数不符"); return
		for x in grid_size:
			board[y].append(int(cols[x]))
			
	var simple_nodes := board_to_nodes(board, grid_size)
	print("共 %d 个同色连通块" % simple_nodes.size())
	for n in simple_nodes:
		print("颜色 %d，格子数 %d" % [n.color, n.cells.size()])
	spawn_circles_and_lines(simple_nodes, 64)   # 32 像素一格

# 输入：board[y][x] = color_index
# 返回：Array[SimpleNode]  每个元素是一个连通块
func board_to_nodes(board: Array[Array], size: int) -> Array[SimpleNode]:
	var visited: Array[Array] = []
	for y in size:
		var new = []
		visited.append(new)
		for x in size:
			new.append(false)

	var nodes: Array[SimpleNode] = []

	# 四方向
	var DIR := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	for y in size:
		for x in size:
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
					if np.x < 0 or np.x >= size or np.y < 0 or np.y >= size:
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
	#circles_root.queue_free_all_children()
	#lines_root.queue_free_all_children()

	var screenCenter = get_viewport().get_visible_rect().get_center()
	# 1. 创建圆圈
	var node_to_circle: Dictionary = {}  # SimpleNode → Circle Node2D
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
		node_to_circle[sn] = c

	# 2. 创建连线（无向图，防止重复）
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
			line.LinkA = node_to_circle[sn]
			line.LinkB = node_to_circle[peer]
			lines_root.add_child(line)
