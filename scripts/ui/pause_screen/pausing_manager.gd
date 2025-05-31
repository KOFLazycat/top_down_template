# 游戏暂停管理器：控制暂停状态、输入处理及暂停界面显示
class_name PausingManager  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 动作资源（存储暂停操作的输入动作名称，如 "pause"）
@export var action_resource:ActionResource

## 暂停状态布尔资源（存储暂停状态，暴露 `value` 变量和 `updated` 信号）
@export var pause_bool_resource:BoolResource

## 暂停界面根节点（如包含菜单的 Panel，控制其可见性和交互）
@export var pause_root:CanvasItem

## 恢复按钮（点击后恢复游戏的 Button 节点）
@export var resume_button:Button

## 菜单导航管理器（处理暂停菜单的导航逻辑，如返回上一级）
@export var menu_traverse_manager:MenuTraverseManager


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()->void:
	if pause_bool_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PausingManager: 未配置暂停状态资源（pause_bool_resource）", LogManager.LogLevel.ERROR)
		return
	# 重置暂停状态资源（确保初始状态为未暂停）
	pause_bool_resource.reset_resource()
	# 设置节点处理模式为始终处理（即使游戏暂停也能响应输入）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 连接暂停状态变更信号到 `pause_changed` 方法（状态变化时更新界面）
	pause_bool_resource.updated.connect(pause_changed)
	# 初始化调用 `pause_changed`（确保初始状态正确）
	pause_changed()
	# 连接恢复按钮的点击信号到 `resume` 方法（点击按钮恢复游戏）
	resume_button.pressed.connect(resume)
	# 连接场景退出信号，退出时强制设置暂停状态为 false（避免残留暂停状态）
	tree_exiting.connect(pause_bool_resource.set_value.bind(false))


# -------------------- 输入事件处理（响应暂停/恢复操作） --------------------
func _input(event:InputEvent)->void:
	if action_resource == null || pause_bool_resource == null || menu_traverse_manager == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PausingManager: 关键资源未配置，无法处理暂停输入", LogManager.LogLevel.ERROR)
		return
	
	# 检查是否释放了暂停动作或 "ui_cancel" 输入（如 ESC 键）
	if event.is_action_released(action_resource.pause_action) || event.is_action_released("ui_cancel"):
		if pause_bool_resource.value == false:
			# 当前未暂停：设置暂停状态为 true（触发界面显示）
			pause_bool_resource.set_value(true)
		else:
			# 当前已暂停：检查菜单导航管理器的选中目录是否为根路径（`.` 表示当前节点）
			if menu_traverse_manager.directory_resource.selected_directory == NodePath("."):
				# 在根菜单：设置暂停状态为 false（隐藏界面，恢复游戏）
				pause_bool_resource.set_value(false)
			else:
				# 非根菜单：调用菜单导航管理器的 `back` 方法（返回上一级菜单）
				menu_traverse_manager.back()


# -------------------- 恢复游戏（响应按钮点击） --------------------
func resume()->void:
	# 直接设置暂停状态为 false（触发 `pause_changed` 隐藏界面）
	pause_bool_resource.set_value(false)


# -------------------- 暂停状态变更回调（更新界面和交互） --------------------
func pause_changed()->void:
	# 获取当前暂停状态（从布尔资源中读取）
	var is_paused:bool = pause_bool_resource.value
	# 显示/隐藏暂停界面根节点（控制视觉可见性）
	pause_root.visible = is_paused
	# 设置暂停界面的处理模式：暂停时允许处理（响应输入），否则禁用处理（节省性能）
	pause_root.process_mode = Node.PROCESS_MODE_ALWAYS if is_paused else Node.PROCESS_MODE_DISABLED


# -------------------- 在 _exit_tree 方法中断开所有信号连接。 --------------------
func _exit_tree()->void:
	if pause_bool_resource != null:
		pause_bool_resource.updated.disconnect(pause_changed)
	if resume_button != null:
		resume_button.pressed.disconnect(resume)
	if tree_exiting.is_connected(pause_bool_resource.set_value.bind(false)):
		tree_exiting.disconnect(pause_bool_resource.set_value.bind(false))
