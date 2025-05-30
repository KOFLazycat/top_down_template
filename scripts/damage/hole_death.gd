# 洞穴死亡处理节点：监听洞穴触发事件，处理角色死亡逻辑
class_name HoleDeath  # 定义类名，可在场景中作为死亡判定节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 节点是否启用（禁用时忽略所有逻辑）
@export var enabled:bool = true  
## 洞穴触发节点（监听触洞事件）
@export var hole_trigger:HoleTrigger  
## 资源节点（存储健康和伤害资源）
@export var resource_node:ResourceNode  


# -------------------- 生命周期方法（节点初始化与信号连接） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("HoleDeath: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if hole_trigger == null:
		Log.entry("HoleDeath: 节点（hole_trigger）未配置", LogManager.LogLevel.ERROR)
		return
	if !enabled:  # 节点禁用时直接返回
		return
	
	# 连接洞穴触发节点的触洞事件（触洞时触发死亡逻辑）
	hole_trigger.hole_touched.connect(_insta_kill)
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(
		hole_trigger.hole_touched.disconnect.bind(_insta_kill),  # 断开信号与回调的连接
		CONNECT_ONE_SHOT  # 仅触发一次
	)


# -------------------- 核心逻辑：立即击杀角色并传递伤害数据 --------------------
## @brief 触洞时执行的死亡逻辑（立即击杀角色并记录伤害数据）
func _insta_kill()->void:
	# 获取健康资源（确保非空）
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if _health_resource == null:
		Log.entry("HoleDeath: 健康资源（health）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 记录当前生命值（用于伤害数据）
	var _hp:float = _health_resource.hp
	
	# 立即击杀角色（HealthResource 需实现 insta_kill 方法）
	_health_resource.insta_kill()
	
	# 创建伤害数据资源（记录总伤害和击杀状态）
	var _damage_data:DamageDataResource = DamageDataResource.new("damage")
	_damage_data.total_damage = _hp  # 总伤害为当前生命值（即秒杀）
	_damage_data.is_kill = true       # 标记为击杀伤害
	
	# 获取伤害资源并传递伤害数据
	var _damage:DamageResource = resource_node.get_resource("damage")
	if _damage == null:
		Log.entry("HoleDeath: 伤害资源（damage）未配置", LogManager.LogLevel.ERROR)
		return
	_damage.receive(_damage_data)    # 通知伤害系统处理死亡伤害
