# 保存控制配置事件节点：监听重绑定面板可见性，隐藏时自动保存输入配置
class_name SaveControlsEvent  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 重绑定面板（如包含按键设置的 UI 面板，控制其可见性）
@export var rebinding_panel:Control

## 动作资源（存储输入绑定配置，需支持 `save_resource()` 方法）
@export var action_resource:ActionResource


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()->void:
	# 断言确保动作资源和重绑定面板已配置（未配置时抛出错误）
	assert(action_resource != null)
	assert(rebinding_panel != null)
	if action_resource == null:
		Log.entry("未配置动作资源（action_resource），保存功能将失效", LogManager.LogLevel.ERROR)
		return
	if rebinding_panel == null:
		Log.entry("未配置重绑定面板（rebinding_panel），保存功能将失效", LogManager.LogLevel.ERROR)
		return
	
	# 连接重绑定面板的可见性变更信号到 `on_visibility_changed` 回调
	rebinding_panel.visibility_changed.connect(on_visibility_changed)


# -------------------- 可见性变更回调（面板隐藏时保存配置） --------------------
func on_visibility_changed()->void:
	# 若面板当前可见，直接返回（仅处理隐藏事件）
	if rebinding_panel.visible:
		return
	
	# 断言确保动作资源的存储路径不为空（未配置路径时抛出错误）
	if action_resource.resource_path.is_empty():
		Log.entry("动作资源的存储路径（resource_path）未配置，无法保存", LogManager.LogLevel.ERROR)
		return
	
	# 调用动作资源的保存方法（将输入绑定写入文件）
	action_resource.save_resource()


func _exit_tree()->void:
	if rebinding_panel != null:
		rebinding_panel.visibility_changed.disconnect(on_visibility_changed)
