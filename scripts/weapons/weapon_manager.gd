# 武器管理节点：统一管理玩家或角色的武器系统，支持武器切换、库存更新及拾取丢弃
class_name WeaponManager  # 定义类名，作为场景中的武器管理核心节点
extends Node2D  # 继承自2D节点，支持场景树管理和2D节点操作


# -------------------- 信号（武器状态通知） --------------------
## 当当前激活武器变更时触发（携带新旧武器信息）
signal weapon_changed(old_weapon:Weapon, new_weapon:Weapon)  

# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点：存储武器库存、输入资源等全局配置
@export var resource_node:ResourceNode  
## 武器发射物碰撞掩码：传递给实例化武器的projectile
@export_flags_2d_physics var collision_mask:int  
## 物品拾取实例资源：武器丢弃时生成的拾取物预制体
@export var item_pickup_instance_resource:InstanceResource  

# -------------------- 成员变量（运行时状态） --------------------
## 已实例化的武器列表（按库存顺序存储）
var weapon_list:Array[Weapon]
## 武器路径与实例的字典映射（快速查找已加载武器）
var weapon_dictionary:Dictionary = {}  
## 当前激活的武器实例（非null时处于启用状态）
var current_weapon:Weapon = null  
## 武器库存资源（管理可使用的武器列表和选中索引）
var weapon_inventory:ItemCollectionResource  
## 输入资源（获取切换武器的输入信号）
var input_resource:InputResource  
## 武器场景缓存（避免重复加载相同武器场景）
var weapon_scene_cache:Array[PackedScene]


# -------------------- 生命周期方法（节点初始化与资源连接） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponManager: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if item_pickup_instance_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponManager: 物品拾取实例资源节点（item_pickup_instance_resource）未配置", LogManager.LogLevel.ERROR)
		return
	
	_setup_weapon_inventory()  # 初始化武器库存
	_setup_input_connection()  # 连接输入信号
	request_ready()  # 配合对象池使用（标记节点准备完成）

# -------------------- 节点退出处理（清理资源与信号） --------------------
func _exit_tree() -> void:
	# 断开库存变更信号
	if weapon_inventory != null:
		weapon_inventory.selected_changed.disconnect(set_weapon_index)
		weapon_inventory.updated.disconnect(_update_weapon_inventory)
		weapon_inventory.removed.disconnect(_on_remove)
	# 断开输入信号
	if input_resource != null:
		input_resource.switch_weapon.disconnect(_on_switch_weapon)


# -------------------- 核心逻辑：初始化武器库存 --------------------
func _setup_weapon_inventory()->void:
	# 获取武器库存资源（必须配置，否则无法管理武器）
	weapon_inventory = resource_node.get_resource("weapons")
	if weapon_inventory == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponManager: 武器库存资源（weapons）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 清理已有子节点（避免重复初始化）
	for _child in get_children():
		remove_child(_child)
		_child.queue_free()
	
	## 重置数据结构
	weapon_dictionary.clear()
	weapon_list.clear()
	weapon_scene_cache.clear()
	
	# 遍历库存中的每个武器配置
	for _item:ItemResource in weapon_inventory.list:
		var _path:String = _item.scene_path  # 武器场景路径
		var _scene:PackedScene = load(_path)  # 加载场景（同步加载，可能阻塞主线程）
		weapon_scene_cache.append(_scene)  # 缓存场景避免重复加载
		var _weapon:Weapon = _add_new_weapon_from_scene(_scene)  # 实例化武器
		weapon_list.append(_weapon)  # 添加到武器列表
		weapon_dictionary[_path] = _weapon  # 建立路径到实例的映射
	
	# 连接库存变更信号（响应添加/删除/选中变更）
	weapon_inventory.updated.connect(_update_weapon_inventory)
	weapon_inventory.removed.connect(_on_remove)
	weapon_inventory.selected_changed.connect(set_weapon_index)
	set_weapon_index()  # 初始化当前武器


# -------------------- 核心逻辑：建立输入信号连接 --------------------
func _setup_input_connection()->void:
	input_resource = resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponManager: 输入资源（input）未配置", LogManager.LogLevel.ERROR)
		return
	input_resource.switch_weapon.connect(_on_switch_weapon)  # 连接切换武器信号


# -------------------- 辅助方法：从场景实例化武器 --------------------
func _add_new_weapon_from_scene(scene:PackedScene)->Weapon:
	var _weapon:Weapon = scene.instantiate() as Weapon  # 实例化武器节点
	if _weapon == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponManager: 武器场景实例化失败", LogManager.LogLevel.ERROR)
		return
	
	# 初始化武器配置（在加入场景树前配置）
	_weapon.enabled = false  # 初始禁用，切换时启用
	_weapon.resource_node = resource_node  # 传递资源节点引用
	_weapon.collision_mask = collision_mask  # 设置碰撞掩码
	_weapon.damage_data_resource = _weapon.damage_data_resource.duplicate()  # 复制伤害数据避免共享引用
	
	add_child(_weapon)  # 将武器添加为子节点
	return _weapon


# -------------------- 库存更新回调：响应武器列表变更 --------------------
func _update_weapon_inventory()->void:
	weapon_list.clear()  # 清空现有列表
	
	# 重新构建武器列表（处理新增/更新的武器）
	for _item:ItemResource in weapon_inventory.list:
		var _path:String = _item.scene_path
		var _weapon:Weapon
		if weapon_dictionary.has(_path):
			# 已存在的武器直接添加到列表
			_weapon = weapon_dictionary[_path]
			weapon_list.append(_weapon)
			continue
		# 不存在的武器加载新场景
		var _scene:PackedScene = load(_path)
		weapon_scene_cache.append(_scene)
		_weapon = _add_new_weapon_from_scene(_scene)
		weapon_list.append(_weapon)
		weapon_dictionary[_path] = _weapon
	
	set_weapon_index()  # 更新当前武器


# -------------------- 测试方法：丢弃当前选中武器（TODO: 完善拾取逻辑） --------------------
func test_drop()->void:
	weapon_inventory.drop()  # 触发库存丢弃逻辑


# -------------------- 库存移除回调：处理武器删除或丢弃 --------------------
func _on_remove(item:WeaponItemResource, is_dropped:bool)->void:
	var _path:String = item.scene_path
	if !weapon_dictionary.has(_path):
		return  # 路径不存在时跳过
	
	# 从场景树移除武器并释放资源
	var _weapon:Weapon = weapon_dictionary[_path]
	weapon_dictionary.erase(_path)
	remove_child(_weapon)
	_weapon.queue_free()
	
	if is_dropped:
		# 生成武器拾取物（TODO: 完善配置逻辑）
		var _config_callback:Callable = func (inst:ItemPickup)->void:
			inst.item_resource = item  # 设置拾取物对应的物品资源
			inst.global_position = global_position  # 设置拾取物位置
		item_pickup_instance_resource.instance(_config_callback)


# -------------------- 输入回调：处理武器切换输入 --------------------
func _on_switch_weapon(dir:int)->void:
	if dir == 1:
		# 向前切换（索引递减，如从索引2切到1）
		weapon_inventory.set_selected(max(0, weapon_inventory.selected - 1))
	elif dir == -1:
		# 向后切换（索引递增，如从索引1切到2）
		weapon_inventory.set_selected(min(weapon_inventory.selected + 1, weapon_inventory.list.size() - 1))

# -------------------- 核心方法：根据库存选中索引设置当前武器 --------------------
func set_weapon_index()->void:
	if weapon_list.is_empty():
		return  # 无武器时不处理
	
	# 禁用旧武器
	var _old_weapon = current_weapon
	if current_weapon != null:
		current_weapon.set_enabled(false)
		current_weapon = null
	
	# 启用新武器
	current_weapon = weapon_list[weapon_inventory.selected]
	current_weapon.set_enabled(true)
	
	# 发射武器变更信号（携带新旧武器实例）
	weapon_changed.emit(_old_weapon, current_weapon)


# -------------------- 公有方法：获取当前武器的伤害资源 --------------------
func get_current_damage() -> DamageResource:
	return current_weapon.damage_resource if current_weapon != null else null
