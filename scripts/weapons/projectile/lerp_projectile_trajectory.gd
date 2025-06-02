# 插值投射物轨迹控制器：通过插值曲线控制投射物的抛物线轨迹，并处理落地逻辑
class_name LerpProjectileTrajectory  # 定义类名，作为轨迹控制核心组件
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 投射物引用：需要控制轨迹的Projectile节点（绑定具体投射物实例）
@export var projectile:Projectile  
## 移动控制器：监听插值时间和完成事件（需绑定ProjectileMover节点）
@export var projectile_mover:ProjectileMover  
## 高度节点：用于控制轨迹高度的辅助节点（通常为投射物的子节点）
@export var height_node:Node2D  
## 轨迹曲线：定义插值时间（0-1）与高度的映射关系（X轴为时间，Y轴为高度偏移）
@export var curve:Curve  
## 形状投射传输器：用于检测落地碰撞的组件（触发伤害或碰撞逻辑）
@export var shape_cast_transmitter:ShapeCastTransmitter2D  
## 落地特效资源：投射物落地时生成的视觉效果（如爆炸、烟尘预制体）
@export var landing_vfx:InstanceResource  
## 落地音效资源：投射物落地时播放的声音（如爆炸声）
@export var landing_sound:SoundResource  


# -------------------- 生命周期方法（信号连接初始化） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "LerpProjectileTrajectory: 投射物引用（projectile）未配置", LogManager.LogLevel.ERROR)
		return
	if projectile_mover == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "LerpProjectileTrajectory: 移动控制器（projectile_mover）未配置", LogManager.LogLevel.ERROR)
		return
	if height_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "LerpProjectileTrajectory: 高度节点（height_node）未配置", LogManager.LogLevel.ERROR)
		return
	if curve == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "LerpProjectileTrajectory: 轨迹曲线（curve）未配置", LogManager.LogLevel.ERROR)
		return
	if shape_cast_transmitter == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "LerpProjectileTrajectory: 形状投射传输器（shape_cast_transmitter）未配置", LogManager.LogLevel.ERROR)
		return
	if landing_vfx == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "LerpProjectileTrajectory: 落地特效资源（landing_vfx）未配置", LogManager.LogLevel.ERROR)
		return
	if landing_sound == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "LerpProjectileTrajectory: 落地音效资源（landing_sound）未配置", LogManager.LogLevel.ERROR)
		return
	# 监听移动控制器的插值时间变化信号（持续传递当前插值进度t）
	projectile_mover.interpolated_time.connect(_on_interpolation)
	# 监听移动控制器的插值完成信号（延迟调用确保主线程执行）
	projectile_mover.lerp_finished.connect(_on_lerp_finished.call_deferred)


# -------------------- 插值进度回调（动态调整轨迹高度） --------------------
## @brief 根据插值时间t更新高度节点的Y坐标，实现抛物线轨迹
## @param t 插值进度（0-1，0为起点，1为终点）
func _on_interpolation(t:float)->void:
	if height_node != null && curve != null:
		# 通过曲线采样获取当前时间对应的Y轴高度偏移（控制轨迹弧度）
		height_node.position.y = curve.sample(t)

	
# -------------------- 插值完成回调（处理落地逻辑） --------------------
## @brief 投射物到达目标点后，执行碰撞检测、特效生成、音效播放和投射物退出
func _on_lerp_finished()->void:
	# 触发形状投射传输器的碰撞检测（传递伤害或碰撞信息）
	shape_cast_transmitter.check_transmission()
	
	# 获取投射物当前全局位置（作为落地位置）
	var _position:Vector2 = projectile.global_position
	
	# 生成落地特效（通过配置回调设置位置）
	if landing_vfx != null:
		var _config_callback:Callable = func (inst:Node2D)->void:
			inst.global_position = _position  # 设置特效位置为投射物落地位置
		landing_vfx.instance(_config_callback)  # 实例化特效
	
	# 播放落地音效（使用SoundResource的管理播放方法，自动处理音效生命周期）
	if landing_sound != null:
		landing_sound.play_managed()
	
	# 触发投射物退出逻辑（如销毁或回收）
	projectile.prepare_exit()
