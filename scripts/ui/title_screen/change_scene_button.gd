class_name ChangeSceneButton
extends Node

# 导出的按钮节点引用（需在编辑器中拖拽赋值）
@export var button: Button

# 目标场景的资源路径（如 "res://scenes/main_menu.tscn"）
@export var scene_path: StringName

func _ready() -> void:
	# 连接按钮的按下信号到处理方法
	button.pressed.connect(pressed, CONNECT_ONE_SHOT)

# 按钮按下回调函数
func pressed() -> void:
	# 通过场景过渡管理器切换场景
	TransitionManager.change_scene(scene_path)  # 问题点2：无错误处理
