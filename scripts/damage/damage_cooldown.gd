# 伤害冷却控制器：管理受击后的冷却时间，避免连续伤害
class_name DamageCooldown  # 定义类名，可在场景中作为冷却控制节点使用
extends Node  # 继承自基础节点类


# -------------------- 信号（冷却状态通知） --------------------
## 冷却开始时触发（通知外部冷却已启动）
signal cooldown_started
## 冷却结束时触发（通知外部冷却已完成）
signal cooldown_finished


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储健康资源和伤害资源）
@export var resource_node:ResourceNode  
## 冷却时间（单位：秒，0 表示无冷却）
@export var cooldown_time:float = 0.0  


# -------------------- 成员变量（运行时资源引用） --------------------
var health_resource:HealthResource  # 健康资源（监听受击事件）
var damage_resource:DamageResource  # 伤害资源（控制是否可接收伤害）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# 从资源节点获取健康资源（用于监听受击事件）
	health_resource = resource_node.get_resource("health")
	if health_resource == null:
		Log.entry("健康资源（health）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 从资源节点获取伤害资源（用于控制可受击状态）
	damage_resource = resource_node.get_resource("damage")
	if damage_resource == null:
		Log.entry("伤害资源（damage）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 连接健康资源的受击信号（受击时触发冷却）
	health_resource.damaged.connect(_start_cooldown)
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(health_resource.damaged.disconnect.bind(_start_cooldown), CONNECT_ONE_SHOT)


# -------------------- 冷却启动逻辑（受击时触发） --------------------
## @brief 受击后启动冷却，期间禁止接收伤害
## @param _d 受击数值（未使用，保留参数）
func _start_cooldown(_d: float)->void:
	# 若冷却时间为0，直接返回（无冷却逻辑）
	if cooldown_time == 0.0:
		Log.entry("冷却时间（cooldown_time）为0，冷却逻辑未启动", LogManager.LogLevel.WARNING)
		return
	
	# 禁止接收伤害（通过伤害资源标记）
	damage_resource.set_can_receive_damage(false)
	
	# 创建补间动画（延迟cooldown_time后触发冷却结束）
	# 绑定冷却结束回调
	# 设置延迟时间
	var _tween:Tween = create_tween()
	_tween.tween_callback(_on_cooldown_finish).set_delay(cooldown_time)  
	
	# 触发冷却开始信号（通知外部冷却已启动）
	cooldown_started.emit()


# -------------------- 冷却结束逻辑（补间回调） --------------------
## @brief 冷却结束后恢复可接收伤害状态
func _on_cooldown_finish()->void:
	# 恢复接收伤害（通过伤害资源标记）
	damage_resource.set_can_receive_damage(true)
	
	# 触发冷却结束信号（通知外部冷却已完成）
	cooldown_finished.emit()
