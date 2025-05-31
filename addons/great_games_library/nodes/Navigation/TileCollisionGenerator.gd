@tool  # 标记为工具脚本，允许在编辑器中实时生效
## 收集图块障碍物并生成碰撞体，用于导航路径计算的工具节点
class_name TileCollisionGenerator  # 定义类名，可在编辑器中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 是否在编辑器中生成碰撞体（切换时触发更新）
@export var generate_colliders:bool : set = set_generate_colliders

## 需要读取的 TileMap 图层（存储图块及自定义碰撞偏移量数据）
@export var tilemap_layer:TileMapLayer

## 用于承载碰撞体的 StaticBody2D 节点
@export var static_body:StaticBody2D

## 碰撞体的基础形状（如多边形，需提前在编辑器中配置顶点）
@export var tile_shape:Shape2D

## 自定义数据层名称（存储图块碰撞偏移量的层，类型为 PackedVector2Array）
@export var data_name:String = "collider_offset"


# -------------------- 工具方法（编辑器中生成/清理碰撞体） --------------------

## 设置生成状态的回调方法（导出变量 set 回调）
func set_generate_colliders(value:bool)->void:
	# 若节点不在场景树中或非编辑器环境，直接返回
	if !is_inside_tree():
		return
	if !Engine.is_editor_hint():
		return

	cleanup()  # 清理旧碰撞体
	setup_colliders()  # 生成新碰撞体


## 清理所有已生成的碰撞体
func cleanup() -> void:
	# 遍历 StaticBody2D 的子节点并销毁
	for child:Node in static_body.get_children():
		remove_child(child)
		child.queue_free()


## 核心方法：根据图块数据生成碰撞体
func setup_colliders()->void:
	if tilemap_layer == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TileCollisionGenerator: tilemap_layer 未配置", LogManager.LogLevel.ERROR)
		return
	if static_body == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TileCollisionGenerator: static_body 未配置", LogManager.LogLevel.ERROR)
		return
	if tile_shape == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TileCollisionGenerator: tile_shape 未配置", LogManager.LogLevel.ERROR)
		return
	# -------------------- 步骤1：检查自定义数据层是否存在 --------------------
	#var _tile_data_count:int = tilemap_layer.tile_set.get_custom_data_layers_count()
	#var _tile_data_names:Array[String] = []
	#_tile_data_names.resize(_tile_data_count)
	#for i:int in _tile_data_count:
		#_tile_data_names[i] = tilemap_layer.tile_set.get_custom_data_layer_name(i)
	#var _has_offset:bool = _tile_data_names.has(data_name)  # 检查目标数据层是否存在
	var _has_offset:bool = tilemap_layer.tile_set.has_custom_data_layer_by_name(data_name) # 检查目标数据层是否存在

	if !_has_offset:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TileCollisionGenerator: 目标数据层不存在", LogManager.LogLevel.ERROR)
		return

	# -------------------- 步骤2：收集所有需要生成碰撞体的图块坐标 --------------------
	var _tiles:Array[Vector2i] = tilemap_layer.get_used_cells()  # 获取所有使用中的单元格
	var _tile_pos_list:Array[Vector2i] = []  # 存储去重后的偏移坐标

	for i:int in _tiles.size():
		var _tile_pos:Vector2i = _tiles[i]
		var _tile_data:TileData = tilemap_layer.get_cell_tile_data(_tile_pos)
		if _tile_data == null:
			continue  # 无图块数据时跳过

		var _offset_list:PackedVector2Array = _tile_data.get_custom_data(data_name)
		for _offset:Vector2 in _offset_list:
			var _tile_pos_off:Vector2i = _tile_pos + Vector2i(_offset)
			if !_tile_pos_list.has(_tile_pos_off):
				_tile_pos_list.append(_tile_pos_off)  # 去重添加偏移后的坐标

	if _tile_pos_list.is_empty():
		return  # 无有效坐标时返回

	# -------------------- 步骤3：生成碰撞体节点并添加到 StaticBody2D --------------------
	for _tile_pos_off in _tile_pos_list:
		var _polygon_collider:CollisionPolygon2D = CollisionPolygon2D.new()
		_polygon_collider.name = "X" + str(_tile_pos_off.x) + "_Y" + str(_tile_pos_off.y)
		_polygon_collider.polygon = tile_shape.points  # 设置碰撞多边形顶点
		_polygon_collider.position = tilemap_layer.map_to_local(_tile_pos_off)  # 转换为本地坐标
		static_body.add_child(_polygon_collider)  # 添加子节点
		_polygon_collider.owner = owner  # 设置所有者


## 辅助方法：合并相邻图块（尝试生成连续碰撞体）
func _queue_neighbouring_tiles(pos_list:Array[Vector2i])->Array[Vector2i]:
	## 功能：收集相邻图块，确保碰撞体合并（未完全实现，存在逻辑问题）
	var _tile_queue:Array[Vector2i] = [pos_list.back()]  # 从列表末尾开始

	var _insert_index:int = 0
	var _size:int = pos_list.size()
	for q:int in range(_size):
		if _insert_index >= _tile_queue.size() && _insert_index > 0:
			break  # 无更多相邻图块

		var _tile:Vector2i = _tile_queue[_insert_index]
		pos_list.erase(_tile)  # 从列表中移除当前图块（危险操作，可能导致循环错误）

		_insert_index += 1  # 移动插入索引

		# 检查四个方向的相邻图块
		var _directions:Array[Vector2i] = [
			Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT
		]
		for _dir in _directions:
			var _neighbor:Vector2i = _tile + _dir
			if pos_list.has(_neighbor) && !_tile_queue.has(_neighbor):
				_tile_queue.insert(_insert_index, _neighbor)  # 插入相邻图块到队列

	return _tile_queue


## 辅助方法：对图块坐标进行排序（未正确实现，依赖未定义的 width）
func sort_tiles(a:Vector2i, b:Vector2i, width:int)->bool:
	## 功能：根据坐标计算索引排序（width 未定义，存在缺陷）
	var a_index:int = a.x + a.y * width
	var b_index:int = b.x + b.y * width
	return a_index > b_index  # 返回降序排序
