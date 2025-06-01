# 物品掉落节点：处理角色死亡时的物品掉落逻辑
class_name ItemDrop  # 定义类名，可在场景中作为物品掉落控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点：存储健康资源（HealthResource）等全局资源
@export var resource_node:ResourceNode  
## 根节点：用于获取角色的全局位置（通常为角色根节点）
@export var root_node:Node2D  
## 掉落物品实例资源数组：包含可掉落的物品预制体（如武器、金币等）
@export var drop_instance_resources:Array[InstanceResource]  
## 掉落概率：0.0~1.0之间的数值（如0.1表示10%概率掉落）
@export_range(0.0, 1.0) var drop_chance:float = 0.1


# -------------------- 生命周期方法（节点初始化与信号连接） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ItemDrop: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return 
	if root_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ItemDrop: 根节点（root_node）未配置", LogManager.LogLevel.ERROR)
		return 
	# 获取健康资源（监听角色死亡事件）
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if _health_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ItemDrop: 健康资源（health）未配置，物品掉落逻辑失效", LogManager.LogLevel.ERROR)
		return
	
	# 角色死亡时触发掉落逻辑
	_health_resource.dead.connect(_on_death)
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(
		_health_resource.dead.disconnect.bind(_on_death), 
		CONNECT_ONE_SHOT  # 确保仅断开一次
	)
	
	# 配合对象池使用（标记节点准备完成）
	request_ready()


# -------------------- 角色死亡回调（处理物品掉落） --------------------
## @brief 当角色死亡时，根据概率和配置生成掉落物品
func _on_death()->void:
	# 检查是否配置了掉落资源（数组为空时直接返回）
	if drop_instance_resources.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ItemDrop: 掉落物品实例资源数组（drop_instance_resources）未配置", LogManager.LogLevel.WARNING)
		return
	
	# 随机概率判断是否触发掉落（小于等于概率值时触发）
	if randf() > drop_chance:
		return
	
	# 定义物品实例化配置回调：设置掉落物品的位置为根节点位置
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = root_node.global_position  # 物品掉落在角色根节点位置
		inst.name = "DroppedItem_" + str(randi())  # 可选：为掉落物品设置唯一名称
	
	# 从掉落资源数组中随机选择一个实例资源
	var _drop_instance_resource:InstanceResource = drop_instance_resources.pick_random()
	
	# 实例化物品并应用配置回调
	_drop_instance_resource.instance(_config_callback)
