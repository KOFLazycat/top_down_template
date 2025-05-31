# 资源管理节点：通过字典集中管理 ResourceNodeItem 资源条目
class_name ResourceNode  # 定义类名，可在场景中作为资源管理节点使用
extends Node  # 继承自基础节点类


# -------------------- 信号（资源变更通知） --------------------
## 当资源通过 add/remove 方法变更时触发（通知外部资源已更新）
signal add_done(item:ResourceNodeItem)
signal remove_done(item:ResourceNodeItem)


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源条目数组（在编辑器中配置需要管理的 ResourceNodeItem 列表）
@export var list:Array[ResourceNodeItem]  # 存储 ResourceNodeItem 实例


# -------------------- 运行时状态变量（内部缓存） --------------------
## 资源字典（键：资源名称，值：ResourceNodeItem 实例），用于快速查询
var dictionary:Dictionary  # 格式：{String: ResourceNodeItem}


# -------------------- 生命周期方法（节点初始化与资源加载） --------------------
## @brief 初始化资源字典（根据 list 数组生成）
## WARNING: 需确保该节点的第一个子节点正确配置（用于保证初始化顺序）
func _ready()->void:
	# 遍历编辑器配置的资源条目列表
	for item:ResourceNodeItem in list:
		# 资源名称非空（作为字典的键）
		if item.resource_name.is_empty():
			Log.entry("ResourceNode: resource_name 为空，无法作为字典键", LogManager.LogLevel.ERROR)
			return
		# 资源引用非空（避免空值错误）
		if item.resource == null:
			Log.entry("ResourceNode: resource 未配置，资源条目无效", LogManager.LogLevel.ERROR)
			return
		# 资源名称重复
		if dictionary.has(item.resource_name):
			Log.entry("ResourceNode: 资源名称重复，%s 重复加入字典" % item.resource_name, LogManager.LogLevel.WARNING)
		# 复制资源条目（避免修改原始配置）
		var _new_item:ResourceNodeItem = item.duplicate()
		
		# 根据 make_unique 决定是否创建资源副本
		if _new_item.make_unique:
			# 复制资源实例（确保每个 ResourceNode 拥有独立资源）
			_new_item.value = _new_item.resource.duplicate()
		else:
			# 直接引用原始资源（多节点共享同一实例）
			_new_item.value = _new_item.resource
		
		# 将新资源条目存入字典（键为资源名称）
		dictionary[_new_item.resource_name] = _new_item
	
	# 强制触发节点的 ready 状态（确保子节点已初始化，配合对象池使用）
	request_ready()


# -------------------- 核心方法：动态添加资源条目 --------------------
## @brief 向资源节点添加新的资源条目（同步更新 list 和 dictionary）
## @param item 要添加的 ResourceNodeItem 实例
func add_resource(item:ResourceNodeItem)->void:
	# 资源名称非空（作为字典的键）
	if item.resource_name.is_empty():
		Log.entry("ResourceNode: resource_name 为空，无法作为字典键", LogManager.LogLevel.ERROR)
		return
	# 资源引用非空（避免空值错误）
	if item.resource == null:
		Log.entry("ResourceNode: resource 未配置，资源条目无效", LogManager.LogLevel.ERROR)
		return
	# 资源名称重复
	if dictionary.has(item.resource_name):
		Log.entry("ResourceNode: add_resource: 资源名称重复，%s 重复加入字典" % item.resource_name, LogManager.LogLevel.WARNING)
	
	# 根据 make_unique 生成资源实例
	if item.make_unique:
		item.value = item.resource.duplicate()  # 复制资源实例
	else:
		item.value = item.resource  # 引用原始资源
	
	# 同步更新数组和字典
	list.append(item)  # 添加到资源列表（编辑器可见）
	dictionary[item.resource_name] = item  # 添加到字典（运行时查询）
	
	# 触发资源变更信号（通知外部资源已更新）
	add_done.emit(item)


# -------------------- 核心方法：移除资源条目 --------------------
## @brief 根据资源名称移除资源条目（同步更新 list 和 dictionary）
## @param key 要移除的资源名称（字典的键）
func remove_resource(key:String)->void:
	# 校验字典中是否存在该键
	if !dictionary.has(key):
		return  # 无该资源，直接返回
	
	# 获取资源条目并从数组和字典中移除
	var item:ResourceNodeItem = dictionary[key]
	list.erase(item)       # 从资源列表中移除
	dictionary.erase(key)  # 从字典中移除
	
	# 触发资源变更信号（通知外部资源已更新）
	remove_done.emit(item)


# -------------------- 核心方法：获取资源实例 --------------------
## @brief 根据资源名称获取对应的资源实例（支持空值安全）
## @param key 要查询的资源名称（字典的键）
## @return 资源实例（若不存在则返回 null）
func get_resource(key:String)->SaveableResource:
	# 校验字典中是否存在该键
	if !dictionary.has(key):
		return null  # 无该资源，返回 null
	
	# 返回资源条目的实际值（可能是副本或原始资源）
	return dictionary[key].value
