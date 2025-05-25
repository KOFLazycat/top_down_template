# 2D相机跟随节点：平滑跟随目标位置（支持资源化配置）
class_name CameraFollow2D  # 定义类名，可在场景中作为相机节点类型使用
extends Camera2D  # 继承自 Godot 2D 相机类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 是否启用跟随功能（开关）
@export var follow:bool = true

## 平滑插值速度（值越大跟随越灵敏，建议范围：1.0~10.0）
@export_range(0.0, 10.0) var lerp_speed:float = 5.0

## 目标位置资源（存储 Vector2 坐标，可在编辑器中指定或通过资源动态修改）
@export var target_position:Vector2Resource

## 添加最小距离阈值，避免无意义插值
const DISTANCE_LERP_MIN:float = 0.1


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()->void:
	# 初始化目标位置（若已配置资源）
	set_target_position(target_position)
	# 根据跟随状态和目标有效性，启用/禁用物理进程更新
	_update_physics_process()


## 切换跟随功能的开关
## @param value: 是否启用跟随（true/false）
func set_follow(value:bool)->void:
	follow = value  # 更新跟随状态
	# 仅当跟随启用且目标位置有效时，开启物理进程更新
	_update_physics_process()


## 设置目标位置资源（支持动态切换目标）
## @param value: 新的目标位置资源（Vector2Resource 实例）
func set_target_position(value:Vector2Resource)->void:
	if value == null:
		return  # 空资源直接返回
	
	target_position = value  # 保存目标资源
	# 立即将相机位置同步到目标初始位置
	global_position = target_position.value
	# 更新物理进程状态（根据跟随状态和目标有效性）
	_update_physics_process()


## 物理进程回调（每帧调用，确保跟随逻辑与物理引擎同步）
## @param delta: 帧间隔时间（秒）
func _physics_process(delta:float)->void:
	if target_position == null:
		return  # 目标资源无效时跳过更新
	
	# 添加最小距离阈值，避免无意义插值
	var distance = (global_position - target_position.value).length()
	if distance < DISTANCE_LERP_MIN:  # 阈值可调整
		global_position = target_position.value  # 直接定位，避免浮点误差
		return
	
	# 使用线性插值（Lerp）平滑移动相机至目标位置
	# lerp_speed * delta 控制每帧移动的比例（确保速度与帧率无关）
	global_position = global_position.lerp(target_position.value, lerp_speed * delta)


func _update_physics_process()->void:
	set_physics_process(follow && target_position != null)
