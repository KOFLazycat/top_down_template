# 伤害抗性配置节点：初始化并管理角色的伤害抗性数值
class_name DamageSetup  # 定义类名，可在场景中作为抗性配置节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储伤害资源）
@export var resource_node:ResourceNode  
## 初始抗性列表（配置不同类型的伤害抗性值，如火焰、物理等）
@export var resistance_list:Array[DamageTypeResource]  


# -------------------- 成员变量（运行时状态） --------------------
## 伤害资源实例（用于同步抗性数值）
var damage_resource:DamageResource  


# -------------------- 生命周期方法（节点初始化与抗性设置） --------------------
func _ready() -> void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DamageSetup: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# BUG 修复：解决 Godot 引擎数组复制的已知问题（https://github.com/godotengine/godot/issues/96181）
	# 对导出数组进行深拷贝，避免编辑器修改影响运行时数据
	resistance_list = resistance_list.duplicate()
	
	# 初始化抗性配置
	_setup_resistance()
	
	# 资源节点准备完成时重新配置抗性（配合对象池或动态资源加载）
	if !resource_node.ready.is_connected(_setup_resistance):
		resource_node.ready.connect(_setup_resistance)


# -------------------- 核心逻辑：初始化伤害资源的抗性数值 --------------------
## @brief 从资源节点获取伤害资源，并将配置的抗性列表同步到伤害资源中
func _setup_resistance()->void:
	# 从资源节点获取伤害资源（用于存储抗性数值）
	damage_resource = resource_node.get_resource("damage")
	if damage_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DamageSetup: 伤害资源（damage）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 设置伤害资源的所属节点（通常为当前节点的父节点，如角色根节点）
	damage_resource.owner = owner
	
	# 调整抗性值数组大小为伤害类型总数（枚举DamageTypeResource.DamageType的COUNT值）
	damage_resource.resistance_value_list.resize(DamageTypeResource.DamageType.COUNT)
	# 初始化所有抗性值为0.0（避免旧数据残留）
	damage_resource.resistance_value_list.fill(0.0)
	
	# 遍历配置的抗性列表，将每个抗性类型的数值累加到伤害资源的对应位置
	for _resistance:DamageTypeResource in resistance_list:
		var type_index = _resistance.type
		if type_index < 0 || type_index >= DamageTypeResource.DamageType.COUNT:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DamageSetup: 抗性类型索引 %d 越界（总类型数：%d），跳过该抗性" % [type_index, DamageTypeResource.DamageType.COUNT], LogManager.LogLevel.WARNING)
			continue
		
		# 注意：若存在相同类型的抗性，数值会累加（如多个火焰抗性装备）
		damage_resource.resistance_value_list[type_index] += _resistance.value


# -------------------- 动态操作：添加抗性 --------------------
## @brief 动态添加一个抗性到列表，并更新伤害资源的抗性数值
## @param resistance 要添加的抗性资源（包含类型和数值）
func add_resistance(resistance:DamageTypeResource)->void:
	if resistance.type < 0 || resistance.type >= DamageTypeResource.DamageType.COUNT:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DamageSetup: 无效的抗性类型（索引：%d），无法添加" % resistance.type, LogManager.LogLevel.ERROR)
		return
	# 将新抗性添加到本地列表
	resistance_list.append(resistance)
	# 更新伤害资源中对应类型的抗性数值（累加）
	damage_resource.resistance_value_list[resistance.type] += resistance.value


# -------------------- 动态操作：移除抗性 --------------------
## @brief 从列表中移除一个抗性，并更新伤害资源的抗性数值
## @param resistance 要移除的抗性资源（需与列表中实例一致）
func remove_resistance(resistance:DamageTypeResource)->void:
	# 检查列表中是否存在该抗性（避免空操作）
	if !resistance_list.has(resistance):
		return
	
	# 从本地列表中移除抗性
	resistance_list.erase(resistance)
	# 更新伤害资源中对应类型的抗性数值（扣除）
	damage_resource.resistance_value_list[resistance.type] -= resistance.value
