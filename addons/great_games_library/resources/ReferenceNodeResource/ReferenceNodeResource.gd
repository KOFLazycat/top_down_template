# 自定义资源类：用于引用一个节点，并在引用变更时触发通知
class_name ReferenceNodeResource  # 定义类名，可在 Godot 编辑器中作为资源类型使用
extends Resource  # 继承自 Godot 基础资源类，允许在场景中保存/加载

# 当引用节点变更时触发的信号（参数可选，这里未传参，可根据需求扩展）
signal updated(n: Node)

# 被引用的节点（共享给所有持有该资源的对象）
var node:Node

# 监听器回调列表（存储所有注册的回调函数）
var listeners:Array[Callable]

# 设置引用的节点，并触发监听器通知
# 参数说明：
#   value: 新的目标节点（可为 null）
#   until_exit: 是否在目标节点退出场景树时自动移除引用（默认 true）
func set_reference(value:Node, until_exit:bool = true)->void:
	node = value  # 更新节点引用

	# 遍历所有监听器并执行回调（通知引用变更）
	for callback in listeners:
		if callback.is_valid():
			callback.call()  # 直接调用回调（无参数，可根据需求传递新节点）

	# 如果目标节点存在且需要自动清理
	if value != null && until_exit:
		# 连接目标节点的 "tree_exiting" 信号（节点即将退出场景树时触发）
		# 绑定 remove_reference 方法（参数为当前节点），并设置单次连接（CONNECT_ONE_SHOT）
		# 作用：当节点退出场景树时，自动调用 remove_reference 移除引用
		value.tree_exiting.connect(remove_reference.bind(node), CONNECT_ONE_SHOT)

	updated.emit(node)  # 发射 "updated" 信号，通知所有信号监听器


# 移除指定节点的引用（仅当当前引用指向该节点时生效）
# 参数说明：
#   value: 需要移除的目标节点
func remove_reference(value:Node)->void:
	# 如果当前引用的节点不是目标节点，直接返回
	if node != value:
		return

	node = null  # 清空引用

	# 遍历所有监听器并执行回调（通知引用被移除）
	for callback in listeners:
		if callback.is_valid():
			callback.call()

	updated.emit(node)  # 发射 "updated" 信号


# 注册监听器（监听引用变更，并立即执行一次回调作为初始化）
# 参数说明：
#   inst: 监听器所在的节点实例（用于自动清理回调）
#   callback: 引用变更时触发的回调函数（无参数，可自定义）
#   until_exit: 是否在 inst 退出场景树时自动移除该监听器（默认 true）
func listen(inst:Node, callback:Callable, until_exit:bool = true)->void:
	# 如果回调已存在，避免重复注册
	if listeners.has(callback):
		return

	listeners.append(callback)  # 将回调添加到监听器列表

	# 如果需要自动清理
	if until_exit:
		# 连接 inst 的 "tree_exited" 信号（节点退出场景树后触发）
		# 绑定 erase_listener 方法（参数为当前回调），并设置单次连接
		# 作用：当 inst 退出场景树时，自动从监听器列表中移除该回调
		inst.tree_exited.connect(erase_listener.bind(callback), CONNECT_ONE_SHOT)

	callback.call()  # 立即执行一次回调（作为初始化）


# 从监听器列表中移除指定回调
# 参数说明：
#   callback: 需要移除的回调函数
func erase_listener(callback:Callable)->void:
	listeners.erase(callback)  # 从数组中删除回调（若存在）
