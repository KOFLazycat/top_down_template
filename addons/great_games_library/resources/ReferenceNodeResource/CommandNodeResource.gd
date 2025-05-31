## 为引用节点或回调函数提供命令发送功能的资源类
class_name CommandNodeResource  # 定义类名，可在编辑器中作为资源类型使用
extends ReferenceNodeResource  # 继承自节点引用管理资源（假设已实现节点引用与信号机制）


# -------------------- 信号与变量（核心功能载体） --------------------

## 回调函数变更信号（用于通知监听者回调已更新）
signal callback_changed

## 通用回调函数（无需绑定节点，可直接调用）
## 示例：Callable(self, "on_command") 或预定义的脚本函数
var callable:Callable


# -------------------- 核心方法（回调与命令管理） --------------------

## 设置回调函数并触发变更信号
## @param value: 新的回调函数（Callable 类型）
func set_callable(value:Callable)->void:
	callable = value  # 更新回调函数
	callback_changed.emit()  # 通知监听者回调已变更


## 执行回调函数（支持带参/无参调用）
## @param value_list: 参数数组（若为空则无参调用）（如 [10, true] 表示传递两个参数）
## IMPORTANT: 调用者需确保参数类型与回调函数签名匹配
func callback(value_list:Array)->void:
	# 确保回调函数有效（发布模式下断言会被忽略）
	if callable.is_null():
		Log.entry("CommandNodeResource: 回调函数未设置，无法执行", LogManager.LogLevel.ERROR)
		return

	if value_list.is_empty():
		callable.call()  # 无参调用回调
	else:
		callable.call(value_list)  # 带参调用回调（参数数组展开）


## 向引用节点发送命令（调用其指定方法）
## @param method: 节点要调用的方法名（StringName 类型）
## @param value_list: 参数数组（传递给方法的参数）（如 [50] 表示造成 50 点伤害）
## IMPORTANT: 调用者需明确节点方法的签名（参数类型与数量）
func command(method:StringName, value_list:Array)->void:
	# 确保节点引用有效（继承自 ReferenceNodeResource 的 node 变量）
	if node == null || !node.is_instance_valid():
		Log.entry("CommandNodeResource: 节点引用无效（未设置或已销毁）", LogManager.LogLevel.ERROR)
		return
	if !node.has_method(method):
		Log.entry("CommandNodeResource: 节点 %s 未实现方法 %s" % [node.name, method], LogManager.LogLevel.ERROR)
		return

	# 调用节点的方法（callv 支持通过数组传递参数）
	node.call_deferred("callv", method, value_list)
