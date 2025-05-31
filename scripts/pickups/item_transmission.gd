# 物品传输资源类：实现物品传输的具体逻辑（如武器类物品的背包添加）
class_name ItemTransmission  # 定义资源类名（可在编辑器中创建实例）
extends TransmissionResource  # 继承自基础传输资源类（包含传输状态管理）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var item_resource:ItemResource  # 要传输的物品资源（存储物品属性，如图标、类型）
@export var target_inventory_name:StringName = "weapons"  # 导出目标背包名称（可在编辑器配置）


# -------------------- 核心逻辑：处理物品传输（重写父类方法） --------------------
## @brief 处理物品传输逻辑（根据物品类型分发到具体处理函数）
## @param resource_node 接收方的资源节点（用于获取目标背包）
func process(resource_node:ResourceNode)->void:
	if item_resource == null:
		Log.entry("ItemTransmission: 物品资源（item_resource）未配置，传输失败", LogManager.LogLevel.ERROR)
		failed()
		return
	if resource_node == null:
		Log.entry("ItemTransmission: 资源节点（resource_node）为空，传输失败", LogManager.LogLevel.ERROR)
		failed()
		return
	
	# 根据物品类型匹配处理逻辑（当前仅支持武器类型）
	match item_resource.type:
		ItemResource.ItemType.WEAPON:
			_weapon(resource_node)  # 调用武器类型传输逻辑
		# 其他类型可在此扩展（如 CONSUMABLE、ARMOR 等）
		_:
			Log.entry("ItemTransmission: 未支持的物品类型：%s" % item_resource.type, LogManager.LogLevel.ERROR)
			failed()  # 默认标记为传输失败


# -------------------- 具体逻辑：处理武器类型物品的传输 --------------------
## @brief 处理武器类物品的传输（检查武器背包容量并添加物品）
## @param resource_node 接收方的资源节点（用于获取武器背包）
func _weapon(resource_node:ResourceNode)->void:
	# 从资源节点中获取名为 "weapons" 的武器背包（ItemCollectionResource 类型）
	var _weapon_inventory:ItemCollectionResource = resource_node.get_resource(target_inventory_name)
	if _weapon_inventory == null:
		Log.entry("ItemTransmission: 资源节点缺少武器背包（weapons），传输失败", LogManager.LogLevel.ERROR)
		failed()
		return
	
	# 检查武器背包是否已满（容量超过最大值）
	if _weapon_inventory.list.size() >= _weapon_inventory.max_items:
		Log.entry("ItemTransmission: 传输失败：背包（%s）已满（容量：%d/%d）" % [
			target_inventory_name,
			_weapon_inventory.list.size(),
			_weapon_inventory.max_items
		], LogManager.LogLevel.ERROR)
		failed()  # 背包已满，标记传输失败
		return
	
	# 向武器背包添加当前物品资源
	_weapon_inventory.append(item_resource)
	success()  # 物品添加成功，标记传输成功
