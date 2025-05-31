# 物品拾取节点：管理物品的可视化展示、拾取逻辑及拾取后资源释放
class_name ItemPickup  # 定义类名，可在场景中作为可拾取物品节点使用
extends Node2D  # 继承自 2D 节点（支持在 2D 场景中显示和交互）


# -------------------- 信号（拾取成功通知） --------------------
signal success  # 物品拾取成功时触发（供外部逻辑监听，如更新背包）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var item_resource:ItemResource  # 物品资源（存储物品属性，如图标、类型）
@export var icon_sprite:Sprite2D  # 物品图标精灵（用于显示物品外观）
@export var data_transmitter:DataChannelTransmitter  # 数据传输器（用于触发拾取逻辑）
@export var sound_resource:SoundResource  # 拾取音效资源（拾取成功时播放）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready() -> void:
	if item_resource == null:
		Log.entry("ItemPickup: 物品资源（item_resource）未配置，节点：%s" % name, LogManager.LogLevel.ERROR)
		return
	if icon_sprite == null:
		Log.entry("ItemPickup: 图标精灵（icon_sprite）未配置，节点：%s" % name, LogManager.LogLevel.ERROR)
		return
	if data_transmitter == null:
		Log.entry("ItemPickup: 数据传输器（data_transmitter）未配置，节点：%s" % name, LogManager.LogLevel.ERROR)
		return
	if sound_resource == null:
		Log.entry("ItemPickup: 音效资源（sound_resource）未配置，拾取时无音效", LogManager.LogLevel.ERROR)
		return
	
	# 设置物品图标（从物品资源中获取纹理）
	icon_sprite.texture = item_resource.icon
	
	# 创建传输资源（用于数据传输器发送物品信息）
	var _transmission_resource:ItemTransmission = ItemTransmission.new()
	_transmission_resource.transmission_name = "item"  # 设置传输通道名称（与接收方匹配）
	_transmission_resource.item_resource = item_resource  # 绑定当前物品资源
	
	# 配置数据传输器的传输资源
	data_transmitter.transmission_resource = _transmission_resource
	
	# 连接数据传输成功信号（单次连接，避免重复触发拾取）
	data_transmitter.success.connect(prepare_remove, CONNECT_ONE_SHOT)
	
	# 初始禁用数据传输器（避免生成时因碰撞重叠误触发拾取）
	data_transmitter.set_enabled(false)
	
	# 连接物理帧信号，延迟启用数据传输器（确保生成后位置稳定）
	get_tree().physics_frame.connect(_delay_enable, CONNECT_ONE_SHOT)


# -------------------- 辅助逻辑：延迟启用数据传输器 --------------------
## @brief 延迟启用数据传输器（避免生成时因重叠误触发拾取）
func _delay_enable()->void:
	# 在下一物理帧启用数据传输器（通过绑定参数传递 true）
	get_tree().physics_frame.connect(data_transmitter.set_enabled.bind(true), CONNECT_ONE_SHOT)


# -------------------- 核心逻辑：准备移除物品（拾取成功后） --------------------
func prepare_remove()->void:
	if !item_resource.unlocked:
		Log.entry("ItemPickup: 物品未解锁，无法拾取，节点：%s" % name, LogManager.LogLevel.ERROR)
		return
	data_transmitter.set_enabled(false)  # 禁用数据传输器（防止重复拾取）
	sound_resource.play_managed()  # 播放拾取音效（自动管理音效生命周期）
	success.emit()  # 发射拾取成功信号（通知外部逻辑，如更新背包）
	
	## TODO: 添加正式的视觉特效（如粒子效果、淡入淡出动画）
	queue_free()  # 销毁当前物品节点（从场景树中移除）
