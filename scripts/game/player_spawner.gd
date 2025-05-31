# 玩家生成器节点：管理玩家实例生成、场景过渡时的位置同步
class_name PlayerSpawner  # 定义类名，可在场景中作为节点类型使用
extends Node2D  # 继承自 2D 节点（适用于 2D 场景中的玩家生成）


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 玩家引用资源（存储玩家节点引用，支持跨场景持久化）
@export var player_reference:ReferenceNodeResource

## 玩家实例资源（用于实例化玩家场景，需暴露 `instance` 方法）
@export var player_instance_resource:InstanceResource

## 场景过渡资源（管理场景切换逻辑，需暴露相关信号和属性）
@export var scene_transition_resource:SceneTransitionResource


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()->void:
	# 断言：确保玩家引用资源和实例资源已配置（调试模式校验）
	if player_reference == null:
		Log.entry("PlayerSpawner: 玩家引用资源未配置", LogManager.LogLevel.ERROR)
		return
	if player_instance_resource == null:
		Log.entry("PlayerSpawner: 玩家实例资源未配置", LogManager.LogLevel.ERROR)
		return
	
	# 连接场景过渡资源的场景切换信号到回调函数
	scene_transition_resource.change_scene.connect(on_scene_transition)
	
	# 检查当前场景是否已存在玩家节点
	if player_reference.node != null:
		## 延迟调用玩家进入场景逻辑（确保节点树初始化完成）
		on_player_scene_entry.call_deferred()
		return
	
	# 若玩家节点不存在，实例化玩家场景
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = global_position  # 设置玩家生成位置为当前节点位置
	var _player:Node2D = player_instance_resource.instance(_config_callback)


# -------------------- 玩家进入场景逻辑（处理场景内位置同步） --------------------
func on_player_scene_entry()->void:
	# 确保场景过渡资源的入口匹配节点有效
	if scene_transition_resource.entry_match == null:
		Log.entry("PlayerSpawner: 场景过渡入口节点未配置，玩家位置同步失败", LogManager.LogLevel.ERROR)
		return
	if !scene_transition_resource.entry_match.is_inside_tree():
		Log.entry("PlayerSpawner: 入口节点不在场景树中，使用默认生成位置", LogManager.LogLevel.ERROR)
		return
	if scene_transition_resource.entry_match.is_queued_for_deletion():
		Log.entry("PlayerSpawner: 入口节点已入队删除", LogManager.LogLevel.ERROR)
		return
	
	var _player:Node2D = player_reference.node  # 获取玩家节点引用
	# 设置玩家全局位置为场景过渡入口节点的位置
	_player.global_position = scene_transition_resource.entry_match.global_position
	
	if player_instance_resource.parent_reference_resource.node == null:
		Log.entry("PlayerSpawner: 玩家父节点未配置", LogManager.LogLevel.ERROR)
		return
	# 将玩家节点添加到实例资源指定的父节点中
	player_instance_resource.parent_reference_resource.node.add_child(_player)


# -------------------- 场景切换回调（处理跨场景玩家状态） --------------------
func on_scene_transition()->void:
	var _parent:Node = player_instance_resource.parent_reference_resource.node
	var _player:Node = player_reference.node
	
	# 延迟移除玩家节点（避免场景切换时立即销毁导致的异常）
	_parent.remove_child.call_deferred(_player)
	
	# 断开场景切换信号连接（避免重复触发）
	scene_transition_resource.change_scene.disconnect(on_scene_transition)
	
	# 调用场景过渡管理器执行实际场景切换（假设 TransitionManager 为全局单例）
	TransitionManager.change_scene(scene_transition_resource.next_scene_path)
