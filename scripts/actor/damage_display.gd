# 伤害数字显示控制器：管理伤害数值的可视化显示，合并连续伤害
class_name DamageDisplay  # 定义类名，可在场景中作为伤害显示节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储伤害资源）
@export var resource_node:ResourceNode  
## 伤害数字实例资源（用于生成伤害数字节点，需绑定DamagePoints预制体）
@export var damage_points_instance_resource:InstanceResource
## 伤害数字位置偏移（角色上方为负Y轴）
@export var position_offset:Vector2 = Vector2(0.0, -8.0)  


# -------------------- 常量与成员变量（运行时状态） --------------------
## 伤害数字更新间隔（秒）：避免短时间内显示多个伤害数字，合并连续伤害
const UPDATE_INTERVAL:float = 0.3  
var last_time:float = 0.0  # 上次显示伤害的时间
var last_points:DamagePoints = null  # 上一次显示的伤害数字节点
var last_critical:bool = false  # 上一次伤害是否为暴击
var total_points:float = 0.0  # 累计伤害值（用于合并连续伤害）


# -------------------- 生命周期方法（节点初始化与信号连接） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("DamageDisplay: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if damage_points_instance_resource == null:
		Log.entry("DamageDisplay: 受伤显示实例资源（damage_points_instance_resource）未配置", LogManager.LogLevel.ERROR)
		return
	# 从资源节点获取伤害资源（用于监听伤害数值事件）
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	if _damage_resource == null:
		Log.entry("DamageDisplay: 伤害资源（damage）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 连接伤害资源的received_damage_points信号（伤害数值到达时触发）
	_damage_resource.received_damage_points.connect(_on_damage_points)
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()


# -------------------- 伤害数值处理回调（合并连续伤害并显示） --------------------
## @brief 处理接收到的伤害数值，合并短时间内的连续伤害并显示
## @param points 本次伤害数值（可能为单次或累计值）
## @param is_critical 是否为暴击伤害（影响伤害数字颜色）
func _on_damage_points(points:float, is_critical:bool)->void:
	# 获取当前时间（秒）
	var _time:float = Time.get_ticks_msec() * 0.001
	
	# 检查是否需要合并伤害：
	# 1. 上次暴击状态与本次相同
	# 2. 当前时间在上次显示时间的UPDATE_INTERVAL内
	if last_critical == is_critical && last_points != null && _time < last_time + UPDATE_INTERVAL:
		last_time = _time  # 更新上次显示时间
		total_points += points  # 累计伤害值
		# 更新已有的伤害数字（显示累计值，保持颜色一致）
		last_points.set_displayed_points(int(total_points), last_critical)
		return
	else:
		# 重置累计值（状态变更或间隔超时，创建新伤害数字）
		last_time = _time
		total_points = points
		last_critical = is_critical
	
	# 定义伤害数字实例的配置回调（设置位置和数值）
	var _config_callback:Callable = func (inst:Node2D)->void:
		# 伤害数字显示位置：角色上方偏移8像素（Y轴负方向）
		inst.global_position = owner.global_position + position_offset
		# 将实例转换为DamagePoints类型并设置数值和暴击状态
		(inst as DamagePoints).set_displayed_points(int(total_points), last_critical)
	
	# 实例化伤害数字节点（使用配置回调初始化）
	last_points = damage_points_instance_resource.instance(_config_callback)
