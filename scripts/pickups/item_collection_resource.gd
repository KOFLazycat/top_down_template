# 物品集合资源类：管理物品列表的增删改查，支持存档与状态通知
class_name ItemCollectionResource  # 定义资源类名（可在编辑器中创建实例）
extends SaveableResource  # 继承自可存档资源（支持游戏存档功能）


# -------------------- 信号（状态变更通知） --------------------
signal updated  # 物品列表更新时触发（如添加、删除、交换物品）
signal removed(value:ItemResource, is_dropped:bool)  # 物品被移除时触发（携带被移除的物品和是否为丢弃操作）
signal selected_changed  # 选中物品索引变化时触发


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var list:Array[ItemResource]  # 当前物品列表（存储 ItemResource 实例）
@export var selected:int  # 当前选中的物品索引（用于快速访问目标物品）
@export var max_items:int  # 物品列表最大容量（限制可携带的物品数量）


# -------------------- 核心方法：设置物品列表 --------------------
## @brief 设置物品列表并触发更新信号
## @param value 新的物品列表
func set_list(value:Array[ItemResource])->void:
	list = value  # 直接替换当前列表
	updated.emit()  # 触发列表更新信号（通知外部列表已变更）


# -------------------- 核心方法：设置选中物品索引 --------------------
## @brief 设置当前选中的物品索引（自动处理越界问题）
## @param value 目标索引（支持负数索引，如 -1 表示最后一个物品）
func set_selected(value:int)->void:
	# 当 list 为空时，set_selected 强制将 selected 设为 0，但此时列表无物品，selected 应标记为无效（如 -1）。
	if list.is_empty():  # 列表为空时，强制选中索引为 0（无实际物品）
		selected = 0
	else:
		# 计算有效索引（通过取模确保索引在列表范围内）
		selected = abs(value + list.size()) % list.size()
	selected_changed.emit()  # 触发选中索引变更信号


# -------------------- 核心方法：添加物品到列表 --------------------
## @brief 向物品列表末尾添加新物品（触发更新信号）
## @param value 要添加的物品资源
func append(value:ItemResource)->void:
	if max_items > 0 && list.size() >= max_items:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ItemCollectionResource: 物品列表已满（最大容量：%d），无法添加新物品" % max_items, LogManager.LogLevel.ERROR)
		return
	
	list.append(value)  # 添加物品到列表末尾
	updated.emit()  # 触发列表更新信号


# -------------------- 核心方法：交换当前选中的物品 --------------------
## @brief 交换当前选中位置的物品（触发更新和移除信号）
## @param value 新物品（替换当前选中位置的物品）
## @param is_dropped 是否为丢弃操作（影响 removed 信号的参数）
## @return 被替换的旧物品
func swap(value:ItemResource, is_dropped:bool = true)->ItemResource:
	var _item:ItemResource = list[selected]  # 获取当前选中的物品
	list[selected] = value  # 替换为新物品
	updated.emit()  # 触发列表更新信号
	removed.emit(_item, is_dropped)  # 触发移除信号（通知旧物品被移除）
	return _item  # 返回被替换的旧物品


# -------------------- 核心方法：丢弃当前选中的物品 --------------------
## @brief 丢弃当前选中的物品（从列表中移除并触发信号）
## @return 被丢弃的物品
func drop()->ItemResource:
	var _item:ItemResource = list[selected]  # 获取当前选中的物品
	list[selected] = null  # 将当前位置标记为 null（后续过滤）
	
	# 过滤列表（移除所有 null 值）
	list = list.filter(filter_empty)
	# 调整选中索引（避免越界，取原索引与新列表长度-1的较小值）
	set_selected(min(selected, list.size() -1))
	
	updated.emit()  # 触发列表更新信号
	removed.emit(_item, true)  # 触发移除信号（标记为丢弃操作）
	return _item  # 返回被丢弃的物品


# -------------------- 核心方法：取出当前选中的物品（非丢弃） --------------------
## @brief 取出当前选中的物品（从列表中移除但不标记为丢弃，用于转移物品）
## @return 被取出的物品
func take()->ItemResource:
	var _item:ItemResource = list[selected]  # 获取当前选中的物品
	list[selected] = null  # 将当前位置标记为 null（后续过滤）
	
	# 过滤列表（移除所有 null 值）
	list = list.filter(filter_empty)
	# 调整选中索引（避免越界）
	set_selected(min(selected, list.size() -1))
	
	updated.emit()  # 触发列表更新信号
	removed.emit(_item, false)  # 触发移除信号（标记为非丢弃操作）
	return _item  # 返回被取出的物品


# -------------------- 辅助方法：过滤空值（用于列表清理） --------------------
## @brief 过滤列表中的 null 值（保留有效物品）
## @param value 列表中的单个元素（ItemResource 类型）
## @return true 表示保留该元素（非 null），false 表示移除
func filter_empty(value:ItemResource)->bool:
	return value != null
