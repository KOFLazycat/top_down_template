# 投射物配置节点：集中管理投射物的伤害属性、碰撞层及数据传输逻辑
class_name ProjectileSetup  # 定义类名，作为投射物初始化配置核心节点
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 基础伤害数组：包含多种伤害类型资源（如物理伤害、元素伤害等）
@export var base_damage:Array[DamageTypeResource]  
## 状态伤害数组：包含施加给目标的状态效果资源（如中毒、燃烧等）
@export var status_damage:Array[DamageStatusResource]  
## 击退强度：命中目标时施加的击退力度（像素/秒）
@export var kickback:float  

@export_category("References")  # 分组标签，便于编辑器管理
## 投射物引用：需要配置的Projectile节点（绑定具体投射物实例）
@export var projectile:Projectile  
## 区域传输器：用于Area2D碰撞检测的伤害传输组件
@export var area_transmitter:AreaTransmitter2D  
## 形状投射传输器：用于ShapeCast2D碰撞检测的伤害传输组件
@export var shape_transmitter:ShapeCastTransmitter2D  
## 数据通道传输器：负责传递伤害数据的通道组件
@export var data_channel_transmitter:DataChannelTransmitter 


# -------------------- 生命周期方法（初始化配置） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileSetup: 投射物引用（projectile）未配置", LogManager.LogLevel.ERROR)
		return
	if data_channel_transmitter == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileSetup: 数据通道传输器（data_channel_transmitter）未配置", LogManager.LogLevel.ERROR)
		return
	# 获取投射物携带的伤害数据资源（核心数据容器）
	var _damage_data_resource:DamageDataResource = projectile.damage_data_resource
	
	# 配置区域传输器的碰撞层（合并投射物的碰撞掩码）
	if area_transmitter != null:
		area_transmitter.collision_mask = Bitwise.append_flags(area_transmitter.collision_mask, projectile.collision_mask)
	# 配置形状投射传输器的碰撞层（同上）
	if shape_transmitter != null:
		shape_transmitter.collision_mask = Bitwise.append_flags(shape_transmitter.collision_mask, projectile.collision_mask)
	
	# 绑定伤害数据资源到数据通道传输器
	data_channel_transmitter.transmission_resource = _damage_data_resource
	# 连接数据更新请求信号（当需要更新伤害数据时触发）
	if !data_channel_transmitter.update_requested.is_connected(_on_update_requested):
		data_channel_transmitter.update_requested.connect(_on_update_requested)


# -------------------- 数据更新回调（动态配置伤害参数） --------------------
## @brief 当数据通道请求更新时，动态设置伤害数据的属性
## @param transmission_resource 传输资源（强制转换为DamageDataResource）
## @param _receiver 受击目标（未使用，仅作为信号参数）
func _on_update_requested(transmission_resource:TransmissionResource, _receiver:AreaReceiver2D)->void:
	var _damage_data_resource:DamageDataResource = transmission_resource as DamageDataResource
	
	## TODO: 优化点：考虑使用对象池或复制机制避免共享数据污染
	# 设置伤害方向为投射物当前移动方向
	_damage_data_resource.direction = projectile.direction
	# 设置击退强度
	_damage_data_resource.kickback_strength = kickback
	# 添加基础伤害数组（注意：多次调用会重复添加，需确保调用时机）
	_damage_data_resource.base_damage.append_array(base_damage)
	# 添加状态伤害数组（同上）
	_damage_data_resource.status_list.append_array(status_damage)
