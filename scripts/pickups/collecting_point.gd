# 收集点节点：管理收集点的生成动画、碰撞检测及回收逻辑
class_name CollectingPoint  # 定义类名，可在场景中作为收集点节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var moved_node:Node2D  # 需要移动的目标节点（如收集点的视觉表现节点）
@export_flags_2d_physics var collision_mask:int  # 碰撞掩码（决定检测哪些物理层的物体）
@export var area:Area2D  # 用于碰撞检测的区域节点（触发收集行为）
@export var collision_shape:CollisionShape2D  # 碰撞形状（定义区域的检测范围）
@export var point_resource:ScoreResource  # 分数资源（用于增加收集得分）
@export var pool_node:PoolNode  # 对象池节点（用于回收当前收集点）
@export var player_reference:ReferenceNodeResource  # 玩家引用资源（获取玩家位置）
@export var sound_collect:SoundResource  # 收集音效资源（收集成功时播放）
@export var axis_multiplication:Vector2Resource  # 轴乘法因子（调整生成位置的方向偏移）
@export var spawn_radius:float = 8.0  # 生成半径（收集点初始移动的随机范围）
@export var spawn_radius_random_min:float = 0.8  # 生成半径随机因子最小系数
@export var spawn_radius_random_max:float = 1.2  # 生成半径随机因子最大系数


# -------------------- 常量与成员变量（运行时状态） --------------------
const SPAWN_TIME:float = 0.3  # 动画持续时间（秒）
var tween:Tween  # 补间动画对象（控制收集点的移动轨迹）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready() -> void:
	request_ready()  # 重新触发 _ready()（确保子节点状态同步）
	if moved_node == null || area == null \
	|| point_resource == null || pool_node == null \
	|| player_reference == null || sound_collect == null:
		Log.entry("关键导出变量未配置，节点：%s" % name, LogManager.LogLevel.ERROR)
		return
	
	area.collision_mask = 0  # 初始禁用区域碰撞（避免未完成生成时触发收集）
	
	# 清理旧补间动画（防止重复播放）
	if tween != null:
		tween.kill()
	tween = create_tween()  # 创建新补间动画
	
	# 计算初始生成的随机目标位置（以 moved_node 初始位置为中心，半径 spawn_radius 的随机方向）
	var _random_radius = spawn_radius * randf_range(spawn_radius_random_min, spawn_radius_random_max)
	var _to:Vector2 = Vector2(_random_radius, 0.0).rotated(randf_range(0.0, TAU)) * axis_multiplication.value + moved_node.global_position
	# 补间动画：从初始位置平滑移动到随机目标位置
	# 缓出效果（开始快，结束慢）
	# 立方过渡（运动曲线）
	tween.tween_method(_tween_position.bind(moved_node.global_position, _to), 0.0, 1.0, SPAWN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)  
	
	# 动画完成后初始化碰撞检测（启用区域碰撞）
	tween.finished.connect(_init_area)
	
	# 监听玩家引用更新（如玩家节点被销毁时回调）
	player_reference.listen(self, _on_reference_update)


# -------------------- 核心逻辑：初始化碰撞检测 --------------------
func _init_area()->void:
	area.collision_mask = collision_mask  # 启用区域碰撞（根据配置的碰撞掩码检测目标物体）
	# 连接区域的 body_entered 信号（当物体进入区域时触发收集）
	area.body_entered.connect(_on_body_enter, CONNECT_ONE_SHOT)  # 单次连接（避免重复触发）


# -------------------- 回调逻辑：玩家引用更新时处理 --------------------
func _on_reference_update()->void:
	if player_reference.node != null:  # 玩家节点存在时，无需处理
		return
	# 玩家节点丢失时，终止当前动画（避免无效移动）
	if tween != null:
		tween.kill()


# -------------------- 核心逻辑：物体进入区域时触发收集 --------------------
func _on_body_enter(_body:Node2D)->void:
	if player_reference.node == null:
		Log.entry("玩家引用为空，无法执行收集逻辑", LogManager.LogLevel.ERROR)
		return
	area.collision_mask = 0  # 禁用区域碰撞（防止重复触发收集）
	if tween != null:  # 终止当前未完成的动画
		tween.kill()
	
	tween = create_tween()  # 创建新补间动画
	
	# 计算远离玩家的方向（从玩家位置指向收集点位置的单位向量）
	var _dir_away:Vector2 = (moved_node.global_position - player_reference.node.global_position).normalized()
	# 计算远离玩家的偏移位置（避免与玩家重叠）
	var _offset:Vector2 = _dir_away * spawn_radius * axis_multiplication.value + moved_node.global_position
	
	# 补间动画1：收集点先向远离玩家的方向移动
	tween.tween_method(_tween_position.bind(moved_node.global_position, _offset), 0.0, 1.0, SPAWN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 补间动画2：收集点从偏移位置向玩家位置移动（模拟被收集的效果）
	# 缓入效果（开始慢，结束快）
	tween.tween_method(_tween_target_position.bind(_offset), 0.0, 1.0, SPAWN_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# 动画完成后执行收集逻辑（音效、分数、回收）
	tween.finished.connect(_on_finished)


# -------------------- 辅助逻辑：补间动画-位置插值 --------------------
func _tween_position(t:float, from:Vector2, to:Vector2)->void:
	# 通过线性插值（lerp）计算当前位置，实现平滑移动
	moved_node.global_position = from.lerp(to, t)


# -------------------- 辅助逻辑：补间动画-目标位置插值 --------------------
func _tween_target_position(t:float, from:Vector2)->void:
	if player_reference.node == null:
		Log.entry("玩家引用为空，tween动画失效", LogManager.LogLevel.ERROR)
		return
	# 从偏移位置向玩家位置插值（最终被玩家收集）
	moved_node.global_position = from.lerp(player_reference.node.global_position, t)


# -------------------- 核心逻辑：收集完成后处理 --------------------
func _on_finished()->void:
	sound_collect.play_managed()  # 播放收集音效（自动管理音效生命周期）
	point_resource.add_point()  # 增加分数（通过分数资源更新得分）
	pool_node.pool_return()  # 将当前收集点回收到对象池（复用节点）
