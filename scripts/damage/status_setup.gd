# 状态效果管理节点：初始化并存储角色的状态效果（如中毒、灼烧等）
class_name StatusSetup  # 定义类名，可在场景中作为状态管理节点使用
extends Node2D  # 继承自2D节点（支持2D场景中的位置相关操作）


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储伤害资源）
@export var resource_node:ResourceNode  
## 初始状态效果列表（配置角色初始携带的状态效果，如初始增益）
@export var status_list:Array[DamageStatusResource]  


# -------------------- 成员变量（运行时状态） --------------------
## 伤害资源实例（用于监听状态存储信号）
var damage_resource:DamageResource  


# -------------------- 生命周期方法（节点初始化与状态设置） --------------------
func _ready() -> void:
	if resource_node == null:
		Log.entry("StatusSetup: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# BUG 修复：解决 Godot 引擎数组复制的已知问题（https://github.com/godotengine/godot/issues/96181）
	# 对导出数组进行深拷贝，避免编辑器修改影响运行时数据同步
	status_list = status_list.duplicate()
	
	# 初始化状态效果（加载初始配置的状态）
	_setup_status()
	
	# 资源节点准备完成时重新初始化状态（配合对象池或动态资源加载）
	if !resource_node.ready.is_connected(_setup_status):
		resource_node.ready.connect(_setup_status)


# -------------------- 核心逻辑：初始化状态效果并监听动态存储 --------------------
## @brief 从资源节点获取伤害资源，初始化初始状态效果，并监听状态存储信号
func _setup_status()->void:
	# 从资源节点获取伤害资源（用于存储和管理状态效果）
	damage_resource = resource_node.get_resource("damage")
	if damage_resource == null:
		Log.entry("StatusSetup: 伤害资源（damage）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 检查是否已连接store_status信号（避免重复连接）
	if damage_resource.store_status.is_connected(_store_status):
		# 若已连接，说明是同一伤害资源实例，直接返回
		return
	
	# 连接伤害资源的store_status信号（新状态效果生成时触发存储）
	damage_resource.store_status.connect(_store_status)
	
	# 遍历初始状态列表，处理每个状态效果（如激活状态、应用初始效果）
	for _status:DamageStatusResource in status_list:
		if _status == null:
			Log.entry("StatusSetup: 状态效果资源不能为空", LogManager.LogLevel.ERROR)
			return
		# 调用状态效果的process方法（具体逻辑由DamageStatusResource实现）
		# 参数说明：resource_node（资源节点）、null（无目标节点）、true（是否为初始化）
		_status.process(resource_node, null, true)


# -------------------- 动态存储：添加新状态效果到列表 --------------------
## @brief 监听store_status信号，将新生成的状态效果添加到状态列表
## @param status_effect 新生成的状态效果资源（如敌人攻击施加的中毒效果）
func _store_status(status_effect:DamageStatusResource)->void:
	# 将新状态效果添加到本地状态列表（持久化存储）
	status_list.append(status_effect)
