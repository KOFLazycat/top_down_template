# 血量面板节点：可视化显示角色血量状态（带补间动画）
class_name HealthPanel  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 健康状态资源（存储血量数据，需暴露 hp 和 max_hp 变量）
@export var health_resource:HealthResource

## 血量文本标签（显示当前血量/最大血量）
@export var label:Label

## 进度条着色器材质（需包含 progress_foreground 和 progress_middle 参数）
@export var progress_shader:ShaderMaterial

## 补间动画持续时间（单位：秒，控制进度条过渡速度）
@export var tween_time:float = 0.5


# -------------------- 成员变量（运行时状态） --------------------

var tween_front:Tween  # 前景进度补间动画（快速过渡层）
var tween_middle:Tween  # 中间进度补间动画（缓慢过渡层）

var value_front:float   # 前景进度值（0~1）
var value_middle:float  # 中间进度值（0~1）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	# 连接 HealthResource 的信号：重置/最大血量变更时触发重置
	health_resource.reset_update.connect(_on_reset)
	health_resource.max_hp_changed.connect(_on_reset)
	# 连接血量变更信号：实时更新进度条
	health_resource.hp_changed.connect(_update)
	_on_reset()  # 初始化显示


# -------------------- 重置方法（血量重置或最大血量变更时调用） --------------------
func _on_reset()->void:
	# 更新文本标签（显示当前血量/最大血量）
	_update_label()

	# 杀死已存在的补间动画（避免残留动画干扰）
	if tween_front != null:
		tween_front.kill()
	if tween_middle != null:
		tween_middle.kill()

	# 初始化进度值（当前血量占最大血量的比例）
	var max_hp: float = health_resource.max_hp
	if max_hp == 0.0:
		max_hp = 1.0
	value_front = health_resource.hp / max_hp
	value_middle = value_front

	# 更新着色器参数（设置初始进度）
	progress_shader.set_shader_parameter("progress_foreground", value_front)
	progress_shader.set_shader_parameter("progress_middle", value_middle)


# -------------------- 血量变更回调（实时更新进度条） --------------------
func _update()->void:
	# 更新文本标签（实时显示最新血量）
	_update_label()

	# 杀死已存在的补间动画（开始新动画前清理）
	if tween_front != null:
		tween_front.kill()
	if tween_middle != null:
		tween_middle.kill()

	# 创建新的补间动画对象
	tween_front = create_tween()
	tween_middle = create_tween()

	# 计算新的进度值（当前血量比例）
	var max_hp: float = health_resource.max_hp
	if max_hp == 0.0:
		max_hp = 1.0
	var _new_value:float = health_resource.hp / max_hp

	# 前景进度动画：快速过渡（半时长，缓出效果）
	tween_front.tween_method(_tween_front, value_front, _new_value, tween_time * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 中间进度动画：缓慢过渡（全时长，缓入效果）
	tween_middle.tween_method(_tween_middle, value_middle, _new_value, tween_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


func _update_label()->void:
	label.text = "%d/%d" % [health_resource.hp, health_resource.max_hp]


# -------------------- 补间回调：更新前景进度 --------------------
func _tween_front(value:float)->void:
	value_front = value  # 更新前景进度值
	# 设置着色器参数（驱动前景进度条显示）
	progress_shader.set_shader_parameter("progress_foreground", value_front)


# -------------------- 补间回调：更新中间进度 --------------------
func _tween_middle(value:float)->void:
	value_middle = value  # 更新中间进度值
	# 设置着色器参数（驱动中间进度条显示）
	progress_shader.set_shader_parameter("progress_middle", value_middle)


# -------------------- 节点销毁时断开信号连接 --------------------
func _exit_tree()->void:
	health_resource.reset_update.disconnect(_on_reset)
	health_resource.max_hp_changed.disconnect(_on_reset)
	health_resource.hp_changed.disconnect(_update)
