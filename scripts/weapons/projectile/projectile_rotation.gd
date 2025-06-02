# 投射物旋转控制器：管理投射物的视觉旋转与翻转效果（适用于2D Sprite方向控制）
class_name ProjectileRotation  # 定义类名，可在场景中作为投射物旋转逻辑组件
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 功能启用开关：控制旋转逻辑是否生效
@export var enabled:bool = true  
## 旋转目标节点：需要旋转/翻转的节点（通常为Sprite2D或AnimatedSprite2D）
@export var rotated_node:Node2D  
## 投射物引用：获取投射物的移动方向（需绑定Projectile节点）
@export var projectile:Projectile  
## 移动控制器引用：监听反弹事件以更新旋转（需绑定ProjectileMover节点）
@export var mover:ProjectileMover  
## 连续更新模式：若为true，每帧更新旋转；若为false，仅在反弹时更新
@export var is_continuous:bool = false  
## 水平翻转开关：通过翻转Sprite的水平缩放模拟方向变化（替代旋转）
@export var flip_horizontaly:bool = true  

# -------------------- 状态控制方法（启用/禁用更新） --------------------
## @brief 切换启用状态，控制_process回调的激活
## @param value true 启用并开启连续更新，false 禁用并停止更新
func set_enabled(value:bool)->void:
	enabled = value
	set_process(is_continuous && enabled)  # 根据连续模式和启用状态决定是否调用_process


# -------------------- 生命周期方法（初始化更新模式与信号连接） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileRotation: 投射物引用（projectile）未配置", LogManager.LogLevel.ERROR)
		return
	if rotated_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileRotation: 旋转目标节点（rotated_node）未配置", LogManager.LogLevel.ERROR)
		return
	if mover == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileRotation: 移动控制器引用（mover）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 初始化_process状态（连续模式下启用帧更新）
	set_process(is_continuous && enabled)
	
	# 非连续模式下，监听移动控制器的反弹位置信号以触发旋转更新
	if !is_continuous && mover != null:
		if !mover.bounce_position.is_connected(_rotate_visuals):
			mover.bounce_position.connect(_rotate_visuals)
	_rotate_visuals()  # 初始调用一次，确保初始方向正确


# -------------------- 核心旋转更新方法（计算旋转角度与翻转） --------------------
## @brief 根据投射物方向更新目标节点的旋转和翻转状态
func _rotate_visuals()->void:
	if !enabled || rotated_node == null || projectile == null:
		return  # 关键节点无效时跳过更新
	
	var direction:Vector2 = projectile.direction.normalized()  # 标准化方向向量
	
	if flip_horizontaly && direction.x != 0.0:
		# 通过缩放Y轴实现水平翻转（X正方向为默认方向，X负方向时翻转）
		#rotated_node.scale = Vector2(sign(direction.x), rotated_node.scale.y)
		rotated_node.scale.y = sign(direction.x)
	
	# 设置旋转角度（方向向量的弧度角，0弧度为右，顺时针为正）
	rotated_node.rotation = direction.angle()


# -------------------- 连续更新回调（每帧调用，适用于动态方向变化场景） --------------------
## @brief 连续模式下每帧更新旋转（如追踪目标时的实时转向）
func _process(_delta:float)->void:
	_rotate_visuals()  # 直接调用核心更新方法
