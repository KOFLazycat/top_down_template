# 近程攻击控制节点：根据目标距离触发攻击动作
class_name ProximityAttack  # 定义类名，可在场景中作为近程攻击控制节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 目标检测节点（用于获取当前检测到的目标）
@export var target_finder:TargetFinder  
## 机器人输入节点（用于获取攻击距离和设置攻击动作）
@export var bot_input:BotInput  


# -------------------- 成员变量（运行时状态） --------------------
var enabled:bool = false  # 攻击是否启用（初始为false，延迟后启用）
var tween_timer:Tween  # 补间计时器（用于延迟启用攻击）


# -------------------- 生命周期方法（节点进入场景树） --------------------
func _enter_tree() -> void:
	enabled = false  # 初始禁用攻击（避免节点刚加载就触发）
	
	# 清理旧补间（防止节点重复进入时多个补间同时运行）
	if tween_timer != null:
		tween_timer.kill()
	
	# 创建新补间：延迟1秒后启用攻击（如用于角色进入场景的准备时间）
	tween_timer = create_tween()
	tween_timer.tween_callback(set_enabled.bind(true)).set_delay(1.0)


# -------------------- 生命周期方法（节点准备完成） --------------------
func _ready()->void:
	if target_finder == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProximityAttack: 目标检测节点（target_finder）未配置，近程攻击初始化失败", LogManager.LogLevel.ERROR)
		return
	if bot_input == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProximityAttack: 机器人输入节点（bot_input）未配置，近程攻击初始化失败", LogManager.LogLevel.ERROR)
		return
	
	# 连接目标更新信号（目标变更时触发攻击判断）
	target_finder.target_update.connect(_on_target_update)


# -------------------- 状态控制方法（启用/禁用攻击） --------------------
## @brief 设置攻击启用状态
## @param value true 启用攻击，false 禁用
func set_enabled(value:bool)->void:
	enabled = value


# -------------------- 目标更新回调（核心攻击判断逻辑） --------------------
## @brief 当目标检测结果更新时，判断是否触发攻击
func _on_target_update()->void:
	if !enabled:  # 攻击未启用时直接返回
		return
	
	# 无目标时停止攻击动作
	if target_finder.target_count < 1:
		bot_input.input_resource.set_action(false)
		return
	
	# 计算当前AI与最近目标的距离
	var distance:float = (target_finder.closest.global_position - bot_input.global_position).length_squared()
	
	# 根据距离是否小于等于攻击距离，设置攻击动作（true为攻击，false为停止）
	bot_input.input_resource.set_action(distance <= bot_input.attack_distance * bot_input.attack_distance)
