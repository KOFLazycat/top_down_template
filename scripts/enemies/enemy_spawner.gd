# 敌人生成器节点：管理敌人波次生成、位置过滤及视觉特效
class_name EnemySpawner  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类

# 信号：当敌人被消灭时触发，传递被消灭的敌人实例
signal enemy_killed(enemy:ActiveEnemy)

# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var enemy_manager:EnemyManager  # 敌人波次管理器（关联波次配置与生成逻辑）
@export var spawn_mark_instance_resource:InstanceResource  # 生成标记预制体（生成前的视觉提示，如地面标记）
@export var spawn_partickle_instance_resource:InstanceResource  # 生成粒子特效预制体（生成时的特效，如烟雾）
@export var enemy_count_resource:IntResource  # 剩余敌人数量资源（同步显示与逻辑计数）
@export var spawn_point_resource:SpawnPointResource  # 生成点资源（存储普通/BOSS 生成位置列表）
@export var fight_mode_resource:BoolResource  # 战斗模式开关资源（控制生成逻辑是否激活）

# -------------------- 成员变量（运行时状态） --------------------
## 最大允许同时存在的敌人数量（当前基于生成点数量，后续可扩展难度影响）
var max_allowed_count:int

# -------------------- 生命周期方法（节点初始化与清理） --------------------
func _ready()->void:
	# 确保关键资源已配置
	if enemy_count_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemySpawner: 敌人数量资源未配置", LogManager.LogLevel.ERROR)
		return
	if spawn_point_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemySpawner: 生成点资源未配置", LogManager.LogLevel.ERROR)
		return
	if spawn_mark_instance_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemySpawner: 生成标记资源未配置", LogManager.LogLevel.ERROR)
		return
	if fight_mode_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemySpawner: 战斗模式资源未配置", LogManager.LogLevel.ERROR)
		return
	
	# 战斗模式激活时启用_process，关闭时禁用（节省性能）
	fight_mode_resource.changed_true.connect(set_process.bind(true))
	fight_mode_resource.changed_false.connect(set_process.bind(false))
	set_process(fight_mode_resource.value)  # 初始化_process状态
	
	# 节点退出时清理资源（避免内存泄漏）
	tree_exiting.connect(_cleanup)
	
	# 延迟初始化最大允许敌人数量（确保资源加载完成）
	_setup_active_count.call_deferred()


func _setup_active_count()->void:
	# TODO：当前逻辑基于生成点数量限制同时生成的敌人，后续可结合敌人威胁值或难度动态计算
	max_allowed_count = spawn_point_resource.position_list.size()


func _cleanup()->void:
	# 清理生成点列表（避免残留引用）
	spawn_point_resource.position_list.clear()
	spawn_point_resource.boss_position_list.clear()
	# 重置敌人树状结构根节点（释放所有敌人实例引用）
	ActiveEnemy.root = ActiveEnemyResource.new()


# -------------------- 核心逻辑：每帧检查并生成敌人 --------------------
func _process(_delta: float) -> void:
	# 获取当前活跃敌人数量（通过树状结构根节点统计）
	var _active_count:int = ActiveEnemy.root.nodes.size() + ActiveEnemy.root.children.size()
	
	# 检查是否超过最大允许数量或剩余敌人不足
	if max_allowed_count - _active_count < 1 || _active_count >= max_allowed_count:
		return
	if _active_count + 1 > enemy_count_resource.value:
		return
	
	# 生成敌人生成标记（延迟实际生成，先显示视觉提示）
	_create_spawn_mark()


func _create_spawn_mark()->void:
	if enemy_manager.wave_queue.waves.is_empty():
		return  # 无剩余波次时返回
	
	if enemy_manager.wave_queue.waves.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemySpawner: 敌人波次为空", LogManager.LogLevel.ERROR)
		return
	var _current_wave:SpawnWaveList = enemy_manager.wave_queue.waves.front()  # 获取当前波次
	
	# 根据是否为BOSS波次筛选生成点（BOSS使用独立位置列表）
	var _free_positions:Array[Vector2]
	if _current_wave.is_boss:
		_free_positions = spawn_point_resource.boss_position_list.filter(_filter_free_position)
	else:
		_free_positions = spawn_point_resource.position_list.filter(_filter_free_position)
	if _free_positions.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemySpawner: 无可用生成点生成敌人", LogManager.LogLevel.ERROR)
		return# 无可用生成点时返回
	
	var _spawn_position:Vector2 = _free_positions.pick_random()  # 随机选择生成位置
	
	# 配置生成标记：实例化后设置位置，并在标记销毁时触发敌人生成（单次连接避免重复）
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _spawn_position
		inst.tree_exiting.connect(_create_enemies.bind(_spawn_position), CONNECT_ONE_SHOT)
	spawn_mark_instance_resource.instance(_config_callback)


func _create_enemies(spawn_position:Vector2)->void:
	# 生成生成粒子特效（位置同步）
	var _partickle_config:Callable = func(inst:Node2D)->void:
		inst.global_position = spawn_position
	spawn_partickle_instance_resource.instance(_partickle_config)
	
	# 生成敌人实例：配置位置并加入树状管理结构，注册销毁回调
	var _enemy_config:Callable = func (inst:Node2D)->void:
		inst.global_position = spawn_position
		ActiveEnemy.insert_child(inst, ActiveEnemy.root, _erase_enemy)  # 插入根节点分支
	enemy_manager.wave_queue.waves.front().instance_list.pick_random().instance(_enemy_config)


func _erase_enemy(enemy:ActiveEnemy)->void:
	# 敌人被消灭时更新剩余数量，并触发信号（通知 UI 或游戏逻辑）
	enemy_count_resource.set_value(enemy_count_resource.value - 1)
	enemy_killed.emit(enemy)


# -------------------- 辅助方法：过滤可用生成位置（距离校验） --------------------
func _filter_free_position(position:Vector2)->bool:
	# 定义安全距离的平方（避免计算平方根，提升性能）
	const FREE_DISTANCE_SQUARED:float = 116.0 * 116.0
	var _closest_dist_squared:float = 999999.0  # 初始化为极大值
	
	# 遍历所有活跃敌人，计算与生成点的距离平方
	var instance_list:Array[Node2D] = ActiveEnemy.active_instances
	for inst:Node2D in instance_list:
		if inst == null:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemySpawner: 活跃敌人实例为空", LogManager.LogLevel.ERROR)
			continue
		var _inst_dist_squared:float = (inst.global_position - position).length_squared()
		if _inst_dist_squared < _closest_dist_squared:
			_closest_dist_squared = _inst_dist_squared
	
	# 距离平方大于安全距离时返回true（位置可用）
	return _closest_dist_squared > FREE_DISTANCE_SQUARED


# -------------------- 未使用的冗余方法（可移除） --------------------
func _config_spawn_mark(inst:Node2D, spawn_position:Vector2)->void:
	# 注：此方法与_create_spawn_mark中的lambda逻辑重复，未被调用
	inst.global_position = spawn_position
	inst.tree_exiting.connect(_create_enemies.bind(spawn_position), CONNECT_ONE_SHOT)


func _config_spawn_particles(inst:Node2D, spawn_position:Vector2)->void:
	# 注：此方法未被调用，属于冗余代码
	inst.global_position = spawn_position
