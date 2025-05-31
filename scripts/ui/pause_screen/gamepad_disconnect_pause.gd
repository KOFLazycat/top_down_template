# 手柄断开暂停节点：检测游戏手柄连接状态，断开时自动暂停游戏
class_name GamepadDisconnectPause  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 暂停状态布尔资源（控制游戏暂停状态，true 为暂停）
@export var pause_resource:BoolResource


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()->void:
	# 连接 Input 类的手柄连接状态变更信号
	# 当手柄连接状态变化时，触发 on_joy_connection_changed 回调
	Input.joy_connection_changed.connect(on_joy_connection_changed)


# -------------------- 手柄连接状态变更回调 --------------------
func on_joy_connection_changed(_device: int, connected: bool)->void:
	if pause_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "GamepadDisconnectPause: 未配置暂停状态资源（pause_resource），无法处理手柄断开事件", LogManager.LogLevel.ERROR)
		return
	# 若手柄已连接（connected 为 true），直接返回（不处理连接事件）
	if connected:
		return
	
	# 若当前游戏已处于暂停状态（pause_resource.value 为 true），返回
	if pause_resource.value == true:
		return
	
	# 手柄断开且游戏未暂停时，设置暂停状态为 true（触发游戏暂停）
	pause_resource.set_value(true)


func _exit_tree()->void:
	Input.joy_connection_changed.disconnect(on_joy_connection_changed)
