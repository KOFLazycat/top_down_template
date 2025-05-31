# 自动为 ReferenceNodeResource 资源分配节点引用的工具节点
class_name ReferenceNodeSetter  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# ------------- 导出变量（可在编辑器中可视化配置） -------------

## 需要被分配给 ReferenceNodeResource 的目标节点
@export var reference_node:Node

## 目标 ReferenceNodeResource 资源（用于存储节点引用）
@export var reference_resource:ReferenceNodeResource

## 资源路径（若不为空，会覆盖 reference_resource 变量，从路径加载资源）
@export var reference_resource_path:String

## 是否仅在节点可处理（处于场景树且未被禁用）时初始化（默认 false）
@export var process_only:bool = false

## 是否在 reference_node 退出场景树时自动移除引用（传递给 ReferenceNodeResource）
@export var until_tree_exit:bool = true

## 可选：用于触发移除引用的信号发送节点
@export var signal_node:Node

## 可选：触发移除引用的信号名称（需与 signal_node 配合使用）
@export var signal_name:StringName


# ------------- 生命周期方法（节点初始化完成时调用） -------------
func _ready()->void:
	# 若配置为 "仅可处理时初始化" 但当前节点不可处理（如被禁用或未加入场景树），则跳过初始化
	if process_only && !can_process():
		return

	# 若资源路径不为空，优先从路径加载资源（覆盖 reference_resource 变量）
	if !reference_resource_path.is_empty():
		var loaded_resource: Resource = load(reference_resource_path)
		if loaded_resource is ReferenceNodeResource and loaded_resource != null:
			reference_resource = loaded_resource
		else:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ReferenceNodeSetter: 资源路径 %s 加载失败或类型错误（需为 ReferenceNodeResource）" % reference_resource_path, LogManager.LogLevel.ERROR)
			return  # 提前返回避免后续逻辑出错

	if reference_node == null || !reference_node.is_inside_tree():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ReferenceNodeSetter: reference_node 未配置或已失效，跳过引用绑定", LogManager.LogLevel.ERROR)
		return

	# 核心逻辑：调用 ReferenceNodeResource 的 set_reference 方法，设置节点引用
	# 参数 1：目标节点（reference_node）
	# 参数 2：是否在节点退出场景树时自动移除引用（由 until_tree_exit 控制）
	reference_resource.set_reference(reference_node, until_tree_exit)

	# 若配置了信号节点和信号名称，绑定信号以触发引用移除
	if signal_node != null and signal_node.has_signal(signal_name):
		if !signal_node.is_connected(signal_name, reference_resource.remove_reference):
			# 连接 signal_node 的 signal_name 信号，绑定 reference_resource 的 remove_reference 方法
			# 当 signal_node 发射该信号时，会调用 remove_reference 并传入 reference_node 作为参数
			signal_node.connect(signal_name, reference_resource.remove_reference.bind(reference_node), CONNECT_ONE_SHOT)
