# 跳跃移动控制节点：处理角色的跳跃移动逻辑，包括位置插值、精灵动画和缩放效果
class_name JumpMove  # 定义类名，可在场景中作为跳跃移动控制器
extends Node  # 继承自基础节点类

# -------------------- 信号定义（状态与过程通知） --------------------
## 跳跃开始信号：在跳跃动作启动时触发
signal jump_started  
## 跳跃完成信号：在跳跃动作结束时触发
signal jump_finished  
## 移动插值信号：在跳跃过程中实时反馈进度（0.0~1.0）
signal movement_interpolation(t:float)  

# -------------------- 导出变量（编辑器可视化配置） --------------------
## 角色物理体：用于处理物理移动和碰撞（需绑定CharacterBody2D节点）
@export var character_body:CharacterBody2D  
## 角色精灵：用于调整跳跃时的精灵偏移效果
@export var sprite:Sprite2D  
## 偏移曲线：控制跳跃过程中精灵的Y轴偏移量（X轴为进度，Y轴为偏移值）
@export var offset_curve:Curve  
## 缩放节点：用于控制跳跃/落地时的缩放动画（需为Sprite2D或Node2D子节点）
@export var stretch_node:Node2D  
## 跳跃缩放向量：跳跃时的缩放比例（如压扁效果）
@export var jump_stretch:Vector2 = Vector2(0.8, 1.1)  
## 落地缩放向量：落地时的缩放比例（如拉伸效果）
@export var land_stretch:Vector2 = Vector2(1.2, 0.8)  
## 跳跃音效资源：TODO：实现音效播放逻辑
@export var jump_sound:SoundResource  
## 落地音效资源：TODO：实现音效播放逻辑
@export var land_sound:SoundResource  

# -------------------- 成员变量（运行时状态） --------------------
var move_tween:Tween  # 位置补间动画控制器（处理跳跃移动）
var stretch_tween:Tween  # 缩放补间动画控制器（处理跳跃/落地缩放）
var is_jumping:bool = false  # 跳跃状态标记（防止重复触发跳跃）
var receiver_collision_layer:int  # 碰撞层（未使用，预留扩展）
var physics_ticks:int  # 物理帧率（从项目设置中获取，用于计算速度）
var previous_position:Vector2  # 上一帧位置（用于计算移动速度）

# -------------------- 生命周期方法（初始化物理帧率） --------------------
func _ready() -> void:
	if character_body == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "JumpMove: 角色物理体（character_body）未配置", LogManager.LogLevel.ERROR)
		return
	if sprite == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "JumpMove: 角色精灵（sprite）未配置", LogManager.LogLevel.ERROR)
		return
	if stretch_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "JumpMove: 缩放节点（stretch_node）未配置", LogManager.LogLevel.ERROR)
		return
	if jump_sound == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "JumpMove: 跳跃音效资源（jump_sound）未配置", LogManager.LogLevel.ERROR)
		return
	if land_sound == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "JumpMove: 落地音效资源（land_sound）未配置", LogManager.LogLevel.ERROR)
		return
	# 获取项目设置中的物理帧率（用于将补间进度转换为实际速度）
	physics_ticks = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")

# -------------------- 核心方法：触发跳跃移动 --------------------
## @brief 开始向目标位置跳跃，创建补间动画并更新状态
## @param value 目标位置（世界坐标）
## @param time 跳跃持续时间（秒）
func move_target_position(value:Vector2, time:float)->void:
	if is_jumping:  # 防止重叠跳跃
		return
	is_jumping = true  # 标记跳跃状态
	
	previous_position = character_body.global_position  # 记录起始位置
	emit_signal("jump_started")  # 通知外部跳跃开始
	
	# 销毁旧补间动画（避免多个动画同时运行）
	if move_tween != null:
		move_tween.kill()
	
	 # 创建位置补间动画（使用物理进程确保与Physics同步）
	move_tween = create_tween()
	move_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# 插值方法：通过_move_body逐步更新角色位置
	move_tween.tween_method(
		_move_body.bind(character_body.global_position, value),  # 绑定起始位置和目标位置
		0.0, 1.0, time  # 从0.0到1.0，持续time秒
	)
	move_tween.finished.connect(_jump_finished.bind(value))  # 补间完成后触发落地逻辑
	
	# 创建缩放补间动画（跳跃时的压扁效果）
	if stretch_tween != null:
		stretch_tween.kill()
	stretch_tween = create_tween()
	stretch_tween.tween_method(
		_stretch_interpolation.bind(jump_stretch),  # 绑定跳跃缩放向量
		0.0, 1.0, 0.5  # 持续0.5秒，使用弹性过渡
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	 # TODO：播放跳跃音效（当前仅预留接口）
	if jump_sound != null:
		jump_sound.play_managed()


# -------------------- 补间回调：更新角色位置与精灵动画 --------------------
## @brief 插值过程中更新角色位置、速度和精灵偏移
## @param t 补间进度（0.0~1.0）
## @param from 起始位置
## @param to 目标位置
func _move_body(t:float, from:Vector2, to:Vector2)->void:
	# 计算当前位置（线性插值）
	var _new_pos:Vector2 = from.lerp(to, t)
	# 计算速度（位置变化量 * 物理帧率，转换为每秒位移）
	var _distance:Vector2 = _new_pos - previous_position
	previous_position = _new_pos
	character_body.velocity = _distance * physics_ticks
	character_body.move_and_slide()  # 执行物理移动
	
	# 根据曲线调整精灵Y轴偏移（实现跳跃弧度效果）
	sprite.offset.y = offset_curve.sample(t)
	
	# 通知外部当前跳跃进度（用于同步其他动画或逻辑）
	movement_interpolation.emit(t)


# -------------------- 跳跃完成回调：处理落地逻辑 --------------------
## @brief 跳跃补间完成后，重置状态并触发落地效果
## @param _target_pos 目标位置（未使用，仅用于信号绑定）
func _jump_finished(_target_pos:Vector2)->void:
	is_jumping = false  # 重置跳跃状态
	character_body.velocity = Vector2.ZERO  # 清除剩余速度
	jump_finished.emit()  # 通知外部跳跃完成
	
	# 创建落地缩放动画（拉伸效果）
	if stretch_tween != null:
		stretch_tween.kill()
	stretch_tween = create_tween()
	stretch_tween.tween_method(
		_stretch_interpolation.bind(land_stretch),  # 绑定落地缩放向量
		0.0, 1.0, 0.5  # 持续0.5秒，使用弹性过渡
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	# TODO：播放落地音效（当前仅预留接口）
	if land_sound != null:
		land_sound.play_managed()

# -------------------- 辅助方法：处理缩放插值 --------------------
## @brief 控制缩放节点的缩放效果（跳跃/落地时的压扁/拉伸）
## @param t 补间进度（0.0~1.0）
## @param from 起始缩放向量
func _stretch_interpolation(t:float, from:Vector2)->void:
	# 线性插值缩放向量（从from到Vector2.ONE）
	stretch_node.scale = from.lerp(Vector2.ONE, t)
