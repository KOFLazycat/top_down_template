# 基于 TileMap 图层的自定义数据动态生成场景实例的工具节点
class_name TileSpawner  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 需要读取的 TileMap 图层（存储图块及自定义数据）
@export var tilemap_layer:TileMapLayer

## 父节点引用资源（用于指定生成的实例的父节点）
@export var parent_reference:ReferenceNodeResource

## 自定义数据层名称（TileSet 中存储场景路径的层）
@export var data_layer_name:String


# -------------------- 成员变量（运行时状态） --------------------

## 缓存 TileSet 中所有自定义数据层的名称（用于快速查询）
var tile_data_names:Array[String]

## 缓存 TileMap 图层中所有被使用的单元格位置（Vector2i 数组）
var tiles:Array[Vector2i]

## 标志位：当前 TileSet 是否包含指定的自定义数据层（data_layer_name）
var has_data:bool


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()->void:
	# 断言：确保父引用资源已配置（未配置会触发运行时错误）
	assert(parent_reference != null)

	# -------------------- 步骤1：缓存 TileSet 自定义数据层名称 --------------------
	# 获取 TileSet 中自定义数据层的数量（每个层可存储不同类型的自定义数据）
	var _tile_data_count:int = tilemap_layer.tile_set.get_custom_data_layers_count()
	# 调整数组大小以存储所有数据层名称（避免动态扩容开销）
	tile_data_names.resize(_tile_data_count)
	# 遍历所有自定义数据层，缓存名称到 tile_data_names 数组
	for i:int in _tile_data_count:
		tile_data_names[i] = tilemap_layer.tile_set.get_custom_data_layer_name(i)

	# 检查是否存在目标数据层（data_layer_name）
	has_data = tile_data_names.has(data_layer_name)
	# 若不存在目标数据层，直接返回（无需后续逻辑）
	if !has_data:
		return

	# -------------------- 步骤2：监听父节点引用变更 --------------------
	# 注册父引用资源的监听器：当父节点引用变更时，触发 _on_parent_updated 回调
	# 参数说明：
	#   self：当前节点实例（用于自动清理监听器，当当前节点退出场景树时移除监听）
	#   _on_parent_updated：回调函数（父节点引用变更时执行）
	parent_reference.listen(self, _on_parent_updated)


# -------------------- 回调方法（父节点引用变更时触发） --------------------
func _on_parent_updated()->void:
	# 若父节点引用为空（未绑定有效节点），直接返回
	if parent_reference.node == null:
		return
	# 若当前 TileSet 不包含目标数据层，直接返回
	if !has_data:
		return

	# -------------------- 步骤3：缓存 TileMap 中使用的单元格 --------------------
	# 获取 TileMap 图层中所有被使用的单元格位置（即有图块的单元格）
	tiles = tilemap_layer.get_used_cells()

	# -------------------- 步骤4：遍历单元格生成场景实例 --------------------
	# 注意：此处声明了 _scene_cache 但未初始化（潜在问题，后续优化建议中说明）
	var _scene_cache:Dictionary = {}  # 用于缓存已加载的场景（避免重复加载）

	# 遍历所有使用中的单元格
	for i:int in tiles.size():
		var _tile_pos:Vector2i = tiles[i]  # 当前单元格的网格坐标（如 (2,3)）

		# 获取当前单元格的 TileData（存储图块属性和自定义数据）
		var _tile_data:TileData = tilemap_layer.get_cell_tile_data(_tile_pos)
		if _tile_data == null:
			#Log.entry("单元格 %s 未设置 TileData，跳过实例生成" % _tile_pos, LogManager.LogLevel.ERROR)
			continue  # 无 TileData 时跳过

		# 从 TileData 的自定义数据层中获取场景文件路径（如 "res://enemy.tscn"）
		var _file_path:String = _tile_data.get_custom_data(data_layer_name)
		# 若路径为空，跳过当前单元格
		if _file_path.is_empty():
			continue

		# -------------------- 步骤5：加载场景并生成实例 --------------------
		# 注意：原代码未初始化 _scene_cache，此处会导致空字典无法缓存（需优化）
		# 检查场景是否已缓存（避免重复加载）
		if not _scene_cache.has(_file_path):
			# 加载 PackedScene 场景资源（若路径无效会触发错误）
			if not ResourceLoader.exists(_file_path):
				Log.entry("场景路径 %s 不存在，跳过实例生成" % _file_path, LogManager.LogLevel.ERROR)
				continue
			
			var _scene:PackedScene = load(_file_path)
			if not _scene.is_class("PackedScene"):
				Log.entry("%s 不是有效的 PackedScene 资源，跳过实例生成" % _file_path, LogManager.LogLevel.ERROR)
				continue
			_scene_cache[_file_path] = _scene  # 缓存已加载的场景

		# 将单元格的网格坐标转换为本地坐标（基于 TileMap 的位置和缩放）
		var _pos:Vector2 = tilemap_layer.map_to_local(_tile_pos)
		# 实例化场景（生成 Node2D 类型的子节点）
		var _instance:Node2D = _scene_cache[_file_path].instantiate()
		# 设置实例的全局位置（确保与 TileMap 单元格位置对齐）
		_instance.global_position = _pos
		# 延迟将实例添加到父节点（避免在遍历中修改节点树导致的异常）
		parent_reference.node.add_child.call_deferred(_instance)
