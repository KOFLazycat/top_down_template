# 史莱姆分裂节点：处理史莱姆死亡时分裂为多个子实例的逻辑
class_name SlimeSplit  # 定义类名，可在场景中作为史莱姆分裂控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储伤害资源等配置）
@export var resource_node:ResourceNode  
## 分裂后生成的实例资源（如小史莱姆预制体）
@export var split_instance_resource:InstanceResource  
## 分裂角度数组（相对于伤害方向的偏移角度，单位：度）
@export var angles:Array[float] = [-25.0, 25.0, -65.0, 65.0 ]  
## 分裂实例生成距离（从父节点位置出发的距离）
@export var spawn_distance:float = 8.0  
## 轴乘数资源（调整不同轴的生成方向缩放，如顶视角透视效果）
@export var axis_multiplication:Vector2Resource  
## 位置节点（分裂位置参考点，通常为史莱姆自身节点）
@export var position_node:Node2D  
## 活跃敌人节点（关联敌人资源与分裂后的子节点管理）
@export var active_enemy:ActiveEnemy  


# -------------------- 生命周期方法（节点初始化与信号连接） --------------------
func _ready() -> void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SlimeSplit: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if split_instance_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SlimeSplit: 分裂slime实例资源节点（split_instance_resource）未配置", LogManager.LogLevel.ERROR)
		return
	if position_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SlimeSplit: 位置节点（position_node）未配置", LogManager.LogLevel.ERROR)
		return
	if active_enemy == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SlimeSplit: 活跃敌人节点（active_enemy）未配置", LogManager.LogLevel.ERROR)
		return
	if angles.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SlimeSplit: 分裂角度数组未配置", LogManager.LogLevel.ERROR)
		return
	# 获取伤害资源并连接受击信号（仅在击杀时触发分裂）
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	if _damage_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SlimeSplit: 伤害资源（damage）未配置，分裂逻辑失效", LogManager.LogLevel.ERROR)
		return
	_damage_resource.received_damage.connect(_on_damage_received)  # 受击时触发分裂检查
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(
		_damage_resource.received_damage.disconnect.bind(_on_damage_received), 
		CONNECT_ONE_SHOT  # 确保仅断开一次
	)
	
	# 配合对象池使用（标记节点准备完成）
	request_ready()


# -------------------- 受击事件回调（核心分裂逻辑） --------------------
func _on_damage_received(damage:DamageDataResource)->void:
	if !damage.is_kill:
		return  # 非击杀伤害不触发分裂
	
	# 获取当前敌人资源分支（用于子节点管理）
	var _active_enemy_branch:ActiveEnemyResource = active_enemy.enemy_resource
	assert(_active_enemy_branch != null, "敌人资源分支为空，无法插入子节点")
	
	# 获取伤害方向和分裂参考位置
	var _direction:Vector2 = damage.direction.normalized()  # 标准化伤害方向
	var _pos:Vector2 = position_node.global_position         # 分裂中心位置
	
	# 遍历每个分裂角度，生成对应的子实例
	for _degree:float in angles:
		## 定义实例配置回调（设置子实例的位置和方向）
		var _config_callback:Callable = func (inst:Node)->void:
			# 计算带角度偏移的生成方向（将角度转换为弧度并应用轴乘数）
			var _dir:Vector2 = _direction.rotated(deg_to_rad(_degree)) * axis_multiplication.value
			_dir = _dir.normalized()  # 标准化方向向量
			
			# 计算子实例生成位置（中心位置 + 方向 * 生成距离）
			inst.global_position = _pos + spawn_distance * _dir
			
			# 将子实例插入敌人管理系统（由ActiveEnemy负责维护子节点）
			ActiveEnemy.insert_child(inst, _active_enemy_branch)
		
		# 实例化分裂后的子节点并应用配置回调
		split_instance_resource.instance(_config_callback)
	
	# 从敌人管理系统中移除当前节点（触发销毁或回收）
	active_enemy.remove_self()
