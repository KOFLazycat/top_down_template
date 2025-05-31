# 场景过渡资源：存储场景切换所需的配置参数与状态
class_name SceneTransitionResource  # 定义资源类名，可在场景中作为资源实例使用
extends SaveableResource  # 继承自可保存资源（支持数据持久化，尽管当前未使用保存功能）

# 信号：当场景切换参数准备就绪时触发（通知场景管理器执行实际切换）
signal change_scene

# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var player_reference:ReferenceNodeResource  # 玩家引用资源（用于跨场景传递玩家实例）
@export var next_scene_path:String  # 下一场景的文件路径（如 "res://scenes/Level2.tscn"）
@export var entry_tag:String  # 目标场景的入口标签（与 SceneEntry 节点的 tag 匹配）

# -------------------- 运行时变量（场景切换匹配状态） --------------------
var entry_match:Node2D  # 匹配的场景入口节点（由 SceneEntry 节点在 _ready 时自动赋值）


# -------------------- 核心方法：设置场景切换参数并触发信号 --------------------
func set_next_scene(scene_path:String, entry:String)->void:
	# 确保关键参数有效（调试模式生效）
	if player_reference == null:
		Log.entry("SceneTransitionResource: 玩家引用资源未配置", LogManager.LogLevel.ERROR)
		return
	if player_reference.node == null:
		Log.entry("SceneTransitionResource: 玩家节点为空，无法完成切换场景", LogManager.LogLevel.ERROR)
		return
	if scene_path.is_empty():
		Log.entry("SceneTransitionResource: 下一场景路径为空", LogManager.LogLevel.ERROR)
		return
	if entry.is_empty():
		Log.entry("SceneTransitionResource: 入口标签为空", LogManager.LogLevel.ERROR)
		return
	# 赋值场景切换参数
	next_scene_path = scene_path
	entry_tag = entry
	
	# 发射场景切换信号（通知外部逻辑执行实际场景切换）
	change_scene.emit()
