# 定义用于自动配置 A* 导航网格的节点工具类
class_name TileNavigationSetter
extends Node

# 导出的 TileMapLayer 引用，用于获取地图数据和区域信息
@export var tilemap_layer: TileMapLayer

# 导出的 AstarGridResource 引用，用于存储和管理 A* 网格配置
@export var astargrid_resource: AstarGridResource

## 定义导航网格区域的扩展范围（单位：单元格数），用于扩大计算区域，"示例：设为 2 表示向上下左右各扩展 2 格"
@export var grow_region: int = 1

# 节点初始化时自动执行
func _ready() -> void:
	# 确保 TileMapLayer 和 AstarGridResource 已正确赋值
	assert(tilemap_layer != null)
	assert(astargrid_resource != null)
	# 初始化 A* 导航网格
	initialize_astargrid()


# 核心方法：初始化 A* 导航网格
func initialize_astargrid() -> void:
	# 如果资源已初始化，直接返回避免重复操作
	if astargrid_resource.value != null:
		return

	# 将 TileMapLayer 关联到资源（可能用于后续动态更新）
	astargrid_resource.tilemap_layer = tilemap_layer

	# 获取 TileMapLayer 的已使用区域，并扩展边界
	var _tile_rect: Rect2i = tilemap_layer.get_used_rect()
	_tile_rect = _tile_rect.grow(grow_region)

	# 创建 AStarGrid2D 实例
	var _astar: AStarGrid2D = AStarGrid2D.new()
	_astar.region = _tile_rect            # 设置网格区域

	# 根据 TileSet 配置网格参数
	var _tileset: TileSet = tilemap_layer.tile_set
	_astar.cell_size = _tileset.tile_size # 单元格尺寸匹配 Tile 大小
	_astar.offset = Vector2.ZERO          # 网格偏移归零

	# 根据 TileSet 形状设置 A* 网格的单元格形状
	if _tileset.tile_shape == TileSet.TileShape.TILE_SHAPE_SQUARE:
		_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_SQUARE
	elif _tileset.tile_shape == TileSet.TileShape.TILE_SHAPE_ISOMETRIC:
		# 处理等距菱形布局方向
		if _tileset.tile_layout == TileSet.TileLayout.TILE_LAYOUT_DIAMOND_RIGHT:
			_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_ISOMETRIC_RIGHT
		elif _tileset.tile_layout == TileSet.TileLayout.TILE_LAYOUT_DIAMOND_DOWN:
			_astar.cell_shape = AStarGrid2D.CellShape.CELL_SHAPE_ISOMETRIC_DOWN

	# 将配置好的 A* 网格注入资源
	astargrid_resource.set_value(_astar)
	# 绑定节点退出场景树时的清理操作
	tree_exiting.connect(astargrid_resource.cleanup)
