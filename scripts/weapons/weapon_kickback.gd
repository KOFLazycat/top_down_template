# 武器后坐力控制器：在射击时向武器使用者施加反向冲量，实现后坐力反馈
class_name WeaponKickback  # 定义类名，作为后坐力逻辑的核心组件
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 武器引用：绑定当前武器节点（提供资源节点访问能力）
@export var weapon:Weapon  
## 武器触发组件：监听射击事件并获取射击方向（需绑定WeaponTrigger节点）
@export var weapon_trigger:WeaponTrigger  
## 后坐力强度：施加冲量的大小（数值越大，后坐力越明显）
@export var kickback_strength:float  

# -------------------- 成员变量（运行时状态） --------------------
## 推动资源：存储用户的物理推动数据（实际应用后坐力的核心资源）
var push_resource:PushResource  


# -------------------- 生命周期方法（资源初始化与信号连接） --------------------
func _ready()->void:
	if weapon == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponKickback: 武器引用节点（weapon）未配置", LogManager.LogLevel.ERROR)
		return
	if weapon_trigger == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponKickback: 武器触发组件（weapon_trigger）未配置", LogManager.LogLevel.ERROR)
		return
	if weapon.resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponKickback: 武器资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# 从武器的资源节点中获取"push"类型资源（用于物理推动）
	push_resource = weapon.resource_node.get_resource("push")
	if push_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponRotation: push类型资源（push_resource）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 连接武器触发组件的射击事件到后坐力应用方法（避免重复连接）
	if !weapon_trigger.shoot_event.is_connected(apply_kickback):
		weapon_trigger.shoot_event.connect(apply_kickback)
	
	# 当节点是池化节点（如对象池复用）时，确保子节点完成初始化
	request_ready()  


# -------------------- 后坐力应用核心方法（响应射击事件） --------------------
## @brief 射击时向用户施加与射击方向相反的冲量，模拟后坐力
func apply_kickback()->void:
	# 获取武器的射击方向（由触发组件提供，通常为武器瞄准方向）
	var direction:Vector2 = weapon_trigger.get_direction().normalized()
	
	# 计算后坐力方向（与射击方向相反）并施加冲量
	# kickback_strength控制冲量大小，-direction确保方向与射击方向相反
	push_resource.add_impulse(kickback_strength * -direction)
