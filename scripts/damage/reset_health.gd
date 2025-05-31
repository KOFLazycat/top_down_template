# 健康值重置节点：用于重置玩家或角色的健康状态，并在角色死亡时自毁
class_name ResetHealth  # 定义类名，可在场景中作为健康重置控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点：存储健康资源（HealthResource）
@export var resource_node:ResourceNode  


# -------------------- 生命周期方法（节点初始化与健康重置） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ResetHealth: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# 获取健康资源（用于重置健康值和监听死亡事件）
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if _health_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ResetHealth: 健康资源（health）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 调用健康资源的重置方法（如恢复满血、清除负面状态等）
	_health_resource.reset_resource()
	
	# 监听角色死亡信号（当健康值归零时触发）
	_health_resource.dead.connect(owner.queue_free)  # 角色死亡时，释放当前节点的所有者（通常为父节点）
