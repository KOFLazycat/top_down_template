# 效果消耗节点：数据传输成功时触发消耗效果（动画、音效），并禁用传输器
class_name EffectConsume  # 定义类名，可在场景中作为效果消耗节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var data_transmitter:DataChannelTransmitter  # 数据传输器（触发消耗的条件源）
@export var animation_player:AnimationPlayer  # 动画播放器（用于播放消耗动画）
@export var fade_out_animation:StringName = "fade_out"  # 淡出动画名称（需与 AnimationPlayer 中的动画名一致）
@export var sounds_resource:SoundResource  # 消耗音效资源（播放成功音效）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	# 空值校验（发布版本也能捕获错误）
	if data_transmitter == null:
		Log.entry("数据传输器（data_transmitter）未配置，节点：%s" % name, LogManager.LogLevel.ERROR)
		return
	if animation_player == null:
		Log.entry("动画播放器（animation_player）未配置，将无法播放消耗动画", LogManager.LogLevel.ERROR)
		return
	if sounds_resource == null:
		Log.entry("音效资源（sounds_resource）未配置，将无法播放消耗音效", LogManager.LogLevel.ERROR)
		return
	
	# 启用数据传输器（允许触发传输逻辑）
	data_transmitter.set_enabled(true)
	
	# 连接传输成功信号（单次连接，避免重复触发消耗效果）
	data_transmitter.success.connect(_on_success, CONNECT_ONE_SHOT)
	request_ready()  # 重新触发 _ready()（确保子节点状态更新，若有需要）


# -------------------- 核心逻辑：数据传输成功时触发消耗效果 --------------------
func _on_success()->void:
	# 禁用数据传输器（防止重复触发消耗效果）
	data_transmitter.set_enabled(false)
	
	# 播放消耗音效（自动管理音效生命周期）
	if sounds_resource == null:
		Log.entry("音效资源未加载或路径错误，节点：%s" % name, LogManager.LogLevel.ERROR)
		return
	else:
		sounds_resource.play_managed()
	
	# 播放淡出动画（消耗效果的视觉反馈）
	if animation_player != null && animation_player.has_animation(fade_out_animation):
		animation_player.play(fade_out_animation)
