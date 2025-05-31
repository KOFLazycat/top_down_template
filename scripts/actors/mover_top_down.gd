# 顶视角2D移动控制器：处理角色移动、碰撞检测、外力响应及轴补偿
class_name MoverTopDown  # 定义类名，可在场景中作为移动控制节点使用
extends ShapeCast2D  # 继承自形状投射节点（用于碰撞检测与移动）


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 控制物理处理是否启用（可在_ready后禁用功能）
@export var enabled_process:bool = true  
## 受控制的角色节点（需为CharacterBody2D子类）
@export var character:CharacterBody2D  
## 碰撞形状节点（用于获取形状尺寸和位置）
@export var collision_shape:CollisionShape2D  
## 最大碰撞检测次数（处理重叠时的迭代上限）
@export var max_collisions:int = 4  
## 轴乘数资源（模拟透视效果，调整不同轴的移动速度）
@export var axis_multiplier_resource:Vector2Resource  
## 资源节点（存储输入、移动属性等配置）
@export var resource_node:ResourceNode  
## 调试模式标记（显示碰撞信息等）
@export var debug:bool  


# -------------------- 常量与成员变量（运行时状态） --------------------
const MAX_SLIDES:int = 4  # 最大滑动迭代次数（处理碰撞反弹）
var input_resource:InputResource  # 输入资源（获取玩家输入轴）
var actor_stats_resource:ActorStatsResource  # 移动属性资源（速度、加速度等）
var velocity:Vector2 = Vector2.ZERO  # 当前移动速度
var axis_compensation:Vector2  # 轴补偿向量（用于抵消轴乘数的影响）
var shape_rect:Rect2  # 碰撞形状的矩形（半尺寸）

# -------------------- 状态控制方法（启用/禁用物理处理） --------------------
## @brief 启用/禁用物理处理（控制_physics_process是否执行）
func set_enabled_process(value:bool)->void:
	enabled_process = value
	set_physics_process(enabled_process)  # 根据enabled_process设置物理帧回调状态


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "MoverTopDown: 资源节点（resource_node）未配置，无法初始化", LogManager.LogLevel.ERROR)
		return
	# 禁用默认的ShapeCast2D碰撞检测（使用自定义碰撞处理）
	enabled = false
	# 从资源节点获取输入资源（确保非空）
	input_resource = resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "MoverTopDown: 输入资源（input）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 获取移动属性资源（速度、加速度等）
	actor_stats_resource = resource_node.get_resource("movement")
	if actor_stats_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "MoverTopDown: 移动属性资源（movement）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 获取推力资源并连接脉冲事件（如受到攻击时的击退效果）
	var _push_resource = resource_node.get_resource("push")
	if _push_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "MoverTopDown: 推力资源（push）未配置", LogManager.LogLevel.ERROR)
		return
	_push_resource.impulse_event.connect(add_impulse)
	
	# 初始化启用状态
	set_enabled_process(enabled_process)
	
	# 初始化碰撞形状信息
	shape = collision_shape.shape  # 设置ShapeCast2D的碰撞形状
	shape_rect = shape.get_rect()    # 获取形状矩形（全尺寸）
	shape_rect.size *= 0.5           # 转换为半尺寸（用于碰撞计算）
	position = collision_shape.position  # 同步位置到碰撞形状节点
	
	 # 配置碰撞掩码（与角色节点一致）
	collision_mask = character.collision_mask
	target_position = Vector2.ZERO
	velocity = Vector2.ZERO
	# 初始化轴补偿（用于抵消轴乘数的缩放影响）
	axis_compensation = Vector2.ONE / axis_multiplier_resource.value
	
	# 断开推力事件连接（在节点退出场景树时）
	tree_exiting.connect(_push_resource.impulse_event.disconnect.bind(add_impulse), CONNECT_ONE_SHOT)
	
	# 移除初始重叠（确保角色不会卡在场景中）
	_remove_overlap()
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()


# -------------------- 物理帧处理（移动与碰撞） --------------------
func _physics_process(delta:float)->void:
	_remove_overlap()  # 先处理重叠（避免穿透）
	
	# 计算目标速度（基于输入轴和最大速度）
	var _target_velocity:Vector2 = actor_stats_resource.max_speed * input_resource.axis
	# 计算加速度脉冲（平滑过渡到目标速度）
	velocity += get_impulse(velocity, _target_velocity, actor_stats_resource.acceleration, delta)
	 # 应用轴乘数（模拟透视效果，如x轴移动更快）
	velocity *= axis_multiplier_resource.value
	# 执行移动与滑动（处理碰撞反弹）
	move_and_slide(delta)
	# 恢复轴补偿（确保速度计算正确）
	velocity *= axis_compensation


# -------------------- 外力脉冲处理（如击退效果） --------------------
## @brief 向速度中添加外力脉冲
func add_impulse(impulse:Vector2)->void:
	velocity += impulse  # 直接叠加脉冲向量


# -------------------- 计算加速度脉冲 --------------------
## @brief 根据当前速度、目标速度和加速度计算脉冲
func get_impulse(current_velocity:Vector2, target_velocity:Vector2, acceleration:float, delta:float)->Vector2:
	var _direction:Vector2 = target_velocity - current_velocity  # 速度差向量
	var _distance:float = _direction.length()  # 速度差的大小
	
	# 计算可移动的距离（加速度 * 时间）
	acceleration = delta * acceleration
	var _ratio:float = 0.0
	if _distance > 0.0:
		_ratio = min(acceleration / _distance, 1.0)  # 确保不超过最大加速度
	
	return _direction * _ratio  # 返回加速度脉冲


# -------------------- 处理重叠碰撞（避免角色穿透场景） --------------------
func _remove_overlap()->void:
	force_shapecast_update()  # 强制更新形状投射状态
	
	if !is_colliding():  # 无碰撞时直接返回
		return
	
	var _solid_distance:Vector2 = Vector2.ZERO  # 累计移动距离
	var _solid_count:int = 0  # 固体碰撞体计数
	
	# 遍历所有碰撞点
	for i:int in get_collision_count():
		var _point:Vector2 = get_collision_point(i)  # 碰撞点坐标
		var _collider:Object = get_collider(i)       # 碰撞体对象
		
		if _collider is CharacterBody2D:
			# 处理与其他角色的碰撞（当前角色与目标角色的位置差）
			var _dis:Vector2 = _point - global_position
			var _character_distance:Vector2 = _collider.global_position - global_position
			
			if _character_distance.length_squared() > _dis.length_squared():
				# 目标角色在更远的位置，移动当前角色
				_move_character(_collider, _rect_distance(_dis))
			else:
				# 双方重叠，简单处理（TODO: 完善复杂碰撞计算）
				_move_character(_collider, _dis * 2)
			continue  # 跳过固体碰撞体处理
		
		# 处理固体碰撞体（如墙壁、地板）
		_solid_count += 1
		var _distance:Vector2 = global_position - _point  # 当前位置到碰撞点的向量
		_solid_distance += _rect_distance(_distance)       # 计算矩形碰撞的修正距离
	
	if _solid_count > 0:
		# 移动角色以移除重叠（基于固体碰撞的累计修正距离）
		_move_character(character, _solid_distance)


# -------------------- 计算矩形碰撞的修正距离 --------------------
## @brief 根据碰撞距离计算移出矩形的修正向量
func _rect_distance(distance:Vector2)->Vector2:
	# x轴修正：符号 * 半宽 - 当前距离（确保移出碰撞体）
	distance.x = sign(distance.x) * shape_rect.size.x - distance.x
	# y轴修正：符号 * 半高 - 当前距离
	distance.y = sign(distance.y) * shape_rect.size.y - distance.y
	return distance


# -------------------- 移动角色并处理碰撞 --------------------
## @brief 移动角色节点并执行碰撞检测
func _move_character(inst:CharacterBody2D, distance:Vector2)->void:
	inst.move_and_collide(distance)  # 移动角色并检测碰撞（忽略返回值，仅处理重叠）


# -------------------- 移动与滑动处理（带碰撞反弹） --------------------
## @brief 执行移动并处理碰撞反弹（模拟物理滑动）
func move_and_slide(delta:float)->void:
	var _motion:Vector2 = velocity * delta  # 计算移动距离
	
	for _iteration:int in range(MAX_SLIDES):
		# 移动角色并获取碰撞结果
		var _collision:KinematicCollision2D = character.move_and_collide(_motion)
		if _collision == null:
			break  # 无碰撞，结束循环
		
		# 获取碰撞法线并应用轴乘数
		var _normal:Vector2 = (_collision.get_normal() * axis_multiplier_resource.value).normalized()
		
		# 计算剩余移动距离和速度（考虑轴补偿）
		_motion = (_collision.get_remainder() * axis_compensation).slide(_normal) * axis_multiplier_resource.value
		velocity = (velocity * axis_compensation).slide(_normal) * axis_multiplier_resource.value
