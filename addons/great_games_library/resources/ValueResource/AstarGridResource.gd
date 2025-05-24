# 定义自定义资源类，用于管理 AStarGrid2D 的配置和生命周期
class_name AstarGridResource
extends ValueResource  # 假设 ValueResource 是某个基础资源类

# 定义清理事件信号，当资源被清理时触发
signal cleaned_up

# 导出 A* 算法的计算启发式方法（例如曼哈顿距离、欧几里得距离等）
@export var default_compute_heuristic: AStarGrid2D.Heuristic
# 导出 A* 算法的估计启发式方法（通常与计算启发式一致）
@export var default_estimate_heuristic: AStarGrid2D.Heuristic
# 导出对角移动模式（允许、禁止或特定条件下的对角线移动）
# 更新说明：允许对角移动的模式（0=Never, 1=Always, 2=At Least One Passable...）
@export var diagonal_mode: AStarGrid2D.DiagonalMode
# 导出是否启用跳跃优化（跳过中间节点以加速路径计算）
@export var jumping_enabled: bool

# 存储实际的 AStarGrid2D 实例
var value: AStarGrid2D
# 关联的 TileMapLayer，可能用于动态更新网格数据（代码中未直接使用）
var tilemap_layer: TileMapLayer


# 设置 AStarGrid2D 实例并初始化其参数
func set_value(_value: AStarGrid2D) -> void:
	value = _value
	if value != null:
		# 应用导出的配置到 AStarGrid2D 实例
		value.default_compute_heuristic = default_compute_heuristic
		value.default_estimate_heuristic = default_estimate_heuristic
		value.diagonal_mode = diagonal_mode
		value.jumping_enabled = jumping_enabled
		# 更新网格数据（例如障碍变化后重新计算连通性）
		value.update()
	# 触发 updated 信号
	updated.emit()


# 清理资源，释放引用并触发清理信号
func cleanup() -> void:
	value = null
	tilemap_layer = null
	cleaned_up.emit()
