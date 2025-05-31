# 数据通道接收节点：处理传输资源的初步验证、状态管理和流程控制
class_name DataChannelReceiver  # 定义类名，可在场景中作为数据接收节点使用
extends Node  # 继承自基础节点类


# -------------------- 信号（传输状态通知） --------------------
## 当传输被成功接收并处理时触发（携带传输资源）
signal transmission_received(transmission_resource:TransmissionResource)

## 提供外部验证传输的机会（需通过 transmission_resource.set_valid(true) 标记有效）
signal transmission_validate(transmission_resource:TransmissionResource)


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var enabled:bool = true  # 接收器是否启用（禁用时所有传输失败）
@export var bypass:bool = false  # 是否绕过当前处理（传输将在下一物理帧重试）
@export var transmission_name:StringName  # 接收的传输名称（需与传输资源的 transmission_name 一致）
@export var area_receiver:AreaReceiver2D  # 区域接收器（用于检测传输触发区域）
@export var resource_node:ResourceNode  # 资源节点（用于传递给传输资源的 process 方法）


# -------------------- 状态控制方法 --------------------
## @brief 设置接收器是否启用（影响传输是否失败）
## @param value true 启用，false 禁用
func set_enabled(value:bool)->void:
	enabled = value

## @brief 设置是否绕过当前处理（传输将重试）
## @param value true 绕过，false 正常处理
func set_bypass(value:bool)->void:
	bypass = value


func _ready()->void:
	# creates a signal with it's argument signature
	area_receiver.add_receiver(transmission_name, receive)


# -------------------- 核心逻辑：处理传输资源 --------------------
## @brief 接收并处理传输资源（校验状态、触发验证、执行处理）
## @param transmission_resource 接收到的传输资源（如 ItemTransmission、HealthTransmission）
func receive(transmission_resource:TransmissionResource)->void:
	# 1. 基础状态校验：接收器是否启用
	if !enabled:
		transmission_resource.failed()  # 接收器禁用，标记传输失败
		return
	
	# 2. 绕过处理：是否需要重试
	if bypass:
		transmission_resource.try_again()  # 标记传输重试（下一物理帧重新处理）
		return
	
	# 3. 外部验证：触发验证信号（允许外部修改传输资源或标记有效）
	transmission_validate.emit(transmission_resource)
	if !transmission_resource.valid:  # 验证未通过（valid 由外部设置）
		transmission_resource.denied()  # 标记传输被拒绝
		return
	
	# 4. 执行传输处理：调用传输资源的 process 方法（传递资源节点）
	transmission_resource.process(resource_node)
	
	# 5. 通知接收完成：触发传输接收信号（允许外部执行后续逻辑）
	transmission_received.emit(transmission_resource)
