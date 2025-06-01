# 巨型果冻史莱姆追逐控制节点：处理史莱姆的跳跃追逐逻辑（计算目标位置、执行跳跃、落地恢复）
class_name BigJellyChase  # 定义类名，作为场景中史莱姆的追逐行为控制器
extends Node  # 继承自基础节点类

# -------------------- 信号定义（状态通知） --------------------
## 追逐行为完成信号：在落地恢复完成后触发（通知其他系统如AI切换状态）
signal finished  

# -------------------- 导出变量（编辑器可视化配置） --------------------
## 跳跃移动组件：负责实际执行跳跃动作的逻辑组件（需绑定包含跳跃逻辑的节点）
@export var jump_move:JumpMove  
## 目标偏移量：在目标位置基础上增加的偏移（用于调整跳跃落点，避免与目标完全重合）
@export var target_offset:Vector2  
## 跳跃时间：单次跳跃动作的持续时间（秒），控制跳跃速度
@export var jump_time:float = 1.0  
## 落地恢复时间：落地后等待恢复的时间（秒），期间无法执行新动作（TODO：可用于难度调节）
@export var landing_recovery_time:float = 0.32  
## 轴乘数资源：调整X/Y轴方向的移动距离（例如Vector2(2,1)表示X轴移动距离放大2倍）
@export var axis_multiplication:Vector2Resource  
## 落地特效资源：落地时生成的视觉效果预制体（如灰尘、冲击波）
@export var landing_vfx:InstanceResource  
## 启用开关：控制追逐逻辑是否生效（用于暂停或禁用行为）
@export var enabled:bool = true  

# -------------------- 成员变量（运行时状态） --------------------
## 跳跃方向向量（受轴乘数影响）：最终跳跃方向（已应用轴乘数缩放）
var direction:Vector2  
## 跳跃距离长度：实际跳跃的距离（受最大距离限制）
var distance_length:float  
## 跳跃目标位置：最终计算出的跳跃终点坐标（世界坐标系）
var jump_pos:Vector2  
## 轴补偿向量：轴乘数的倒数（用于平衡距离计算中的缩放）
var axis_compensation:Vector2  


# -------------------- 生命周期方法（初始化与信号连接） --------------------
func _ready() -> void:
	if jump_move == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyChase: 跳跃移动组件（jump_move）未配置", LogManager.LogLevel.ERROR)
		return
	if landing_vfx == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyChase: 落地特效资源（landing_vfx）未配置", LogManager.LogLevel.ERROR)
		return
	if axis_multiplication.value == Vector2.ZERO:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyChase: 轴乘数资源（axis_multiplication）值为(0, 0)", LogManager.LogLevel.ERROR)
		return
	# 监听跳跃移动组件的"jump_finished"信号（跳跃动作完成时触发落地逻辑）
	jump_move.jump_finished.connect(_on_landing)
	# 初始化轴补偿：用于在计算距离时抵消轴乘数的缩放（例如轴乘数为(2,1)时，补偿为(0.5,1)）
	axis_compensation = Vector2.ONE / axis_multiplication.value  


# -------------------- 核心方法：触发跳跃到目标位置 --------------------
## @brief 执行已计算好的跳跃动作（需先调用target_calculation计算目标位置）
func jump_at_target()->void:
	if !enabled:  # 未启用时直接返回
		return
	# 调用跳跃移动组件的方法，设置跳跃目标位置和时间
	jump_move.move_target_position(jump_pos, jump_time)  


# -------------------- 核心方法：计算跳跃目标位置 --------------------
## @brief 根据目标位置、速度和最大距离，计算最终的跳跃落点
## @param target_position 目标（如玩家）的当前世界坐标
## @param target_velocity 目标的移动速度（用于预测目标在跳跃期间的位置）
## @param max_distance 最大跳跃距离（限制实际跳跃长度）
func target_calculation(target_position:Vector2, target_velocity:Vector2, max_distance:float)->void:
	# 预测目标在跳跃期间的位置偏移：速度 * 跳跃时间（实现"提前量"追逐）
	var _player_velocity_offset:Vector2 = target_velocity * jump_time
	# 最终目标位置：预测位置 + 手动偏移量（调整落点）
	var _target_pos = target_position + _player_velocity_offset + target_offset
	
	# 计算当前位置到目标位置的向量（应用轴补偿抵消轴乘数的缩放）
	var _distance:Vector2 = (_target_pos - jump_move.character_body.global_position) * axis_compensation
	# 实际跳跃距离：取计算距离与最大距离的较小值（限制跳跃长度）
	distance_length = min(_distance.length(), max_distance)
	# 最终跳跃方向：标准化距离向量后，重新应用轴乘数缩放（恢复方向的实际比例）
	direction = _distance.normalized() * axis_multiplication.value
	# 跳跃目标位置：当前位置 + 方向 * 实际距离（最终落点）
	jump_pos = jump_move.character_body.global_position + direction * distance_length  


# -------------------- 跳跃完成回调（处理落地逻辑） --------------------
## @brief 当跳跃动作完成时触发（生成落地特效、启动恢复计时）
func _on_landing()->void:
	# 创建补间动画：延迟落地恢复时间后触发_on_landing_timeout
	var _tween:Tween = create_tween()
	_tween.tween_callback(_on_landing_timeout).set_delay(landing_recovery_time)
	
	# 生成落地特效：配置特效位置为当前角色位置减去目标偏移（与跳跃落点对齐）
	var _vfx_config:Callable = func (inst:Node2D)->void:
		inst.global_position = jump_move.character_body.global_position - target_offset
	landing_vfx.instance(_vfx_config)  


# -------------------- 恢复完成回调（触发完成信号） --------------------
## @brief 落地恢复时间结束后触发，通知追逐行为完成
func _on_landing_timeout()->void:
	finished.emit()  # 发射完成信号
