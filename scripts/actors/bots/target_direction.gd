# 目标方向控制节点：结合视线检测与导航路径，计算AI移动方向
class_name TargetDirection  # 定义类名，可在场景中作为目标方向控制节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 目标检测节点（获取当前追踪的目标）
@export var target_finder:TargetFinder  
## 机器人输入节点（设置移动轴方向）
@export var bot_input:BotInput  
## 射线检测节点（用于视线遮挡检测）
@export var raycast:RayCast2D  
## 瓷砖导航节点（计算并追踪导航路径）
@export var tile_navigation:TileNavigationGetter  

## 重新计算导航的距离阈值（目标移动超过此距离时触发导航更新）
@export var retarget_distance:float = 16.0  
## 直线路径允许的最大距离（超过此距离不允许直接朝向目标）
@export var straight_path_distance:float = 16.0 * 5.0  
## 调试模式开关（启用时输出调试信息）
@export var debug:bool  

# -------------------- 成员变量（运行时状态） --------------------
## 从AI到目标的方向向量（世界坐标）
var target_direction:Vector2  
## 目标最后一次的位置（用于导航更新）
var last_target_position:Vector2  
## 上次导航更新的时间（控制冷却）
var last_update_time:float  
## 导航更新的冷却时间（秒）
var navigation_cooldown:float = 1.0  
## 是否允许直线路径（绕过导航，直接朝向目标）
var allow_straight_path:bool = false  
## 角色移动属性资源（包含最大速度等参数）
var actor_stats:ActorStatsResource  


# -------------------- 生命周期方法（节点准备完成） --------------------
func _ready()->void:
	if target_finder == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TargetDirection: 目标检测节点（target_finder）未配置，方向控制初始化失败", LogManager.LogLevel.ERROR)
		return
	if raycast == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TargetDirection: 射线检测节点（raycast）未配置，方向控制初始化失败", LogManager.LogLevel.ERROR)
		return
	if tile_navigation == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TargetDirection: 瓷砖导航节点（tile_navigation）未配置，方向控制初始化失败", LogManager.LogLevel.ERROR)
		return
	
	# 连接目标更新信号（目标变更时触发方向计算）
	if !target_finder.target_update.is_connected(_on_target_update):
		target_finder.target_update.connect(_on_target_update)
	
	# 从机器人输入节点的资源节点中获取移动属性资源
	var _resource_node:ResourceNode = bot_input.resource_node
	if _resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TargetDirection: 资源节点（resource_node）为空", LogManager.LogLevel.ERROR)
		return
	actor_stats = _resource_node.get_resource("movement")
	if actor_stats == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "TargetDirection: 移动资源节点（movement）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()


# -------------------- 方向设置方法（输出移动方向） --------------------
## @brief 设置AI的移动方向（考虑轴补偿并归一化）
## @param direction 原始方向向量（世界坐标）
func set_direction(direction:Vector2)->void:
	# 应用轴补偿（调整不同轴的移动速度差异），并归一化方向向量
	bot_input.input_resource.set_axis((direction * bot_input.axis_compensation).normalized())


# -------------------- 目标更新回调（核心方向计算逻辑） --------------------
## @brief 当目标检测结果更新时，计算AI的移动方向
func _on_target_update()->void:
	# 无目标时停止移动（方向设为零）
	if target_finder.target_count < 1:
		set_direction(Vector2.ZERO)
		return
	# 计算从AI到目标的方向向量（世界坐标）
	target_direction = target_finder.closest.global_position - bot_input.global_position
	
	# 测试视线是否被阻挡：若未被阻挡，直接朝向目标移动
	if _test_line_of_sight():
		set_direction(target_direction)
		return
	
	# 视线被阻挡时，通过导航路径获取下一个目标点，并设置方向
	_navigation_update()  # 触发导航路径更新（根据冷却时间）
	var point:Vector2 = tile_navigation.get_next_path_position(bot_input.global_position)  # 获取下一个路径点
	var direction:Vector2 = (point - bot_input.global_position)  # 计算到路径点的方向
	set_direction(direction)  # 设置移动方向


# -------------------- 视线检测方法（判断是否可直接朝向目标） --------------------
## @brief 使用射线检测判断AI到目标的视线是否被环境阻挡
## @return true 视线畅通（可直线路径），false 视线被阻挡（需导航）
func _test_line_of_sight()->bool:
	# 设置射线检测的目标位置（相对于射线起点的本地坐标）
	raycast.target_position = target_direction
	raycast.force_raycast_update()  # 强制更新射线检测结果
	
	var _is_line_of_sight:bool = !raycast.is_colliding()  # 未碰撞表示视线畅通
	# 视线被阻挡时，禁止直线路径
	if !_is_line_of_sight:
		allow_straight_path = false
	
	# 导航路径为空、已到达终点或无后续路径点时，直接返回视线状态
	if tile_navigation.navigation_path.is_empty():
		return _is_line_of_sight
	if tile_navigation.finish_reached:
		return _is_line_of_sight
	if !(tile_navigation.index < tile_navigation.navigation_path.size() - 1):
		return _is_line_of_sight
	
	# 视线畅通且满足条件时，允许直线路径（优化路径转向）
	if _is_line_of_sight && !allow_straight_path && tile_navigation.point_reached:
		# 将目标方向转换为瓷砖网格方向（取整后）
		var _target_tile_direction:Vector2 = (target_direction / tile_navigation.astargrid_resource.value.cell_size).round()
		# 获取当前路径点与下一个路径点的瓷砖方向
		var _point_direction:Vector2 = tile_navigation.tile_path[tile_navigation.index + 1] - tile_navigation.tile_path[tile_navigation.index]
		# 计算方向点积（判断是否同方向）
		var _dot_product:float = _target_tile_direction.normalized().dot(_point_direction.normalized())
		
		# 点积大于0.5表示方向接近，允许直线路径
		if _dot_product > 0.5:
			allow_straight_path = true
	
	return allow_straight_path  # 返回是否允许直线路径


# -------------------- 导航更新方法（控制路径计算频率） --------------------
## @brief 根据冷却时间更新导航路径（避免频繁计算）
func _navigation_update()->void:
	var current_time:float = Time.get_ticks_msec() * 0.001  # 当前时间（秒）
	
	# 未到冷却时间时跳过更新
	if last_update_time + navigation_cooldown > current_time:
		return
	
	last_update_time = current_time  # 记录本次更新时间
	last_target_position = target_finder.closest.global_position  # 记录目标当前位置
	
	# 计算到目标当前位置的导航路径（通过瓷砖导航节点）
	tile_navigation.get_target_path(last_target_position)
	
	# 根据路径长度和移动速度调整冷却时间（路径越长，冷却时间越长）
	var nav_length:float = GameMath.packed_vector2_length(tile_navigation.navigation_path)  # 路径总长度
	var _move_time:float = 0.0
	if actor_stats.max_speed > 0.0:
		_move_time = nav_length / actor_stats.max_speed  # 移动完路径所需时间
	
	# 冷却时间限制在1~3秒（避免过短或过长）
	navigation_cooldown = clamp(_move_time, 1.0, 3.0)
