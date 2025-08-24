extends Node
class_name FloodSolver

# 返回最少步数；若不可达返回 -1
static func min_steps(nodes: Array[SimpleFillGame.SimpleNode], target_color: int) -> int:
	# ---------- 1. 把颜色数组变成可哈希的元组 ----------
	var n := nodes.size()
	var start := _pack_colors(nodes)		  # PackedInt32Array

	# 若已全同色
	if _is_uniform(start, target_color):
		return 0

	# ---------- 2. 广度优先 ----------
	var queue := [[start, 0]]				 # [state, depth]
	var seen := {start: true}

	while not queue.is_empty():
		var current = queue.pop_front()
		var state = current[0]
		var depth = current[1]

		# 枚举当前状态下所有可染的 SimpleNode
		for idx in n:
			var old_color = state[idx]
			# 枚举所有 **不同** 颜色
			for new_color in range(4):		# 4 种颜色
				if new_color == old_color:
					continue

				var next_state = state.duplicate()
				# 把 idx 及其连通同色块全部染成 new_color
				_flood_fill_in_state(nodes, next_state, idx, new_color)

				if _is_uniform(next_state, target_color):
					return depth + 1

				if not seen.has(next_state):
					seen[next_state] = true
					queue.append([next_state, depth + 1])
	return -1

# ---------- 工具 ----------
static func _pack_colors(nodes: Array[SimpleFillGame.SimpleNode]) -> PackedInt32Array:
	var a := PackedInt32Array()
	for n in nodes:
		a.append(n.color)
	return a

static func _is_uniform(packed: PackedInt32Array, col: int) -> bool:
	for c in packed:
		if c != col:
			return false
	return true

# 在“状态数组”里做 BFS flood-fill
static func _flood_fill_in_state(nodes: Array[SimpleFillGame.SimpleNode], state: PackedInt32Array,
								 root_idx: int, new_color: int) -> void:
	var old_color := state[root_idx]
	if old_color == new_color:
		return

	var n := nodes.size()
	var visited := PackedByteArray()
	visited.resize(n)
	for i in n:
		visited[i] = 0

	var queue := [root_idx]
	visited[root_idx] = 1

	while not queue.is_empty():
		var idx = queue.pop_front()
		state[idx] = new_color
		for peer in nodes[idx].links:
			var peer_idx := nodes.find(peer)
			if peer_idx == -1 or visited[peer_idx] == 1:
				continue
			if state[peer_idx] == old_color:
				visited[peer_idx] = 1
				queue.append(peer_idx)

# 返回 [int 步数, Array[Dictionary] 步骤]；若不可达返回 [-1, []]
static func min_steps_with_path(nodes: Array[SimpleFillGame.SimpleNode], target_color: int) -> Array:
	# 把颜色数组变成 PackedInt32Array 以便哈希
	var n := nodes.size()
	var start := _pack_colors(nodes)

	if _is_uniform(start, target_color):
		return [0, []]

	# 队列元素：[state, depth, path]
	var queue := [[start, 0, []]]
	var seen := {start: true}

	while not queue.is_empty():
		var current = queue.pop_front()
		var state   = current[0]
		var depth   = current[1]
		var path	= current[2]

		for idx in n:
			var old_color = state[idx]
			for new_color in range(4):
				if new_color == old_color:
					continue

				var next_state = state.duplicate()
				_flood_fill_in_state(nodes, next_state, idx, new_color)

				var step_info := {
					"step"	  = depth + 1,
					"node_idx"  = idx,
					"new_color" = new_color
				}
				var new_path = path.duplicate()
				new_path.append(step_info)

				if _is_uniform(next_state, target_color):
					return [depth + 1, new_path]

				if not seen.has(next_state):
					seen[next_state] = true
					queue.append([next_state, depth + 1, new_path])

	return [-1, []]   # 无解
