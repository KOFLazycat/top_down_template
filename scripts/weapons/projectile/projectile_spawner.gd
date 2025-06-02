# 投射物生成器：负责根据配置生成具有不同方向和属性的子投射物
class_name ProjectileSpawner  # 定义类名，可在场景中作为投射物生成核心组件
extends Node  # 继承自基础节点类


# -------------------- 信号定义（生成前事件通知） --------------------
## 生成准备信号：在实际生成前触发，用于外部组件调整角度数组（如散射角度计算）
signal prepare_spawn  

# -------------------- 导出变量（编辑器可视化配置） --------------------
## 生成启用开关：false时取消生成（用于暂停或条件生成）
@export var enabled:bool = true  
## 生成位置：投射物生成点的全局坐标（作为初始位置计算基准）
@export var projectile_position:Vector2  
## 主方向：投射物的基础飞行方向（标准化向量，如Vector2.RIGHT）
@export var direction:Vector2  
## 轴乘数资源：模拟斜角透视的缩放比例（如顶视角中X轴缩放大于Y轴）
@export var axis_multiplication_resource:Vector2Resource  
## 初始距离：生成点沿主方向的偏移距离（控制投射物生成位置与发射点的距离）
@export var initial_distance:float  
## 投射物实例资源：用于生成投射物的预制体（需继承自Projectile）
@export var projectile_instance_resource:InstanceResource  
## 碰撞掩码：附加到投射物的碰撞层（与投射物自身碰撞层合并）
@export_flags_2d_physics var collision_mask:int  
## 角度偏移数组：每个元素为投射物方向的角度偏移（度，正数为顺时针旋转）
@export var projectile_angles:Array[float] = [0.0]  
## 伤害数据资源：投射物携带的伤害信息（可配置是否生成新实例）
@export var damage_data_resource:DamageDataResource  
## 新建伤害数据：是否为每个投射物创建伤害数据副本（避免共享数据污染）
@export var new_damage:bool = false  


# -------------------- 核心生成方法（处理投射物实例化逻辑） --------------------
func spawn()->void:
	if projectile_instance_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileSpawner: 投射物实例资源（projectile_instance_resource）未配置", LogManager.LogLevel.ERROR)
		return
	if axis_multiplication_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileSpawner: 轴乘数资源（axis_multiplication_resource）未配置", LogManager.LogLevel.ERROR)
		return
	
	if !enabled:  # 生成禁用时直接返回
		return
	# 通知外部调整角度数组（如散射逻辑）
	prepare_spawn.emit()
	
	 # 处理伤害数据（克隆或引用）
	var new_damage_resource:DamageDataResource
	if new_damage:
		# 创建伤害数据新世代
		new_damage_resource = damage_data_resource.new_generation()
	else:
		new_damage_resource = damage_data_resource  # 直接使用现有数据
	
	# 遍历角度数组生成多个投射物
	for angle:float in projectile_angles:
		var _config_callback:Callable = func (inst:Projectile)->void:
			# 计算角度偏移后的方向（应用轴乘数缩放）
			var _rotated_dir = direction.rotated(deg_to_rad(angle))  # 旋转主方向
			var _angle_delta = (_rotated_dir - direction) * axis_multiplication_resource.value  # 方向增量（考虑透视缩放）
			# 标准化最终方向（避免长度变化）
			inst.direction = (_rotated_dir + _angle_delta).normalized()  
			# 处理伤害数据分裂（假设DamageDataResource支持分裂）
			inst.damage_data_resource = new_damage_resource.new_split()  # 创建独立副本
			# 合并碰撞掩码（投射物自身掩码 + 当前配置掩码）
			inst.collision_mask = Bitwise.append_flags(inst.collision_mask, collision_mask)
			# 计算生成位置（主方向偏移 + 初始距离）
			inst.global_position = projectile_position + initial_distance * direction * axis_multiplication_resource.value
		
		var _inst:Projectile = projectile_instance_resource.instance(_config_callback)
