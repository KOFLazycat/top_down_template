# 处理模式控制组件：根据布尔资源状态切换节点的 process_mode（处理模式）
class_name ProcessingComponent  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类

# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var bool_resource:BoolResource  # 布尔资源（控制游戏暂停状态，如 "is_paused"）
@export var paused_nodes:Array[Node] = []  # 需要根据暂停状态调整 process_mode 的节点列表
@export var unpaused_nodes:Array[Node] = []  # 状态与 paused_nodes 相反的节点列表（暂停时保持运行，恢复时暂停）
@export var paused_state:Node.ProcessMode  # 暂停时 paused_nodes 的 process_mode（如 ProcessMode.PAUSED）
@export var not_paused_state:Node.ProcessMode  # 未暂停时 paused_nodes 的 process_mode（如 ProcessMode.INHERIT）

# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	# 监听布尔资源的更新信号（当布尔值变化时触发 pause_changed）
	bool_resource.updated.connect(pause_changed)
	# 初始化时立即同步状态（确保初始状态正确）
	pause_changed()

# -------------------- 核心逻辑：根据布尔资源状态更新节点处理模式 --------------------
func pause_changed()->void:
	# 获取当前暂停状态（布尔资源的当前值）
	var _is_paused:bool = bool_resource.value
	
	# 遍历 paused_nodes：暂停时设置为 paused_state，否则设置为 not_paused_state
	for node:Node in paused_nodes:
		if node == null || !node.is_inside_tree():
			continue  # 跳过无效节点
		node.process_mode = paused_state if _is_paused else not_paused_state
	
	# 遍历 unpaused_nodes：状态与 paused_nodes 相反（暂停时设置为 not_paused_state，否则设置为 paused_state）
	for node:Node in unpaused_nodes:
		if node == null || !node.is_inside_tree():
			continue
		node.process_mode = not_paused_state if _is_paused else paused_state
