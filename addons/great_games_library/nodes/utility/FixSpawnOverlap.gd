# 生成重叠修正节点：自动调整目标节点位置，避免与固体碰撞体重叠
class_name FixSpawnOverlap  # 定义类名，可在场景中作为形状投射节点使用
extends ShapeCast2D  # 继承自 2D 形状投射节点（用于碰撞检测）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var move_node:Node2D  # 需要调整位置的目标节点（如生成的角色、道具）


# -------------------- 成员变量（运行时状态） --------------------
var extent:Vector2  # 碰撞形状的半尺寸（用于计算移动距离）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	enabled = false  # 禁用形状投射的持续检测（仅执行一次初始化修正）
	target_position = Vector2.ZERO  # 形状投射的目标位置（此处未使用，保持默认）
	extent = shape.get_rect().size * 0.5  # 计算碰撞形状的半尺寸（假设形状为矩形）
	_fix()  # 执行重叠修正逻辑
	request_ready()  # 重新触发 _ready()（确保子节点状态更新，若有需要）


# -------------------- 核心逻辑：修正重叠位置 --------------------
func _fix()->void:
	if !is_colliding():  # 若未检测到碰撞，直接返回
		return
	
	var _solid_distance:Vector2 = Vector2.ZERO  # 累计移动距离（初始化为零向量）
	var _count:int = get_collision_count()  # 获取碰撞次数
	if _count < 1:  # 无碰撞时返回（冗余校验）
		return
	
	# 遍历所有碰撞点，计算需要移动的距离
	for i:int in _count:
		var _point:Vector2 = get_collision_point(i)  # 获取第 i 次碰撞的点坐标
		var _collider:Object = get_collider(i)  # 获取第 i 次碰撞的碰撞体（未使用）
		# 计算当前节点位置到碰撞点的修正距离，并累加到总移动距离
		_solid_distance += _rect_distance(global_position - _point)
	
	# 调整目标节点的位置（移出碰撞区域）
	move_node.global_position += _solid_distance


# -------------------- 辅助逻辑：计算矩形碰撞的修正距离 --------------------
func _rect_distance(distance:Vector2)->Vector2:
	# 修正 x 轴距离：符号 * 形状半宽 - 当前距离（将目标节点移出碰撞体）
	distance.x = sign(distance.x) * extent.x - distance.x
	# 修正 y 轴距离：符号 * 形状半高 - 当前距离（同上）
	distance.y = sign(distance.y) * extent.y - distance.y
	return distance
