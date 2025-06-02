# 投射物冲击效果控制器：在投射物命中目标或反弹时生成冲击特效
class_name ProjectileImpact  # 定义类名，作为场景中投射物冲击效果的核心控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 投射物引用：需要绑定的Projectile节点（用于获取位置和方向）
@export var projectile:Projectile  
## 移动控制器引用：监听投射物反弹和结束事件（需绑定ProjectileMover）
@export var projectile_mover:ProjectileMover  
## 数据传输器引用：监听命中成功信号（如伤害传输器）
@export var data_transmitter:DataChannelTransmitter  
## 冲击效果实例资源：用于生成冲击特效的预制体（如爆炸、烟尘等）
@export var impact_instance_resource:InstanceResource  


# -------------------- 生命周期方法（初始化信号连接） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileImpact: 投射物引用（projectile）未配置", LogManager.LogLevel.ERROR)
		return
	if projectile_mover == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileImpact: 移动控制器引用（projectile_mover）未配置", LogManager.LogLevel.ERROR)
		return
	if data_transmitter == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileImpact: 数据传输器引用（data_transmitter）未配置", LogManager.LogLevel.ERROR)
		return
	if impact_instance_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileImpact: 冲击效果实例资源（impact_instance_resource）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 连接命中成功信号（数据传输器检测到命中时触发特效生成）
	data_transmitter.success.connect(spawn)
	# 连接反弹位置信号（投射物每次反弹时触发特效生成）
	projectile_mover.bounce_position.connect(spawn)
	# 连接反弹结束信号（投射物反弹次数耗尽时触发特效生成）
	projectile_mover.bounces_finished.connect(spawn)


# -------------------- 实例化配置回调（设置特效位置和旋转） --------------------
## @brief 配置新生成的冲击效果实例（设置位置和旋转）
## @param inst 新生成的节点实例（通常包含Sprite2D等视觉组件）
func _config_callback(inst:Node2D)->void:
	inst.global_position = projectile.global_position  # 将特效位置设置为投射物当前位置
	
	# 尝试获取实例中的Sprite2D节点并设置旋转（根据投射物方向）
	var sprite:Sprite2D = inst.get_node("Sprite2D")
	if sprite != null:
		sprite.rotation = projectile.direction.angle()  # 设置旋转角度为投射物移动方向的弧度角
	else:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileImpact: Sprite2D节点（Sprite2D）未获取到，无法完成旋转", LogManager.LogLevel.ERROR)
		return


# -------------------- 特效生成方法（响应信号触发实例化） --------------------
## @brief 生成冲击效果实例（响应命中、反弹或结束事件）
func spawn()->void:
	impact_instance_resource.instance(_config_callback)  # 实例化特效并应用配置回调
