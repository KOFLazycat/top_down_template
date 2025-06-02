# 投射物移动控制器：管理投射物的多种移动模式（直线、反弹、插值等）
class_name ProjectileMover  # 定义类名，作为投射物移动逻辑核心组件
extends Node  # 继承自基础节点类


# -------------------- 信号定义（状态与过程通知） --------------------
## 反弹次数耗尽信号：当剩余反弹次数为0时触发
signal bounces_finished  
## 反弹位置信号：每次反弹时触发，携带当前位置信息
signal bounce_position()  
#signal bounce_position(position: Vector2)
## 插值时间信号：在LERP移动中实时反馈进度（0.0~1.0）
signal interpolated_time(value:float)  
## 插值完成信号：LERP移动到达目标时触发
signal lerp_finished  


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 投射物引用：绑定需要控制的Projectile节点
@export var projectile:Projectile  
## 碰撞掩码：指定投射物检测的2D物理层（位掩码）
@export_flags_2d_physics var collision_mask:int  
## 移动类型枚举：定义投射物的移动模式
enum MovementType {
	PROJECTILE,       # 直线移动（速度固定）
	SHAPECAST,        # 形状投射移动（基于ShapeCast2D检测碰撞反弹）
	RAYCAST,          # 射线检测移动（基于RayCast2D，存在角度计算问题）
	LERP_SPEED,       # 速度插值移动（根据距离/速度计算时间）
	LERP_TIME,        # 固定时间插值移动（使用指定时间完成移动）
	FOLLOW            # TODO：跟随移动（待实现）
}
@export var movement_type:MovementType  
## 最大反弹次数：投射物在销毁前允许的最大反弹次数
@export var max_bounce:int  
## 形状投射碰撞形状：仅在SHAPECAST模式下需要配置
@export var collision_shape:Shape2D  
## 速度曲线：在LERP移动中控制速度变化（X轴为进度，Y轴为速度比例）
@export var speed_curve:Curve  

# -------------------- 成员变量（运行时状态） --------------------
var remaining_bounces:int  # 剩余反弹次数（初始为max_bounce+1，首次碰撞消耗1次）
var move_direction:Vector2  # 标准化移动方向（考虑轴乘数补偿）
var shape_cast:ShapeCast2D  # 形状投射节点（动态创建）
var world_2d:World2D       # 2D世界引用（用于射线检测）
var ray_query:PhysicsRayQueryParameters2D  # 射线检测参数
var move_tween:Tween       # 插值移动补间控制器


# -------------------- 编辑器配置警告（辅助开发） --------------------
## @brief 提供编辑器内配置检查（如SHAPECAST模式缺少碰撞形状）
func _get_configuration_warnings() -> PackedStringArray:
	var _warnings:PackedStringArray = PackedStringArray()
	if movement_type == MovementType.SHAPECAST && collision_shape == null:
		_warnings.append("警告：SHAPECAST模式需要配置碰撞形状（collision_shape）")
	return _warnings


# -------------------- 生命周期方法（初始化移动逻辑） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileMover: 投射物引用（projectile）未配置", LogManager.LogLevel.ERROR)
		return
	if projectile.axis_multiplier_resource == null || projectile.axis_multiplier_resource.value == Vector2.ZERO:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileMover: axis_multiplier_resource 未正确配置", LogManager.LogLevel.ERROR)
		return
	
	# 标准化移动方向（应用轴乘数补偿）
	move_direction = _to_normalized_direction(projectile.direction).normalized()
	
	# 初始化反弹次数（+1是因为首次碰撞会消耗1次）
	remaining_bounces = max(max_bounce, 0) + 1
	
	# 根据移动类型初始化不同逻辑
	match movement_type:
		MovementType.PROJECTILE:
			# 直线移动：标准化方向，启用物理帧更新
			projectile.direction = projectile.direction.normalized()
			set_physics_process(true)
		MovementType.SHAPECAST:
			# 形状投射移动：创建ShapeCast2D节点并配置
			projectile.direction = projectile.direction.normalized()
			set_physics_process(true)
			if shape_cast == null:
				shape_cast = ShapeCast2D.new()
				shape_cast.shape = collision_shape
				shape_cast.collision_mask = collision_mask
				shape_cast.enabled = false
				# 延迟添加子节点以确保投射物节点已初始化
				projectile.add_child.call_deferred(shape_cast)
		MovementType.RAYCAST:
			# 射线检测移动：初始化射线参数
			projectile.direction = projectile.direction.normalized()
			set_physics_process(true)
			world_2d = projectile.get_world_2d()
			ray_query = PhysicsRayQueryParameters2D.new()
			ray_query.collide_with_bodies = true
			ray_query.collision_mask = collision_mask
		MovementType.LERP_SPEED:
			# 速度插值移动：根据距离和速度计算时间，创建补间
			set_physics_process(false)
			var _distance:Vector2 = projectile.destination - projectile.global_position
			projectile.direction = _distance.normalized()
			var _length = _distance.length()
			var _time = _length / max(projectile.speed, 0.001)  # 避免除零
			if move_tween != null: move_tween.kill()
			move_tween = create_tween()
			move_tween.tween_method(_lerp_move.bind(projectile.global_position, projectile.direction), 0.0, 1.0, _time)
			move_tween.finished.connect(_lerp_finished, CONNECT_ONE_SHOT)
		MovementType.LERP_TIME:
			# 固定时间插值移动：使用指定时间创建补间
			set_physics_process(false)
			var _distance:Vector2 = projectile.destination - projectile.global_position
			projectile.direction = _distance.normalized()
			if move_tween != null: move_tween.kill()
			move_tween = create_tween()
			move_tween.tween_method(_lerp_move.bind(projectile.global_position, projectile.destination), 0.0, 1.0, projectile.time)
			move_tween.finished.connect(_lerp_finished, CONNECT_ONE_SHOT)


# -------------------- 辅助方法：标准化方向（应用轴乘数补偿） --------------------
## @brief 将原始方向向量转换为标准化向量（考虑轴乘数资源）
func _to_normalized_direction(dir:Vector2)->Vector2:
	var _axis_multiplier = projectile.axis_multiplier_resource.value
	return dir * (Vector2.ONE / _axis_multiplier) if _axis_multiplier != Vector2.ZERO else dir


# -------------------- 物理帧更新（处理实时移动逻辑） --------------------
func _physics_process(delta:float)->void:
	match movement_type:
		MovementType.PROJECTILE:
			# 直线移动：直接按速度和方向更新位置
			var _movement = projectile.speed * delta * move_direction * projectile.axis_multiplier_resource.value
			projectile.global_position += _movement
		MovementType.SHAPECAST:
			# 形状投射移动：处理碰撞检测和反弹
			var _remaining_length:float = projectile.speed * delta
			for i:int in remaining_bounces:
				var _move_vec:Vector2 = _remaining_length * move_direction * projectile.axis_multiplier_resource.value
				shape_cast.target_position = _move_vec
				shape_cast.force_shapecast_update()
				if !shape_cast.is_colliding():
					# 无碰撞：完成移动
					projectile.global_position += _move_vec
					break
				
				# 有碰撞：计算碰撞分数和法线
				var _fraction:float = shape_cast.get_closest_collision_safe_fraction()
				_move_vec *= _fraction
				_remaining_length -= _remaining_length * _fraction
				
				var _normal:Vector2 = shape_cast.get_collision_normal(0)
				var _dot:float = _normal.dot(move_direction.normalized())
				var _bounce:bool = _dot < 0.0 # 仅当方向与法线夹角>90度时反弹
				
				if _bounce:
					# 计算反弹方向并消耗一次反弹次数
					var _bounce_mov:Vector2 = move_direction.bounce((_normal * projectile.axis_multiplier_resource.value).normalized())
					move_direction = _bounce_mov
					remaining_bounces -= 1
				# workaround for questionable collision calculations. It shouldn't have positive dot product and go into a wall.
				 # 处理异常碰撞（避免嵌入墙体）
				if _fraction < 0.1 && _dot < 0.3:
					var _angle_to_normal:float = move_direction.angle_to(_normal)
					## TODO: have situational value for rotation lerp
					move_direction = move_direction.rotated(_angle_to_normal * 0.2) # 微小角度调整
				
				# 更新位置和方向
				projectile.global_position += _move_vec
				projectile.direction = move_direction * projectile.axis_multiplier_resource.value
				shape_cast.rotation = projectile.direction.angle()
				
				if _bounce:
					bounce_position.emit()
				
				if remaining_bounces == 0:
					# 反弹次数耗尽：触发完成信号并销毁
					bounces_finished.emit()
					projectile.prepare_exit()
					set_physics_process(false)
					break
				
				if _fraction == 1.0: break  # 完全碰撞，不再移动
		MovementType.RAYCAST:
			# 射线检测移动（TODO：功能不完整，可能存在瓷砖接缝问题）
			var _remaining_length:float = projectile.speed * delta
			
			for i:int in remaining_bounces:
				ray_query.from = projectile.global_position
				var _move_vec:Vector2 = _remaining_length * move_direction * projectile.axis_multiplier_resource.value
				ray_query.to = projectile.global_position + _move_vec
				
				var _collision:Dictionary = world_2d.direct_space_state.intersect_ray(ray_query)
				if _collision.is_empty():
					# 无碰撞：完成移动
					projectile.global_position = ray_query.to
					break
				
				# 计算移动距离和剩余长度
				var _moved_distance:Vector2 = ray_query.to - ray_query.from
				var _max_move:float = max(_move_vec.x, _move_vec.y)
				if _max_move != 0.0:
					_remaining_length -= _remaining_length * max(_moved_distance.x, _moved_distance.y) / _max_move
				
				# 更新位置和方向
				projectile.global_position = _collision.position
				remaining_bounces -= 1
				
				if remaining_bounces == 0:
					bounces_finished.emit()
					set_physics_process(false)
					break
				
				move_direction = _to_normalized_direction(projectile.direction.bounce(_collision.normal)).normalized()
				projectile.direction = move_direction * projectile.axis_multiplier_resource.value
				shape_cast.rotation = projectile.direction.angle()
				bounce_position.emit()


# -------------------- 插值移动方法（用于Tween回调） --------------------
## @brief 线性插值移动（支持速度曲线）
func _lerp_move(t:float, from:Vector2, to:Vector2)->void:
	var _progress = speed_curve.sample(t) if speed_curve != null else t  # 无曲线时使用线性进度
	projectile.global_position = from.lerp(to, _progress)
	interpolated_time.emit(t)  # 发送插值进度信号


# -------------------- 插值完成回调 --------------------
func _lerp_finished()->void:
	lerp_finished.emit()  # 通知插值移动完成
