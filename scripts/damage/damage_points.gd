# 伤害数字显示节点：动态显示伤害数值并通过动画控制移动与回收
class_name DamagePoints  # 定义类名，可在场景中作为伤害数字节点使用
extends Node2D  # 继承自 2D 节点（支持位置、变换等 2D 属性）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var label:Label  # 用于显示伤害数值的标签节点（需绑定场景中的 Label 子节点）
@export var tween_time:float = 1.0  # 伤害数字移动动画的持续时间（单位：秒）
@export var distance:float = 16.0  # 伤害数字移动的总距离（单位：像素）
@export var pool_node:PoolNode  # 对象池节点（用于动画结束后回收当前节点）
# 导出颜色变量（允许在编辑器配置）
@export var critical_color:Color = Color.YELLOW  # 暴击颜色（默认黄色）
@export var normal_color:Color = Color.WHITE      # 普通伤害颜色（默认白色）
@export var angle_min:float = 0.6  # 最小角度系数（0.6*TAU）
@export var angle_max:float = 0.9  # 最大角度系数（0.9*TAU）


# -------------------- 核心方法：配置伤害数值与显示状态 --------------------
## @brief 设置伤害数值并根据暴击状态调整显示样式
## @param points 要显示的伤害数值（如 100、200）
## @param is_critical 是否为暴击伤害（true：暴击，false：普通伤害）
func set_displayed_points(points:int, is_critical:bool)->void:
	if label == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DamagePoints: 伤害标签（label）未配置，无法显示伤害数值", LogManager.LogLevel.ERROR)
		return  # 避免后续操作崩溃
	# 根据暴击状态设置标签颜色（暴击为黄色，普通为白色）
	if is_critical:
		label.modulate = critical_color  # 暴击时标签颜色为黄色（覆盖原有颜色）
	else:
		label.modulate = normal_color   # 普通伤害时标签颜色为白色
	
	# 设置标签文本内容（将数值转换为字符串）
	label.text = str(points)
	
	# 将标签锚点和偏移量预设为居中（确保文本在节点中心显示）
	# Control.PRESET_CENTER：锚点居中，尺寸自适应内容；Control.PRESET_MODE_MINSIZE：最小尺寸模式
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


# -------------------- 生命周期方法（节点初始化与动画启动） --------------------
func _ready()->void:
	if pool_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DamagePoints: 对象池节点（pool_node）未配置，无法回收节点", LogManager.LogLevel.ERROR)
		return  # 无对象池时不启动动画（或直接销毁节点）
	# 生成随机角度（范围：0.6*TAU 到 0.9*TAU，约 216° 到 324°，即偏向斜上方）
	var _angle:float = randf_range(angle_min, angle_max) * TAU  # TAU = 2π（360°）
	
	# 计算移动偏移量（基于随机角度和预设距离）
	var _offset:Vector2 = Vector2.RIGHT.rotated(_angle) * distance  # 向右旋转角度后乘以距离
	
	# 创建补间动画（控制伤害数字从初始位置移动到偏移位置）
	var tween:Tween = create_tween()
	# 绑定 tween_move 方法，传入起始位置（global_position）和结束位置（global_position + _offset）
	# 动画从时间 0.0 到 1.0，持续时间 tween_time（默认 1 秒）
	# 缓动类型：先快后慢（模拟“弹出”效果）
	# 过渡类型：三次方曲线（运动更平滑）
	tween.tween_method(
		tween_move.bind(global_position, global_position + _offset),  # 绑定参数：起始位置、结束位置
		0.0, 1.0,  # 动画进度范围（0 → 1）
		tween_time  # 动画持续时间
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 同时动画标签的透明度（从 1.0 到 0.0）
	tween.set_parallel(true).tween_property(label, "self_modulate:a", 0.0, tween_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	
	# 动画完成后，将当前节点返回对象池（避免重复创建节点）
	tween.finished.connect(tween_finished, CONNECT_ONE_SHOT)


# -------------------- 补间动画回调（更新伤害数字位置） --------------------
## @brief 根据动画进度更新伤害数字的全局位置（线性插值）
## @param t 动画进度（0.0 到 1.0）
## @param from 起始位置（伤害数字的初始全局坐标）
## @param to 结束位置（伤害数字的目标全局坐标）
func tween_move(t:float, from:Vector2, to:Vector2)->void:
	global_position = from.lerp(to, t)  # 从起始位置线性插值到结束位置（按进度 t）


func tween_finished() -> void:
	label.self_modulate.a = 1.0
	pool_node.pool_return()
