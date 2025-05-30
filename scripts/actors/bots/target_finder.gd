# 目标检测节点：通过形状投射检测范围内的可交互目标，返回最近目标
class_name TargetFinder  # 定义类名，可在场景中作为目标检测节点使用
extends Node  # 继承自基础节点类


# -------------------- 信号（目标更新通知） --------------------
## 当检测到目标或目标变更时触发（通知外部目标列表更新）
signal target_update  


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 形状投射节点（用于碰撞检测，需配置检测区域形状）
@export var shape_cast:ShapeCast2D  
## 机器人输入节点（用于获取当前位置或触发检测逻辑）
@export var bot_input:BotInput  

# -------------------- 常量与成员变量（运行时状态） --------------------
## 最大目标数量（限制检测到的目标数量，避免性能问题）
const MAX_TARGETS:int = 10  
## 目标列表（存储检测到的可交互节点）
var target_list:Array[Node2D]
## 当前最近目标（距离最近的可交互节点）
var closest:Node2D = null  
var target_count:int

# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if shape_cast == null:
		Log.entry("TargetFinder: 形状投射节点（shape_cast）未配置，目标检测初始化失败", LogManager.LogLevel.ERROR)
		return
	if bot_input == null:
		Log.entry("TargetFinder: 机器人输入节点（bot_input）未配置，目标检测初始化失败", LogManager.LogLevel.ERROR)
		return
	# 初始化目标列表为固定大小（避免动态扩容开销）
	target_list.resize(MAX_TARGETS)
	# 连接输入更新信号（当输入状态变化时触发目标检测）
	bot_input.input_update.connect(_on_input_update)


# -------------------- 输入更新回调（触发目标检测） --------------------
## @brief 当输入状态更新时，执行目标检测逻辑
func _on_input_update()->void:
	# 强制更新形状投射状态（确保碰撞检测数据最新）
	shape_cast.force_shapecast_update()
	if shape_cast.is_colliding():  # 检测到碰撞时处理目标
		target_count = 0    # 重置目标数量
		# 遍历所有碰撞结果
		for i in range(shape_cast.get_collision_count()):
			var _collider:PhysicsBody2D = shape_cast.get_collider(i) as PhysicsBody2D
			if _collider == null:
				continue
			# 过滤静态物体（如StaticBody2D，可根据需求调整过滤条件）
			if _collider is StaticBody2D:
				continue
			
			target_list[i] = _collider
			target_count += 1
	else:
		target_count = 0
	
	# 查找最近目标（需确保GameMath存在且包含get_closest_node_2d方法）
	closest = GameMath.get_closest_node_2d(bot_input.global_position, target_list, target_count)
	target_update.emit()
