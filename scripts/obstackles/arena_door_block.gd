# 竞技场门控制节点：根据战斗状态控制门的开启/关闭，并更新A*寻路网格
class_name ArenaDoorBlock
extends Node

# 导出变量：配置门的相关资源和节点
@export var astargrid_resource:AstarGridResource  # A*寻路网格资源，用于设置门的通行性
@export var fight_bool_resource:BoolResource      # 战斗状态布尔资源（true表示战斗进行中）
@export var position_node:Node2D                 # 门的位置节点（用于确定门在网格中的位置）
@export var animation_player:AnimationPlayer     # 动画播放器（控制门的开关动画）
@export var animation_on:StringName              # 门开启时播放的动画名称
@export var animation_off:StringName             # 门关闭时播放的动画名称

# 门的状态枚举
enum WallState {OFF, ON}  # OFF表示门打开（可通行），ON表示门关闭（不可通行）
var state:WallState = WallState.OFF  # 初始状态：门打开

# 节点初始化
func _ready()->void:
	# 连接战斗状态更新信号，当战斗状态变化时触发update方法
	fight_bool_resource.updated.connect(update)
	update()  # 初始化调用一次update确保状态正确

# 更新门的状态
func update()->void:
	if position_node == null or animation_player == null:
		Log.entry("ArenaDoorBlock: position_node或animation_player未设置，无法更新门状态", LogManager.LogLevel.ERROR)
		return
	
	if not animation_player.has_animation(animation_on) or not animation_player.has_animation(animation_off):
		Log.entry("ArenaDoorBlock: 动画名称无效：animation_on=%s, animation_off=%s" % [animation_on, animation_off], LogManager.LogLevel.ERROR)
		return
	
	# 检查A*网格资源是否有效
	if astargrid_resource.value == null:
		Log.entry("ArenaDoorBlock: A*网格资源无效", LogManager.LogLevel.ERROR)
		return
	
	# 根据战斗状态确定新的门状态
	var _new_state:WallState = WallState.ON if fight_bool_resource.value else WallState.OFF
	
	# 如果状态没有变化，则不执行任何操作
	if _new_state == state:
		Log.entry("ArenaDoorBlock: 状态没有变化，不执行任何操作", LogManager.LogLevel.INFO)
		return
	
	# 更新状态
	state = _new_state
	
	# 将位置节点的全局坐标转换为A*网格中的瓦片坐标
	var _tile_pos:Vector2i = astargrid_resource.tilemap_layer.local_to_map(position_node.global_position)
	
	# 根据新状态执行相应操作
	match state:
		WallState.ON:
			animation_player.play(animation_on)  # 播放门开启动画（视觉上是关闭效果）
			astargrid_resource.value.set_point_solid(_tile_pos, true)  # 设置为障碍物（不可通行）
		WallState.OFF:
			animation_player.play(animation_off)  # 播放门关闭动画（视觉上是开启效果）
			astargrid_resource.value.set_point_solid(_tile_pos, false)  # 设置为可通行
