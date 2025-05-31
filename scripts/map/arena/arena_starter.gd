# 战斗区域启动器：通过区域触发激活战斗模式
class_name ArenaStarter  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类

# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var fight_mode:BoolResource  # 战斗模式开关资源（控制战斗是否激活）
@export var area:Area2D  # 触发区域（玩家进入时激活战斗模式）

# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if fight_mode == null:
		Log.entry("ArenaStarter: 战斗模式资源未配置", LogManager.LogLevel.ERROR)
		return
	if area == null:
		Log.entry("ArenaStarter: 触发区域未配置", LogManager.LogLevel.ERROR)
		return
	
	# 当战斗模式激活（变为true）时，延迟销毁当前节点（避免立即移除导致信号未处理）
	fight_mode.changed_true.connect(owner.queue_free.call_deferred)
	# 监听触发区域的body_entered信号（当物体进入区域时触发）
	area.body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)

# -------------------- 核心逻辑：区域触发时激活战斗模式 --------------------
func _on_body_entered(body:Node2D)->void:
	 # 仅玩家触发
	if !body.is_in_group("player"):  # 或通过组判断
		return
	# 延迟调用设置战斗模式为true（确保线程安全，因物理线程触发需同步到主线程）
	fight_mode.set_value.call_deferred(true)
