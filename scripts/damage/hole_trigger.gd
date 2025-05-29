# 触洞触发器：监听布尔资源状态，触发触洞事件并自动重置
class_name HoleTrigger  # 定义类名，可在场景中作为触洞检测节点使用
extends Node  # 继承自基础节点类


# -------------------- 信号（触洞事件通知） --------------------
## 当布尔资源值为true时触发（通知外部触洞事件发生）
signal hole_touched  


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储布尔资源）
@export var resource_node:ResourceNode  


# -------------------- 生命周期方法（节点初始化与资源绑定） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("HoleTrigger: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# 从资源节点获取名为"hole"的布尔资源（用于监听状态变更）
	var _hole_bool:BoolResource = resource_node.get_resource("hole")
	if _hole_bool == null:
		Log.entry("HoleTrigger: 布尔资源（hole）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 连接布尔资源的updated信号（资源值变更时触发）
	# 绑定_hole_bool作为参数传递给回调（确保回调中能访问资源实例）
	_hole_bool.updated.connect(_on_hole_updated.bind(_hole_bool))
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(
		_hole_bool.updated.disconnect.bind(_on_hole_updated),  # 断开信号与回调的连接
		CONNECT_ONE_SHOT  # 仅触发一次
	)


# -------------------- 资源状态变更回调（触发触洞事件） --------------------
## @brief 当布尔资源值变更时，检查是否为true并触发事件
## @param hole_bool 被监听的布尔资源实例
func _on_hole_updated(hole_bool:BoolResource)->void:
	# 若资源值为false，直接返回（不触发事件）
	if hole_bool.value == false:
		return
	
	# 触发触洞事件（通知外部触洞发生）
	hole_touched.emit()
	
	# 重置资源值为false（确保单次触发，避免重复响应）
	hole_bool.set_value(false)
