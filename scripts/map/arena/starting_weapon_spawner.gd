# 初始武器生成器：生成可选武器拾取物，所有武器被拾取后解锁场景出口
class_name StartingWeaponSpawner  # 定义类名，可在场景中作为节点类型使用
extends Node2D  # 继承自 2D 节点类（支持位置、变换等 2D 属性）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var exit_nodes:Array[SceneEntry]  # 场景出口节点列表（拾取完成后解锁）
@export var position_nodes:Array[Node2D]  # 武器生成位置节点列表（决定武器生成坐标）
@export var weapon_database:ItemCollectionResource  # 武器数据库资源（存储所有可选武器）
@export var weapon_pickup_instance_resource:InstanceResource  # 武器拾取物预制体（生成的可交互武器节点）


# -------------------- 成员变量（运行时状态） --------------------
var collision_mask_list:Dictionary  # 缓存出口节点的原始碰撞掩码（用于恢复）
var pickup_count:int  # 剩余未被拾取的武器数量（初始为生成的武器总数）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	_disable_exits()  # 初始化时禁用所有场景出口
	_place_pickups()  # 在指定位置生成武器拾取物


# -------------------- 核心逻辑：禁用场景出口（初始状态） --------------------
func _disable_exits()->void:
	for _exit:SceneEntry in exit_nodes:  # 遍历所有出口节点
		_exit.visible = false  # 隐藏出口（视觉不可见）
		collision_mask_list[_exit] = _exit.collision_mask  # 缓存原始碰撞掩码（用于后续恢复）
		_exit.collision_mask = 0  # 清空碰撞掩码（禁止物理交互）


# -------------------- 核心逻辑：启用场景出口（武器全部拾取后） --------------------
func _enable_exits()->void:
	for _exit:SceneEntry in exit_nodes:  # 遍历所有出口节点
		_exit.visible = true  # 恢复出口可见性
		_exit.collision_mask = collision_mask_list[_exit]  # 恢复原始碰撞掩码（允许物理交互）


# -------------------- 核心逻辑：生成武器拾取物 --------------------
func _place_pickups()->void:
	# 筛选未解锁的武器（从数据库中获取可生成的武器列表）
	var _item_list:Array[WeaponItemResource] = []
	for _item:WeaponItemResource in weapon_database.list:
		if !_item.unlocked:  # 仅选择未解锁的武器（确保玩家需要拾取）
			continue
		_item_list.append(_item)
	
	_item_list.shuffle()  # 随机打乱武器顺序（增加生成随机性）
	
	 # 校验武器列表和位置列表有效性（非断言方式，发布版本仍能处理）
	if _item_list.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "StartingWeaponSpawner: 武器数据库中无可用未解锁武器", LogManager.LogLevel.ERROR)
		return
	if position_nodes.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "StartingWeaponSpawner: 未配置武器生成位置节点", LogManager.LogLevel.ERROR)
		return
	
	# 计算实际生成数量（取位置数量与武器数量的较小值，避免位置或武器不足）
	pickup_count = min(position_nodes.size(), _item_list.size())
	
	# 在指定位置生成武器拾取物
	for i:int in pickup_count:
		var _node:Node2D = position_nodes[i]
		if _node == null || !_node.is_inside_tree():  # 跳过无效节点
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "StartingWeaponSpawner: 位置节点 %d 无效，跳过生成" % i, LogManager.LogLevel.ERROR)
			continue
		var _position:Vector2 = _node.global_position  # 获取第 i 个位置的全局坐标
		var _item:WeaponItemResource = _item_list[i]  # 获取第 i 个武器资源
		# 实例化武器拾取物并配置（使用 bind 传递位置和武器资源）
		weapon_pickup_instance_resource.instance(_pickup_config.bind(_position, _item))


# -------------------- 辅助逻辑：配置武器拾取物实例 --------------------
func _pickup_config(inst:ItemPickup, pickup_position:Vector2, item_resource:WeaponItemResource)->void:
	inst.global_position = pickup_position  # 设置拾取物的生成位置
	inst.item_resource = item_resource  # 绑定对应的武器资源（用于显示/使用）
	inst.success.connect(_finish_pickups)  # 监听拾取成功信号（武器被拾取时触发）


# -------------------- 核心逻辑：武器拾取后更新状态 --------------------
func _finish_pickups()->void:
	pickup_count = max(pickup_count - 1, 0)  # 防止负数
	if pickup_count > 0:  # 仍有未拾取武器时返回
		return
	_enable_exits()  # 所有武器被拾取后解锁场景出口
