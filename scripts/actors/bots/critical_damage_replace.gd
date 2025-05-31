# 临界伤害替换节点：当敌人受到暴击且血量低于阈值时，替换为另一个实例（如精英怪变形成普通怪）
class_name CriticalDamageReplace  # 定义类名，可在场景中作为敌人临界状态处理节点
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储健康、伤害等资源）
@export var resource_node:ResourceNode  
## 对象池节点（用于回收当前节点）
@export var pool_node:PoolNode  
## 当前激活的敌人节点（关联敌人资源与状态）
@export var active_enemy:ActiveEnemy  
## 临界血量阈值：当暴击伤害后血量低于此值时触发替换
@export var health_treshold:float = 20.0  
## 替换实例资源：达到临界状态时生成的新实例（如敌人变形后的预制体）
@export var replacement_instance_resource:InstanceResource  
## 替换时播放的音效资源
@export var sound_effect:SoundResource  
## 伤害数据接收器：用于控制伤害数据的传递（触发替换后禁用）
@export var damage_data_receiver:DataChannelReceiver  


# -------------------- 成员变量（运行时状态） --------------------
var health_resource:HealthResource  # 敌人的健康资源（用于获取血量和死亡状态）
var is_replaced:bool = false  # 替换状态标记（避免重复触发替换）


# -------------------- 生命周期方法（节点初始化与信号连接） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CriticalDamageReplace: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 获取健康资源（确保非空，否则无法获取血量和死亡状态）
	health_resource = resource_node.get_resource("health")
	if health_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CriticalDamageReplace: 健康资源（health）未配置，临界替换逻辑失效", LogManager.LogLevel.ERROR)
		return
	
	# 获取伤害资源并连接受击信号（暴击伤害触发替换逻辑）
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	if _damage_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CriticalDamageReplace: 伤害资源（damage）未配置，无法监听受击事件", LogManager.LogLevel.ERROR)
		return
	_damage_resource.received_damage.connect(_on_damage)  # 受击时触发替换检查
	
	# 对象池相关初始化（确保节点可被回收）
	request_ready()
	is_replaced = false  # 初始未替换
	damage_data_receiver.enabled = true  # 启用伤害数据接收
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(
		_damage_resource.received_damage.disconnect.bind(_on_damage), 
		CONNECT_ONE_SHOT  # 仅触发一次断开操作
	)


# -------------------- 受击事件回调（核心替换逻辑） --------------------
func _on_damage(damage:DamageDataResource)->void:
	if is_replaced:
		return  # 已替换则跳过后续逻辑
	
	if !damage.is_critical:
		return  # 非暴击伤害不触发替换
	
	if health_resource.is_dead:
		return  # 敌人已死亡则不触发替换
	
	if health_resource.hp > health_treshold:
		return  # 当前血量高于阈值，不触发替换
	
	# -------------------- 触发替换流程 --------------------
	is_replaced = true  # 标记为已替换
	damage_data_receiver.enabled = false  # 禁用伤害数据接收（避免重复触发）
	
	# 提取并缓存关键数据（避免资源引用在替换后失效）
	var _push_vector:Vector2 = damage.kickback_strength * damage.direction  # 击退向量
	var _current_hp:float = health_resource.hp  # 当前剩余血量
	var _active_enemy_branch:ActiveEnemyResource = active_enemy.enemy_resource  # 敌人资源分支
	
	## 定义实例初始化回调（在新实例准备完成时执行）
	var _ready_callback:Callable = func (inst:Node)->void:
		var _resource_node:ResourceNode = inst.get_node("ResourceNode")  # 获取新实例的资源节点
		if _resource_node == null:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CriticalDamageReplace: 新实例缺少ResourceNode节点", LogManager.LogLevel.ERROR)
			return
		
		# 同步血量（触发伤害闪烁效果）
		var _health_resource:HealthResource = _resource_node.get_resource("health")
		if _health_resource == null:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CriticalDamageReplace: 新实例 健康资源（health）未配置", LogManager.LogLevel.ERROR)
			return
		_health_resource.add_hp.call_deferred(_current_hp - _health_resource.hp)  # 差值补血
		
		# 应用击退效果（通过推挤资源添加冲量）
		var _push_resource:PushResource = _resource_node.get_resource("push")
		if _push_resource == null:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CriticalDamageReplace: 新实例 推挤资源（push）未配置", LogManager.LogLevel.ERROR)
			return
		else:
			_push_resource.add_impulse(_push_vector)
		
		# 重新启用实例的ready状态（支持对象池复用）
		inst.request_ready()
	
	## 定义实例配置回调（在新实例创建时执行）
	var _config_callback:Callable = func (inst:Node)->void:
		inst.global_position = owner.global_position  # 复制当前节点位置
		inst.ready.connect(_ready_callback.call_deferred.bind(inst), CONNECT_ONE_SHOT)  # 延迟初始化
		
		# 将新实例插入敌人分支（假设ActiveEnemy负责管理子节点）
		ActiveEnemy.insert_child(inst, _active_enemy_branch)
	
	# 执行替换流程
	sound_effect.play_managed()  # 播放替换音效
	replacement_instance_resource.instance(_config_callback)  # 实例化替换对象
	active_enemy.remove_self()  # 从敌人管理系统中移除当前敌人
	pool_node.pool_return()  # 将当前节点返回对象池
