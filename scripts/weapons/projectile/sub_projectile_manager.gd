# 子投射物管理节点：在主投射物生命周期中（生成/销毁时）管理子投射物或特效的生成
class_name SubProjectileManager  # 定义类名，作为子投射物生成的核心管理器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 主投射物引用：绑定需要管理子投射物的主Projectile节点
@export var projectile:Projectile  
## 投射物生成器：用于实例化子投射物的组件（需绑定ProjectileSpawner节点）
@export var projectile_spawner:ProjectileSpawner  
## 开始生成资源：主投射物生成时创建的子资源（如生成特效）
@export var start_projectile_instance_resource:InstanceResource  
## 结束生成资源：主投射物销毁时创建的子资源（如爆炸特效）
@export var end_projectile_instance_resource:InstanceResource  
## 轴乘数资源：用于模拟斜角透视效果的缩放比例（如2D顶视角的XY轴不等比缩放）
@export var axis_multiplication_resource:Vector2Resource  

# -------------------- 成员变量（运行时状态） --------------------
var axis_compensation:Vector2  # 轴乘数的倒数（用于补偿缩放影响，计算实际方向/位置）


# -------------------- 生命周期方法（初始化配置与信号连接） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SubProjectileManager: 主投射物引用（projectile）未配置", LogManager.LogLevel.ERROR)
		return
	if projectile_spawner == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SubProjectileManager: 投射物生成器（projectile_spawner）未配置", LogManager.LogLevel.ERROR)
		return
	if axis_multiplication_resource == null || axis_multiplication_resource.value == Vector2.ZERO:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SubProjectileManager: 轴乘数资源（axis_multiplication_resource）未正确配置", LogManager.LogLevel.ERROR)
		return
	
	# TODO: 临时模拟配置（需根据实际场景扩展条件配置）
	# 合并主投射物的碰撞层到生成器（确保子投射物检测相同层级）
	projectile_spawner.collision_mask = Bitwise.append_flags(projectile_spawner.collision_mask, projectile.collision_mask)
	
	# 计算轴补偿向量（用于将缩放后的方向转换为实际逻辑方向）
	axis_compensation = Vector2.ONE / axis_multiplication_resource.value
	
	# 主投射物生成时立即创建开始资源（如生成特效）
	if start_projectile_instance_resource != null:
		spawn(start_projectile_instance_resource)
	
	# 主投射物退出场景树时创建结束资源（如销毁特效）
	if end_projectile_instance_resource != null:
		projectile.tree_exiting.connect(spawn.bind(end_projectile_instance_resource))


# -------------------- 子资源生成核心方法 --------------------
## @brief 配置投射物生成器并触发子资源生成
## @param projectile_instance_resource 待生成的子资源（预制体）
func spawn(projectile_instance_resource:InstanceResource)->void:
	if projectile_spawner == null:
		return  # 关键组件无效时跳过
	
	# 传递主投射物的属性到生成器
	projectile_spawner.projectile_instance_resource = projectile_instance_resource  # 设置子资源类型
	projectile_spawner.projectile_position = projectile.global_position  # 设置生成位置为主投射物当前位置
	projectile_spawner.direction = projectile.direction * axis_compensation  # 应用轴补偿后的实际方向
	projectile_spawner.damage_data_resource = projectile.damage_data_resource  # 继承主投射物的伤害数据
	
	# 触发子资源生成
	projectile_spawner.spawn()
