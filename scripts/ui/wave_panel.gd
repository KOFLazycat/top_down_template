# 波次显示面板节点：显示当前波次信息并附带动画效果
class_name WavePanel  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 波次文本标签（显示当前波次号，如 "Wave: 3"）
@export var label:Label

## 战斗模式资源（控制波次显示是否可见，布尔值）
@export var fight_mode_resource:BoolResource

## 波次计数资源（存储当前波次数，整数类型）
@export var wave_count_resource:IntResource

## 带动画的节点（如 PanelContainer，用于实现缩放/旋转动画）
@export var tweened_node:Control

## 动画持续时间
@export var animation_duration:float = 0.5 

## 最大旋转角度（弧度）
@export var max_rotation:float = PI * 0.1

## 补间动画对象（管理节点的动画过渡）
var tween:Tween


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()->void:
	# 连接战斗模式资源的更新信号：状态变更时更新标签可见性
	fight_mode_resource.updated.connect(_on_fight_mode_changed)
	# 连接波次计数资源的更新信号：波次变更时更新显示并触发动画
	wave_count_resource.updated.connect(_on_wave_changed)
	
	# 设置动画节点的枢轴偏移为节点中心（确保动画以中心为基准）
	tweened_node.pivot_offset = tweened_node.size * 0.5
	
	# 初始化调用：确保节点创建时显示正确状态
	_on_fight_mode_changed()
	_on_wave_changed()


# -------------------- 战斗模式变更回调（显示/隐藏波次标签） --------------------
func _on_fight_mode_changed()->void:
	if label == null || fight_mode_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WavePanel: 波次标签或战斗模式资源未配置", LogManager.LogLevel.ERROR)
		return
	# 根据战斗模式资源的值显示或隐藏标签
	label.visible = fight_mode_resource.value
	if tween != null && !fight_mode_resource.value:
		tween.kill()  # 非战斗模式时关闭动画


# -------------------- 波次变更回调（更新显示并触发动画） --------------------
func _on_wave_changed()->void:
	if label == null || wave_count_resource == null || tweened_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WavePanel: 波次标签、波次资源或动画节点未配置", LogManager.LogLevel.ERROR)
		return
	
	# 更新波次标签文本（格式："Wave: X"，X 为当前波次数）
	label.text = "Wave: %d" % wave_count_resource.value
	
	# 设置动画节点的初始状态（随机旋转和放大）
	tweened_node.rotation = randf_range(-max_rotation, max_rotation)  # 随机旋转角度（-18° 到 18°）
	tweened_node.scale = Vector2(1.2, 1.2)  # 初始缩放为 1.2 倍
	
	# 清理旧补间动画（避免多个动画同时运行）
	if tween != null:
		tween.kill()  # 停止旧动画
	
	# 创建新的补间动画：同时执行旋转和缩放过渡
	tween = create_tween()
	# 旋转动画：从当前角度平滑过渡到 0°，持续 0.5 秒，缓出效果
	tween.tween_property(tweened_node, "rotation", 0.0, animation_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 并行缩放动画：从 1.2 倍缩放过渡到 1.0 倍，持续 0.5 秒，缓出效果
	tween.parallel().tween_property(tweened_node, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
