# 目标瞄准控制节点：根据目标或移动方向设置AI的瞄准方向
class_name TargetAim  # 定义类名，可在场景中作为瞄准控制节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 机器人输入节点（用于获取移动轴数据和设置瞄准方向）
@export var bot_input:BotInput  
## 目标检测节点（用于获取当前追踪的目标）
@export var target_finder:TargetFinder  
## 瞄准方向是否跟随行走方向（true：瞄准方向=移动方向；false：瞄准方向=目标方向）
@export var aim_walking_direction:bool  


# -------------------- 生命周期方法（节点准备完成） --------------------
func _ready()->void:
	if bot_input == null:
		Log.entry("TargetAim: 机器人输入节点（bot_input）未配置，瞄准控制初始化失败", LogManager.LogLevel.ERROR)
		return
	if target_finder == null:
		Log.entry("TargetAim: 目标检测节点（target_finder）未配置，瞄准控制初始化失败", LogManager.LogLevel.ERROR)
		return
	# 连接目标更新信号（目标变更时触发瞄准方向计算）
	target_finder.target_update.connect(_on_target_update)


# -------------------- 目标更新回调（核心瞄准逻辑） --------------------
## @brief 当目标检测结果更新时，计算并设置AI的瞄准方向
func _on_target_update()->void:
	if aim_walking_direction:  # 瞄准方向跟随行走方向
		# 获取移动轴方向（已应用轴补偿），并归一化为单位向量
		var walking_direction:Vector2 = (bot_input.input_resource.axis * bot_input.axis_compensation).normalized()
		bot_input.input_resource.set_aim_direction(walking_direction)  # 设置瞄准方向为移动方向
		return
	
	# 瞄准方向指向目标时：若未检测到目标，直接返回
	if target_finder.closest == null:
		return
	
	# 计算从AI到目标的方向向量（世界坐标差值）
	var direction:Vector2 = target_finder.closest.global_position - bot_input.global_position
	# 应用轴补偿（调整不同轴的速度差异），并归一化为单位向量
	var aim_direction:Vector2 = (direction * bot_input.axis_compensation).normalized()
	bot_input.input_resource.set_aim_direction(aim_direction)  # 设置瞄准方向为目标方向
