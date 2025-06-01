# 巨型果冻跳跃伤害节点：处理史莱姆跳跃落地时的伤害判定与击退效果
class_name BigJellyJumpDamage  # 定义类名，作为跳跃伤害处理核心节点
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 跳跃移动组件：获取跳跃状态（开始/结束信号）
@export var jump_move:JumpMove  
## 追逐控制组件：获取追逐方向（用于近程击退方向）
@export var chase_player:BigJellyChase  
## 区域接收者：检测地面或目标的碰撞区域
@export var area_receiver:AreaReceiver2D  
## 伤害传输器：通过形状投射检测并发送伤害数据
@export var damage_transmitter:ShapeCastTransmitter2D  
## 击退传输器：通过形状投射检测并发送击退数据
@export var push_transmitter:ShapeCastTransmitter2D  
## 击退数据通道：传递击退相关配置（如强度、方向）
@export var push_channel_transmitter:DataChannelTransmitter  
## 轴乘数资源：调整X/Y轴方向的计算比例（如非等比缩放移动距离）
@export var axis_multiplication:Vector2Resource  
## 击退半径：以史莱姆为中心的击退有效范围（像素）
@export var kickback_radius:float = 40.0  
## 击退曲线：根据距离计算击退强度的插值曲线（X轴为距离比例，Y轴为强度比例）
@export var kickback_curve:Curve  
## 击退强度最大值：距离为0时的最大击退强度
@export var kickback_max:float  
## 击退强度最小值：距离达到半径时的最小击退强度
@export var kickback_min:float  


# -------------------- 成员变量（运行时状态） --------------------
var receiver_collision_layer:int  # 保存区域接收者的原始碰撞层（用于临时禁用碰撞）
var axis_compensation:Vector2    # 轴乘数的倒数（用于平衡不同轴的距离计算）


# -------------------- 生命周期方法（初始化与信号连接） --------------------
func _ready() -> void:
	if jump_move == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyJumpDamage: 跳跃移动组件（jump_move）未配置", LogManager.LogLevel.ERROR)
		return
	if chase_player == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyJumpDamage: 追逐控制组件（chase_player）未配置", LogManager.LogLevel.ERROR)
		return
	if area_receiver == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyJumpDamage: 区域接收者（area_receiver）未配置", LogManager.LogLevel.ERROR)
		return
	if damage_transmitter == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyJumpDamage: 伤害传输器（damage_transmitter）未配置", LogManager.LogLevel.ERROR)
		return
	if push_transmitter == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyJumpDamage: 击退传输器（push_transmitter）未配置", LogManager.LogLevel.ERROR)
		return
	if push_channel_transmitter == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyJumpDamage: 击退数据通道（push_channel_transmitter）未配置", LogManager.LogLevel.ERROR)
		return
	if axis_multiplication.value == Vector2.ZERO:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyJumpDamage: 轴乘数资源（axis_multiplication）值为(0, 0)", LogManager.LogLevel.ERROR)
		return
	# 保存区域接收者的原始碰撞层（跳跃时临时关闭碰撞，落地后恢复）
	receiver_collision_layer = area_receiver.collision_layer
	# 计算轴补偿向量（用于将世界坐标距离转换为逻辑距离）
	axis_compensation = Vector2.ONE / axis_multiplication.value
	
	# 连接数据通道更新信号（当击退数据需要更新时触发）
	push_channel_transmitter.update_requested.connect(_update_push)
	# 连接跳跃开始/结束信号（控制碰撞层开关和伤害检测）
	jump_move.jump_started.connect(_on_jump)
	jump_move.jump_finished.connect(_on_land)


# -------------------- 跳跃开始回调（关闭碰撞检测） --------------------
## @brief 跳跃开始时关闭区域接收者的碰撞层，避免空中触发伤害
func _on_jump()->void:
	area_receiver.collision_layer = 0  # 临时设置碰撞层为0（忽略所有碰撞）


# -------------------- 跳跃完成回调（恢复碰撞并检测伤害/击退） --------------------
## @brief 落地时恢复碰撞层，并触发伤害和击退检测
func _on_land()->void:
	area_receiver.collision_layer = receiver_collision_layer  # 恢复原始碰撞层
	damage_transmitter.check_transmission()  # 检测并发送伤害数据
	push_transmitter.check_transmission()    # 检测并发送击退数据


# -------------------- 击退数据更新回调（计算击退强度和方向） --------------------
## @brief 根据目标距离和曲线计算击退参数，并更新伤害数据
## @param damage_data 伤害数据资源（包含击退强度和方向）
## @param receiver 受击目标的区域接收者
func _update_push(damage_data:DamageDataResource, receiver:AreaReceiver2D)->void:
	# 计算目标与击退传输器的世界坐标距离
	var _distance:Vector2 = receiver.global_position - push_transmitter.global_position
	# 应用轴补偿计算逻辑距离（平衡X/Y轴缩放影响）
	var _distance_length:float = (_distance * axis_compensation).length()
	# 计算距离比例（0.0~1.0，超出半径时取1.0）
	var _interpolation:float = min(_distance_length / kickback_radius, 1.0)
	# 通过曲线获取插值后的强度比例（曲线X轴为_distance_length / kickback_radius）
	var _t:float = kickback_curve.sample(_interpolation)
	# 计算最终击退强度（从最大值线性插值到最小值）
	damage_data.kickback_strength = lerp(kickback_max, kickback_min, _t)
	
	# 根据距离设置击退方向：
	if _distance_length > 2.0:  # 距离足够远时，方向为目标远离传输器的方向
		damage_data.direction = _distance.normalized()
	else:  # 距离过近时，使用追逐方向作为击退方向（避免零向量）
		damage_data.direction = chase_player.direction.normalized()
