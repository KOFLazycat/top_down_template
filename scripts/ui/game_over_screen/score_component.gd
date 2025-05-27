# 分数组件节点：管理分数显示与重试重置逻辑
class_name ScoreComponent  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var score_resource:ScoreResource  # 分数资源（存储当前分数值，需暴露 value 属性和 reset 方法）
@export var score_label:Label  # 分数显示标签（如 "Score: 100"）
@export var try_again_button:Button  # 重试按钮（点击后重置分数）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if score_resource == null:
		Log.entry("未配置分数资源（score_resource）", LogManager.LogLevel.ERROR)
		return
	if score_label == null:
		Log.entry("未配置分数标签（score_label）", LogManager.LogLevel.ERROR)
		return
	if try_again_button == null:
		Log.entry("未配置重试按钮（try_again_button）", LogManager.LogLevel.ERROR)
		return
	
	# 延迟让重试按钮获取焦点（确保界面渲染完成后操作）
	try_again_button.grab_focus.call_deferred()
	
	# 连接重试按钮的点击信号到回调函数
	try_again_button.pressed.connect(on_try_again_pressed)
	
	# 初始化分数标签文本（首次显示当前分数）
	score_label.text = "Score: " + str(score_resource.value)


# -------------------- 重试按钮点击回调（重置分数） --------------------
func on_try_again_pressed()->void:
	# 调用分数资源的重置方法（如将分数清零并触发资源更新）
	score_resource.reset_resource()
