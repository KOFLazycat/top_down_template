# 数据通道传输节点：管理数据传输流程，处理传输状态与错误反馈
class_name DataChannelTransmitter  # 定义类名，可在场景中作为数据传输节点使用
extends Node  # 继承自基础节点类


# -------------------- 信号（传输状态与事件通知） --------------------
signal update_requested(transmission_resource:TransmissionResource)  # 传输资源需要更新时触发
signal success  # 传输成功时触发
signal failed  # 传输失败时触发
signal denied  # 传输被拒绝时触发
signal try_again(receiver:AreaReceiver2D)  # 需要重试传输时触发（携带接收方信息）
signal check_receiver(receiver:AreaReceiver2D)  # 请求校验接收方是否仍有效时触发（供外部节点调用）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var enabled:bool = true  # 传输启用状态（控制是否允许发送）
@export var try_next_frame:bool = true  # 重试时是否在下一物理帧自动尝试
@export var transmission_resource:TransmissionResource  # 传输资源（存储传输数据与逻辑）


# -------------------- 核心方法：设置启用状态 --------------------
func set_enabled(value:bool)->void:
	enabled = value  # 直接修改启用状态


# -------------------- 核心逻辑：执行数据发送 --------------------
func send(receiver:AreaReceiver2D)->void:
	if receiver == null || !receiver.is_inside_tree():
		Log.entry("接收方无效（已销毁或未加入场景树）", LogManager.LogLevel.ERROR)
		return
	
	if !enabled:  # 若传输被禁用，直接返回
		Log.entry("传输被禁用，直接返回", LogManager.LogLevel.INFO)
		return
	
	# 确保传输资源已配置（调试模式生效）
	if transmission_resource == null:
		Log.entry("传输资源（transmission_resource）未配置，无法发送", LogManager.LogLevel.ERROR)
		return
	
	# 复制传输资源（避免修改原始资源）
	var _transmission_resource:TransmissionResource = transmission_resource.duplicate()
	# 连接资源的 update_requested 信号（传输资源需要更新时回调）
	_transmission_resource.update_requested.connect(_on_update_requested.bind(_transmission_resource, receiver))
	
	# 调用传输资源的发送方法（传递接收方）
	if _transmission_resource.send_transmission(receiver):
		on_success()  # 发送成功，触发成功信号
		return
	
	# 根据传输资源的错误状态触发对应信号
	match _transmission_resource.state:
		TransmissionResource.ErrorType.FAILED:
			on_failed()  # 触发失败信号
		TransmissionResource.ErrorType.DENIED:
			on_denied()  # 触发拒绝信号
		TransmissionResource.ErrorType.TRY_AGAIN:
			# 延迟调用重试逻辑（避免当前帧信号连接未断开导致重复触发）
			on_try_again.call_deferred(receiver)
		_:
			Log.entry("未知传输状态：%s" % _transmission_resource.state, LogManager.LogLevel.ERROR)
			pass  # 其他状态（可扩展）


# -------------------- 核心逻辑：处理重试请求 --------------------
func on_try_again(receiver:AreaReceiver2D)->void:
	try_again.emit(receiver)  # 发射重试信号（通知外部逻辑）
	if try_next_frame:  # 若配置为下一帧重试，触发下一物理帧检查
		on_try_next_frame(receiver)


# -------------------- 辅助逻辑：注册下一物理帧检查 --------------------
func on_try_next_frame(receiver:AreaReceiver2D)->void:
	# 若未连接物理帧信号，连接并绑定接收方
	if !get_tree().physics_frame.is_connected(test_receiver):
		get_tree().physics_frame.connect(test_receiver.bind(receiver), CONNECT_ONE_SHOT)


# -------------------- 辅助逻辑：触发接收方校验 --------------------
func test_receiver(receiver:AreaReceiver2D)->void:
	check_receiver.emit(receiver)  # 发射校验信号（通知外部校验接收方是否有效）


# -------------------- 状态通知方法：传输成功 --------------------
func on_success()->void:
	success.emit()  # 发射成功信号（通知外部传输完成）


# -------------------- 状态通知方法：传输失败 --------------------
func on_failed()->void:
	failed.emit()  # 发射失败信号（通知外部传输失败）


# -------------------- 状态通知方法：传输被拒绝 --------------------
func on_denied()->void:
	denied.emit()  # 发射拒绝信号（通知外部传输被拒绝）


# -------------------- 回调逻辑：处理传输资源更新请求 --------------------
func _on_update_requested(transmission_resource:TransmissionResource, receiver:AreaReceiver2D)->void:
	update_requested.emit(transmission_resource, receiver)  # 发射资源更新信号（携带资源与接收方）
