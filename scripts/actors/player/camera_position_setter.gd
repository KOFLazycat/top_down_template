# 相机位置设置节点：同步目标节点位置到相机的目标位置，实现相机跟随效果
class_name CameraPositionSetter  # 定义类名，可在场景中作为相机位置控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 相机引用节点资源：指向场景中的相机节点（需包含set_target_position方法）
@export var camera_reference:ReferenceNodeResource  
## 位置资源：存储目标节点的位置数据（Vector2类型，用于同步到相机）
@export var position_resource:Vector2Resource  
## 目标节点：需要相机跟随的节点（如玩家角色节点）
@export var target_node:Node2D  


# -------------------- 生命周期方法（节点初始化与监听配置） --------------------
func _ready()->void:
	if camera_reference == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CameraPositionSetter: 相机引用资源（camera_reference）未配置", LogManager.LogLevel.ERROR)
		return
	if position_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CameraPositionSetter: 位置资源（position_resource）未配置", LogManager.LogLevel.ERROR)
		return
	if target_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CameraPositionSetter: 目标节点（target_node）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 监听相机引用节点的变化（当引用节点变更时触发回调）
	camera_reference.listen(self, _on_camera_reference)
	
	# 当节点进入场景树时，触发相机位置同步（处理跨场景加载情况）
	tree_entered.connect(_on_camera_reference)


# -------------------- 相机引用变更回调（同步目标位置到相机） --------------------
func _on_camera_reference()->void:
	if !is_inside_tree():  # 确保节点已加入场景树
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CameraPositionSetter: 节点不在场景树", LogManager.LogLevel.ERROR)
		return
	if camera_reference.node == null:  # 校验相机节点是否有效
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CameraPositionSetter: 相机节点不存在", LogManager.LogLevel.ERROR)
		return
	
	# 获取目标节点的当前全局位置，并更新到位置资源
	position_resource.set_value(target_node.global_position)
	# 调用相机节点的方法设置目标位置（需确保相机节点存在该方法）
	camera_reference.node.set_target_position(position_resource)


# -------------------- 物理帧更新（实时同步目标位置） --------------------
## @brief 每一物理帧更新目标节点位置到位置资源（确保实时性）
func _physics_process(_delta: float)->void:
	position_resource.set_value(target_node.global_position)  # 实时同步位置数据
