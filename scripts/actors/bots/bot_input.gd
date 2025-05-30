# 机器人输入控制节点：管理AI角色的输入逻辑，提供轴补偿和状态更新
class_name BotInput  # 定义类名，可在场景中作为AI输入控制节点使用
extends Node2D  # 继承自2D节点（支持物理帧回调和2D变换）


# -------------------- 信号（输入状态更新通知） --------------------
## 输入状态更新时触发（通知外部输入数据已更新）
signal input_update  


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 输入处理是否启用（禁用时停止物理帧回调）
@export var enabled:bool = true  
## 轴乘数资源（用于调整不同轴的移动速度，如顶视角中X轴速度更快）
@export var axis_multiplier_resource:Vector2Resource  
## 攻击距离（AI角色的攻击判定范围，单位：像素）
@export var attack_distance:float = 16.0  
## 资源节点（存储输入资源等配置）
@export var resource_node:ResourceNode  


# -------------------- 成员变量（运行时状态） --------------------
## 轴补偿向量（用于抵消轴乘数的缩放影响，确保速度计算准确）
var axis_compensation:Vector2  
## 输入资源实例（获取或设置AI的输入轴数据）
var input_resource:InputResource  


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("BotInput: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if axis_multiplier_resource == null || axis_multiplier_resource.value == Vector2.ZERO:
		Log.entry("BotInput: axis_multiplier_resource 未正确配置", LogManager.LogLevel.ERROR)
		return
	# 设置物理帧处理优先级（数值越小越先执行，确保输入处理早于移动逻辑）
	process_physics_priority -= 1  # 优先于移动节点处理输入
	
	# 计算轴补偿（轴乘数的倒数，用于将输入轴从缩放空间转换为实际速度空间）
	axis_compensation = Vector2.ONE / axis_multiplier_resource.value
	
	# 从资源节点获取输入资源（确保非空）
	input_resource = resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("BotInput: 输入资源（input）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 初始化输入处理启用状态
	set_enabled(enabled)
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()


# -------------------- 状态控制方法（启用/禁用输入处理） --------------------
## @brief 切换输入处理的启用状态
## @param value true 启用输入处理，false 禁用并重置输入轴
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)  # 根据启用状态控制物理帧回调的执行
	
	if !enabled:
		# 禁用时将输入轴重置为零（避免残留输入影响AI状态）
		input_resource.axis = Vector2.ZERO


# -------------------- 物理帧处理（输入更新通知） --------------------
## @brief 物理帧回调，触发输入更新信号（供外部模块同步输入状态）
func _physics_process(_delta:float)->void:
	input_update.emit()  # 通知外部输入状态已更新（如AI决策模块、移动控制器）
