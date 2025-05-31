# 相机震动资源类：参数化配置并驱动相机震动效果
class_name CameraShakeResource  # 定义类名，可在编辑器中作为资源类型使用
extends Resource  # 继承自 Godot 基础资源类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 震动持续时间（单位：秒）
@export var length:float = 0.5

## 频率曲线（X轴：0~1 时间进度，Y轴：震动频率）
@export var frequency:Curve

## 振幅曲线（X轴：0~1 时间进度，Y轴：震动幅度）
@export var amplitude:Curve

## 震动方向起始角度（0~360度，与 angleto 共同定义随机方向范围）
@export_range (0.0, 360.0) var angleFrom:float = 0.0

## 震动方向结束角度（0~360度，与 angleFrom 共同定义随机方向范围）
@export_range (0.0, 360.0) var angleto:float = 360.0

## 相机引用资源（指向实际的 Camera2D 节点）
@export var camera_reference:ReferenceNodeResource

## 补间资源（管理震动的补间动画）
@export var tween_resource:TweenValueResource

## 全局启用设置（通过 BoolResource 控制是否启用震动，支持跨场景共享）
@export var enabled_settings:BoolResource


# -------------------- 成员变量（运行时状态） --------------------

## 震动方向（由 angleFrom 和 angleto 随机生成的单位向量）
var dir:Vector2


# -------------------- 核心方法（启动震动） --------------------
func play()->void:
	# 确保全局启用设置已配置
	if enabled_settings == null:
		Log.entry("CameraShakeResource: 未配置全局启用设置（enabled_settings）", LogManager.LogLevel.ERROR)
		return

	# 若全局禁用震动，直接返回
	if enabled_settings.value == false:
		return

	# 若相机引用无效（节点未设置或已销毁），直接返回
	if camera_reference == null || camera_reference.node == null:
		Log.entry("CameraShakeResource: 相机引用无效（未设置或已销毁）", LogManager.LogLevel.ERROR)
		return

	# 生成随机震动方向：在 angleFrom 到 angleto 范围内随机选取角度
	var angle = deg_to_rad(lerp(angleFrom, angleto, randf()))  # 角度转弧度
	dir = Vector2(cos(angle), sin(angle))  # 角度转单位向量

	# 杀死当前补间动画（避免多段震动叠加混乱）
	if tween_resource.value != null:
		tween_resource.value.kill()
		tween_resource.value = null  # 清空引用

	# 创建新的补间动画，绑定到相机节点
	tween_resource.value = camera_reference.node.create_tween().bind_node(camera_reference.node)

	# 驱动 sample 方法：t 参数从 0.0 线性过渡到 1.0，持续时间 length 秒
	# warning-ignore:return_value_discarded（忽略 tween 链式调用的返回值）
	tween_resource.value.tween_method(sample, 0.0, 1.0, length)


# -------------------- 核心方法（计算每帧偏移量） --------------------
func sample(t:float)->void:
	if camera_reference.node == null:
		Log.entry("CameraShakeResource: 相机引用无效已销毁", LogManager.LogLevel.ERROR)
		return  # 相机节点已销毁时停止计算偏移
	if frequency == null || amplitude == null:
		camera_reference.node.offset = Vector2.ZERO  # 无曲线时重置偏移
		Log.entry("CameraShakeResource: 相机引用无效已销毁", LogManager.LogLevel.ERROR)
		return
	
	# 计算当前频率：通过 frequency 曲线采样（t 为 0~1 时间进度）
	var freq = frequency.sample(t)
	# 计算当前振幅：通过 amplitude 曲线采样（t 为 0~1 时间进度）
	var amp = amplitude.sample(t)

	# 计算震动偏移量：
	# sin(TAU * freq * length * (1-t)) 生成随时间衰减的正弦波（(1-t) 实现频率渐弱）
	# amp * dir 控制振幅和方向
	var offset:Vector2 = sin(TAU * freq * length * (1.0 - t)) * amp * dir

	# 应用偏移量到相机（Camera2D 的 offset 属性控制镜头偏移）
	camera_reference.node.offset = offset
