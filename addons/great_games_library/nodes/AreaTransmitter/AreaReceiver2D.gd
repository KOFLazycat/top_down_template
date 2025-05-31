# 2D 区域接收节点：接收数据传输请求并分发到对应回调函数处理
class_name AreaReceiver2D  # 定义类名，可在场景中作为接收区域节点使用
extends Area2D  # 继承自 2D 区域节点（用于物理碰撞检测）


# -------------------- 成员变量（运行时状态） --------------------
## 传输名称与回调函数的映射字典（键：传输名称，值：处理回调）
var callbacks:Dictionary = {}  # 存储格式：{StringName: Callable}


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	process_mode = PROCESS_MODE_ALWAYS  # 设置节点处理模式为始终处理（确保回调逻辑及时执行）
	monitoring = false  # 初始禁用区域监控（需手动调用 `set_monitoring(true)` 启用碰撞检测）
	
	# 遍历子节点，收集 DataChannelReceiver 的 send 回调
	for child:Node in get_children():
		if !(child is DataChannelReceiver) || child == null:  # 仅处理 DataChannelReceiver 类型的子节点
			continue
		var data_receiver:DataChannelReceiver = child as DataChannelReceiver
		# 存储子节点的 receive 方法到列表
		add_receiver(data_receiver.transmission_name, data_receiver.receive)


# -------------------- 核心逻辑：接收数据传输请求 --------------------
## @brief 接收传输资源并根据传输名称分发到对应回调
## @param transmission_resource 传输资源（存在拼写错误，应为 transmission_resource）
func receive(transmission_resource:TransmissionResource)->void:
	# 修正拼写错误（transmision → transmission）
	if transmission_resource == null:
		Log.entry("AreaReceiver2D: 传输资源为空，无法处理接收请求", LogManager.LogLevel.ERROR)
		return
	
	var transmission_name = transmission_resource.transmission_name
	if callbacks.has(transmission_name):
		# 调用对应的回调函数（传递传输资源）
		var callback:Callable = callbacks[transmission_name]
		if callback.is_valid():  # 校验回调有效性（避免无效 Callable）
			callback.call(transmission_resource)
		else:
			Log.entry("AreaReceiver2D: 回调函数无效，传输名称：%s" % transmission_name, LogManager.LogLevel.ERROR)
			transmission_resource.failed()
		return
	
	# 未找到匹配的回调时标记传输失败
	Log.entry("AreaReceiver2D: 未找到传输名称对应的回调：%s" % transmission_name, LogManager.LogLevel.WARNING)
	transmission_resource.failed()


# -------------------- 核心逻辑：注册传输处理回调 --------------------
## @brief 注册传输名称对应的处理回调
## @param transmission_name 传输名称（需与传输资源的 transmission_name 一致）
## @param callback 处理回调函数（需接受 TransmissionResource 作为参数）
func add_receiver(transmission_name:StringName, callback:Callable)->void:
	if transmission_name.is_empty():
		Log.entry("AreaReceiver2D: 传输名称为空，无法注册回调", LogManager.LogLevel.ERROR)
		return
	if callback == null || !callback.is_valid():
		Log.entry("AreaReceiver2D: 无效的回调函数，传输名称：%s" % transmission_name, LogManager.LogLevel.ERROR)
		return
	
	callbacks[transmission_name] = callback  # 添加回调到字典
	Log.entry("AreaReceiver2D: 注册传输回调成功：%s" % transmission_name, LogManager.LogLevel.INFO)


## @brief 移除指定传输名称的回调函数
func remove_receiver(transmission_name:StringName)->void:
	if callbacks.has(transmission_name):
		callbacks.erase(transmission_name)
		Log.entry("AreaReceiver2D: 移除传输回调：%s" % transmission_name, LogManager.LogLevel.INFO)
