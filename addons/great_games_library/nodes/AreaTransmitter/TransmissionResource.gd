# 传输资源类：封装数据传输的状态、错误处理及基础逻辑
class_name TransmissionResource  # 定义资源类名，可作为数据传输的载体
extends ValueResource  # 继承自值资源（轻量级资源，用于存储可序列化数据）


# -------------------- 信号（通知传输状态更新） --------------------
signal update_requested  # 传输资源需要更新时触发（由接收方或子类调用）


# -------------------- 枚举：传输错误类型（状态机） --------------------
enum ErrorType {
	## 默认值（未初始化或无效状态）
	NONE = -1,
	## 传输成功（接收方处理完成）
	SUCCESS = 0,
	## 需要下一物理帧重试传输（如接收方暂不可用）
	TRY_AGAIN,
	## 传输被拒绝（接收方主动拒绝处理）
	DENIED,
	## 传输失败（处理过程中发生错误）
	FAILED
}


# -------------------- 导出变量（编辑器配置） --------------------
@export_group("TransmissionResource")  # 编辑器中分组显示

## 传输通道名称（用于匹配目标接收方的传输通道）
@export var transmission_name:StringName = ""

## 当前传输状态（默认：未初始化）
@export var state:ErrorType = ErrorType.NONE

## 传输有效性标记（接收方可设置为false取消处理）
@export var valid:bool = true


# -------------------- 核心方法：执行传输逻辑 --------------------
func send_transmission(receiver:AreaReceiver2D)->bool:
	if transmission_name.is_empty():
		Log.entry("传输名称（transmission_name）未配置", LogManager.LogLevel.ERROR)
		state = ErrorType.FAILED
		return false
	if receiver == null:
		Log.entry("接收方（receiver）为空，无法执行传输", LogManager.LogLevel.ERROR)
		state = ErrorType.FAILED
		return false
	receiver.receive(self)  # 调用接收方的接收方法，传递当前传输资源
	
	# TODO: 若存在状态更新信号，添加信号存在性校验
	# assert(state != ErrorType.NONE, "传输状态未由接收方更新")
	return state == ErrorType.SUCCESS  # 返回传输是否成功（状态为SUCCESS时视为成功）


# -------------------- 状态设置方法（供接收方调用） --------------------
func success()->void:
	state = ErrorType.SUCCESS  # 设置传输状态为成功

func try_again()->void:
	state = ErrorType.TRY_AGAIN  # 设置传输状态为需要重试

func failed()->void:
	state = ErrorType.FAILED  # 设置传输状态为失败

func denied()->void:
	state = ErrorType.DENIED  # 设置传输状态为被拒绝

func invalid()->void:
	valid = false  # 标记传输无效（可用于提前终止处理）


# -------------------- 扩展接口：子类需实现的具体处理逻辑 --------------------
## @brief 接收方处理传输数据的回调（子类需重写）
## @param resource_node 接收方的资源节点（可用于数据交互）
func process(resource_node:ResourceNode)->void:
	pass  # 空实现，子类需覆盖此方法以处理具体传输逻辑
