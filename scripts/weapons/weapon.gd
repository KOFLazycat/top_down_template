# 武器节点：管理武器的启用状态、碰撞属性及伤害报告逻辑
class_name Weapon  # 定义类名，可在场景中作为武器节点使用
extends Node2D  # 继承自2D节点（支持可视化渲染和2D物理交互）


# -------------------- 信号（状态变更通知） --------------------
## 当武器启用状态变更时触发（通知外部系统，如UI、角色状态机）
signal enabled_changed(enabled:bool)  

# -------------------- 导出变量（编辑器可视化配置） --------------------
## 武器是否启用（控制可见性和攻击能力）
@export var enabled:bool = true  
## 武器发射物的碰撞掩码（2D物理层掩码，用于设置Projectile的collision_mask）
@export_flags_2d_physics var collision_mask:int  
## 资源节点（存储伤害资源等配置数据）
@export var resource_node:ResourceNode  
## 伤害数据资源（定义武器的伤害数值、类型等属性）
@export var damage_data_resource:DamageDataResource  


# -------------------- 生命周期方法（节点准备完成） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("Weapon: 资源节点（resource_node）未配置，武器初始化失败", LogManager.LogLevel.ERROR)
		return
	if damage_data_resource == null:
		Log.entry("Weapon: 伤害数据资源（damage_data_resource）未配置，武器无法报告伤害", LogManager.LogLevel.ERROR)
		return
	
	set_enabled(enabled)  # 初始化启用状态（同步可见性和信号）
	
	# 获取伤害资源（用于报告伤害数值到角色系统）
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	if _damage_resource == null:
		Log.entry("Weapon: 伤害资源（damage）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 将伤害数据资源的回调指向伤害资源的报告方法（建立伤害传递链路）
	damage_data_resource.report_callback = _damage_resource.report
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()


# -------------------- 状态控制方法（启用/禁用武器） --------------------
## @brief 设置武器启用状态，控制可见性并触发状态变更信号
## @param value true 启用武器，false 禁用武器
func set_enabled(value:bool)->void:
	enabled = value
	visible = enabled  # 同步可见性（禁用时隐藏武器节点）
	enabled_changed.emit(enabled)
