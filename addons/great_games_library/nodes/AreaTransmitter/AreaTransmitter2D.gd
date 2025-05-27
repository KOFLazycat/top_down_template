# 区域传输节点：通过物理区域检测触发子数据通道的发送逻辑
class_name AreaTransmitter2D  # 定义类名，可在场景中作为区域节点使用
extends Area2D  # 继承自 2D 区域节点（用于物理碰撞检测）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var enabled:bool = true  # 传输启用状态（控制是否触发数据发送）


# -------------------- 成员变量（运行时状态） --------------------
var send_list:Array[Callable] = []  # 存储子 DataChannelTransmitter 的 send 回调（用于批量触发）


# -------------------- 核心方法：设置启用状态 --------------------
func set_enabled(value:bool)->void:
	enabled = value  # 直接修改启用状态


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	# 解决 Godot 引擎 BUG（https://github.com/godotengine/godot/issues/17238）：
	# 延迟设置不可监控（避免物理引擎异常），此处通过设置 process_mode 为始终处理确保逻辑有效
	# set_monitorable.call_deferred(false)  # 原 BUG 修复方案（当前注释，根据引擎版本调整）
	process_mode = PROCESS_MODE_ALWAYS  # 确保节点始终处理逻辑（不因暂停而中断）
	
	# 连接区域进入信号（当其他区域进入当前区域时触发）
	area_entered.connect(_on_area_entered)
	
	# 遍历子节点，收集 DataChannelTransmitter 的 send 回调
	for child:Node in get_children():
		if !(child is DataChannelTransmitter) || child == null:  # 仅处理 DataChannelTransmitter 类型的子节点
			continue
		var data_transmitter:DataChannelTransmitter = child as DataChannelTransmitter
		send_list.append(data_transmitter.send)  # 存储子节点的 send 方法到列表
		# 连接子节点的 check_receiver 信号（用于校验接收方是否仍在重叠区域）
		data_transmitter.check_receiver.connect(_on_check_receiver.bind(data_transmitter))


# -------------------- 核心逻辑：校验接收方是否仍在重叠区域 --------------------
func _on_check_receiver(receiver:AreaReceiver2D, data_transmitter:DataChannelTransmitter)->void:
	if !enabled:  # 新增：校验传输是否启用
		return
	var overlap_list:Array = get_overlapping_areas()  # 获取当前重叠的所有区域
	if !overlap_list.has(receiver):  # 检查目标接收方是否在重叠列表中
		return  # 不在则不发送
	data_transmitter.send(receiver)  # 在重叠区域内，调用子节点的 send 方法发送数据


# -------------------- 核心逻辑：区域进入时触发数据发送 --------------------
func _on_area_entered(area:Area2D)->void:
	if !(area is AreaReceiver2D):  # 仅处理 AreaReceiver2D 类型的区域
		return
	if !enabled:  # 若传输被禁用，直接返回
		return
	# 遍历所有子节点的 send 回调，传递接收方实例
	for _callback:Callable in send_list:
		if _callback.is_valid():
			_callback.call(area as AreaReceiver2D)
