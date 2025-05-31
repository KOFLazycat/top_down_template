# 瓷砖导航路径获取节点：基于A*寻路网格计算导航路径并追踪当前位置
class_name TileNavigationGetter  # 定义类名，可在场景中作为导航路径计算节点使用
extends Line2D  # 继承自2D线条节点（用于可视化导航路径）


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 位置节点（用于获取当前导航起点位置）
@export var position_node:Node2D  
## A*寻路网格资源（包含寻路所需的瓷砖地图和网格数据）
@export var astargrid_resource:AstarGridResource  
## 到达点距离阈值（与路径点的距离小于此值时视为到达，单位：像素）
@export var reached_distance:float = 6.0  


# -------------------- 成员变量（运行时状态） --------------------
var navigation_path:PackedVector2Array  # 导航路径点数组（世界坐标，用于Line2D显示）
var tile_path:Array[Vector2i]            # 瓷砖路径数组（网格坐标，用于寻路逻辑）
var index:int = 0                        # 当前路径点索引（从1开始，0为起点）
var closest_point:Vector2  = Vector2.ZERO # 当前最近路径点
var finish_reached:bool = false          # 路径完成标志（是否到达终点）
var point_reached:bool = false           # 当前点到达标志（是否到达当前路径点）


# -------------------- 公有方法：设置路径完成标志（供外部控制） --------------------
func set_finish_reached(value:bool)->void:
	finish_reached = value  # 更新路径完成状态


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if position_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TileNavigationGetter: 位置节点（position_node）未配置", LogManager.LogLevel.ERROR)
		return
	if astargrid_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TileNavigationGetter: A*寻路网格资源 （astargrid_resource） 未配置", LogManager.LogLevel.ERROR)
		return
	## 设置线条为顶级节点（独立于父节点变换，保持世界坐标不变）
	top_level = true  
	global_position = Vector2.ZERO  # 初始化线条位置为原点（实际路径通过points属性更新）
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()


# -------------------- 核心逻辑：计算导航路径 --------------------
## @brief 计算从当前位置到目标位置的导航路径
## @param to 目标位置（世界坐标）
## @return 导航路径点数组（世界坐标）
func get_target_path(to:Vector2)->PackedVector2Array:
	# 将起点和终点从世界坐标转换为瓷砖网格坐标
	var _from_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(position_node.global_position)
	var _to_tile:Vector2i = astargrid_resource.tilemap_layer.local_to_map(to)
	
	# 使用A*网格计算路径（点路径和瓷砖ID路径）
	navigation_path = astargrid_resource.value.get_point_path(_from_tile, _to_tile)
	tile_path = astargrid_resource.value.get_id_path(_from_tile, _to_tile)
	
	# 初始化路径索引：若路径有效（点数>1），从第2个点开始（索引1），否则停留在起点（索引0）
	index = 1 if navigation_path.size() > 1 else 0
	
	finish_reached = false  # 重置完成标志
	
	# 若线条可见，更新线条的点数据以可视化路径
	if visible:
		points = navigation_path
	
	return navigation_path  # 返回导航路径点


# -------------------- 核心逻辑：获取下一个路径位置 --------------------
## @brief 根据当前位置获取下一个导航路径点
## @param from 当前位置（世界坐标）
## @return 下一个路径点（世界坐标）
func get_next_path_position(from:Vector2)->Vector2:
	if navigation_path.is_empty():  # 路径为空时返回当前位置
		return position_node.global_position
	
	## 计算当前位置与当前路径点的距离平方（避免开平方运算，提升性能）
	closest_point = navigation_path[index]
	var _closest_dist:float = (closest_point - from).length_squared()
	var _treshold:float = reached_distance * reached_distance  # 阈值平方（与距离平方比较）
	
	var i:int = index
	# 若当前点距离小于阈值且非终点，移动到下一个路径点
	if _closest_dist < _treshold && i < navigation_path.size() - 1:
		i += 1
		assert(i < navigation_path.size(), "路径索引越界")  # 断言校验索引有效性
		closest_point = navigation_path[i]
	
	# 更新到达状态
	if i != index:
		point_reached = true  # 已到达当前点，切换至下一点
		if index == navigation_path.size() - 1:  # 到达最后一个点时标记完成
			finish_reached = true
	elif !finish_reached:
		point_reached = false  # 未到达当前点
	
	index = i  # 更新当前索引
	assert(i < navigation_path.size(), "路径索引越界")  # 二次校验（确保安全）
	return closest_point  # 返回最近路径点
