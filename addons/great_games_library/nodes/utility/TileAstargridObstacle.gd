# 基于 TileMap 自定义数据动态设置 A* 寻路网格障碍物的工具节点
class_name TileAstargridObstacle  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 需要读取的 TileMap 图层（存储图块及自定义数据）
@export var tilemap_layer:TileMapLayer

## 目标寻路资源（存储和管理 A* 寻路网格实例）
@export var astargrid_resource:AstarGridResource

## 自定义数据层名称（存储图块碰撞偏移量的层，默认 "collider_offset"）
@export var data_name:String = "collider_offset"


# -------------------- 成员变量（运行时状态） --------------------

## 缓存 TileMap 图层中所有被使用的单元格坐标（Vector2i 数组）
var tiles:Array[Vector2i]
## 新增：缓存所有偏移后的障碍物坐标
var obstacle_positions:Array[Vector2i]
## 新增：缓存数据层是否存在
var has_offset:bool  


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()-> void:
	if astargrid_resource == null:
		Log.entry("AstarGridResource 未正确设置！", LogManager.LogLevel.ERROR)
		return
	
	# -------------------- 步骤1：检查自定义数据层是否存在 --------------------
	## 获取 TileSet 中自定义数据层的数量
	#var _tile_data_count:int = tilemap_layer.tile_set.get_custom_data_layers_count()
	## 缓存所有自定义数据层名称（用于快速查询）
	#var _tile_data_names:Array[String]
	#_tile_data_names.resize(_tile_data_count)
	#for i:int in _tile_data_count:
		#_tile_data_names[i] = tilemap_layer.tile_set.get_custom_data_layer_name(i)
	## 检查是否存在目标数据层（data_name）
	#has_offset = _tile_data_names.has(data_name)
	has_offset = tilemap_layer.tile_set.has_custom_data_layer_by_name(data_name)

	# 连接寻路资源的 "updated" 信号（资源更新时触发障碍物设置）
	astargrid_resource.updated.connect(setup_obstacles)

	# 延迟调用 setup_obstacles（避免在节点初始化阶段立即执行）
	setup_obstacles.call_deferred()

	# 连接当前节点的 "tree_exiting" 信号（节点退出场景树时触发清理）
	tree_exiting.connect(cleanup)

	# 连接寻路资源的 "cleaned_up" 信号（资源清理时触发清理）
	astargrid_resource.cleaned_up.connect(cleanup)


# -------------------- 核心方法（设置 A* 网格障碍物） --------------------
func setup_obstacles()->void:
	# 若寻路资源未绑定有效网格实例，直接返回
	if astargrid_resource.value == null:
		return
	
	# 若不存在目标数据层，直接返回（无需设置障碍物）
	if has_offset == false:
		return

	# 清理旧的障碍物（避免重复标记）
	cleanup()

	# 获取寻路资源中的 A* 网格实例
	var _astar:AStarGrid2D = astargrid_resource.value

	# -------------------- 步骤2：获取所有使用中的单元格 --------------------
	# 获取 TileMap 图层中所有被使用的单元格坐标（即放置了图块的单元格）
	tiles = tilemap_layer.get_used_cells()

	# -------------------- 步骤3：获取物理空间与实例ID（用于物理服务器操作） --------------------
	## 获取当前 TileMap 所在的 2D 物理空间 RID（用于物理服务器操作）
	#var _space:RID = tilemap_layer.get_world_2d().space
	## 获取当前节点的实例ID（用于唯一标识）
	#var _id:int = get_instance_id()
	## 设置物理体模式（运动学模式，确保与 Area2D 正确交互）
	#var _body_mode:PhysicsServer2D.BodyMode = PhysicsServer2D.BODY_MODE_KINEMATIC

	# -------------------- 步骤4：遍历单元格并设置障碍物 --------------------
	# 遍历所有使用中的单元格
	for i:int in tiles.size():
		var _tile_pos:Vector2i = tiles[i]  # 当前单元格的网格坐标

		# 获取当前单元格的 TileData（存储图块属性和自定义数据）
		var _tile_data:TileData = tilemap_layer.get_cell_tile_data(_tile_pos)
		if _tile_data == null:
			continue  # 无 TileData 时跳过

		# 从自定义数据层中获取偏移量列表（类型为 PackedVector2Array）
		var _offset_list:PackedVector2Array
		if has_offset:
			_offset_list = _tile_data.get_custom_data(data_name)
		
		if _offset_list == null || !(_offset_list is PackedVector2Array):
			Log.entry("单元格 %s 的自定义数据层 {data_name} 无有效偏移量，跳过" % _tile_pos, LogManager.LogLevel.INFO)
			continue

		# 遍历偏移量列表（每个偏移量对应一个障碍物点）
		for _offset:Vector2 in _offset_list:
			# 计算偏移后的单元格坐标（原坐标 + 偏移量）
			var _tile_pos_off:Vector2i = _tile_pos + Vector2i(_offset)

			# 断言：确保偏移后的坐标在 A* 网格的区域范围内（避免越界）
			assert(_astar.region.has_point(_tile_pos_off))
			
			# 缓存偏移后的坐标
			obstacle_positions.append(_tile_pos_off)
			# 将偏移后的坐标标记为障碍物（solid = true）
			_astar.set_point_solid(_tile_pos_off, true)

	# 更新 A* 网格（确保配置生效）
	_astar.update()


# -------------------- 清理方法（移除 A* 网格中的障碍物） --------------------
func cleanup() -> void:
	# 若寻路资源未绑定有效网格实例，直接返回
	if astargrid_resource.value == null:
		return
	
	for _pos in obstacle_positions:
		astargrid_resource.value.set_point_solid(_pos, false)
	obstacle_positions.clear()  # 清空缓存
