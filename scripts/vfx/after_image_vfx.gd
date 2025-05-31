# 残像视觉特效节点：实现残像动画并支持对象池复用
class_name AfterImageVFX  # 定义类名，可在场景中作为残像特效节点使用
extends Node2D  # 继承自 2D 节点（支持位置、变换等 2D 属性）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var sprite:Sprite2D  # 残像使用的精灵节点（负责渲染纹理）
@export var animation_player:AnimationPlayer  # 动画播放器（控制残像的淡入/淡出等动画）
@export var animation:StringName  # 要播放的动画名称（如 "after_image_fade"）
@export var pool_node:PoolNode  # 对象池节点（用于动画结束后回收当前节点）


# -------------------- 核心方法：初始化残像属性 --------------------
## @brief 配置残像的精灵属性（纹理、帧信息、位置等）
## @param texture 残像使用的纹理（如角色的临时截图）
## @param hframes 水平方向帧数（精灵图的列数）
## @param vframes 垂直方向帧数（精灵图的行数）
## @param frame 当前显示的帧索引（从 0 开始）
## @param centered 是否居中对齐（精灵原点是否在中心）
## @param offset 精灵偏移量（相对于节点原点的位置）
## @param sprite_position 精灵在节点内的局部位置
## @param world_position 残像节点的全局位置（世界坐标）
func setup(
	texture:Texture,
	hframes:int,
	vframes:int,
	frame:int,
	centered:bool,
	offset:Vector2,
	sprite_position:Vector2,
	world_position:Vector2
)->void:
	if sprite == null:
		Log.entry("AfterImageVFX: 残像精灵（sprite）未配置，setup 失败", LogManager.LogLevel.ERROR)
		return
	# 其他参数校验（示例：纹理不能为空）
	if texture == null:
		Log.entry("AfterImageVFX: 残像纹理（texture）为空，可能导致显示异常", LogManager.LogLevel.ERROR)
		return
	
	# 配置精灵纹理与帧信息
	sprite.texture = texture  # 设置残像的显示纹理
	sprite.hframes = hframes  # 水平帧数（用于切割精灵图）
	sprite.vframes = vframes  # 垂直帧数（用于切割精灵图）
	sprite.frame = frame      # 当前显示的帧（指定精灵图中的子图）
	
	# 配置精灵渲染属性
	sprite.centered = centered  # 精灵原点是否居中（影响旋转、缩放的基准点）
	sprite.offset = offset      # 精灵相对于节点原点的偏移（微调位置）
	
	# 配置位置
	sprite.position = sprite_position  # 精灵在节点内的局部位置（用于调整层级或偏移）
	global_position = world_position    # 残像节点的全局位置（确保残像出现在正确的世界坐标）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready() -> void:
	request_ready()  # 强制触发节点的 ready 状态（确保子节点已初始化）
	animation_player.stop()  # 停止当前播放的动画（避免复用节点时残留动画）
	
	# 校验动画是否存在
	if !animation_player.has_animation(animation):
		Log.entry("AfterImageVFX: 动画（%s）不存在，残像无法播放" % animation, LogManager.LogLevel.ERROR)
		pool_node.pool_return()  # 无动画时直接回收
		return
	animation_player.play(animation)  # 播放配置的残像动画（如淡入淡出）
	
	# 连接动画完成信号（动画结束后回收节点）
	# CONNECT_ONE_SHOT 确保信号仅触发一次（避免多次回收）
	animation_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)


# -------------------- 动画完成回调（对象池回收） --------------------
## @brief 动画播放完成后，将当前节点返回对象池
## @param _anim 完成的动画名称（未使用）
func _on_anim_finished(_anim:StringName)->void:
	pool_node.pool_return()  # 调用对象池的回收方法（复用节点，减少实例化开销）
