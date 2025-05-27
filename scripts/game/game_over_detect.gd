# 游戏结束检测节点：监听玩家死亡事件并切换到游戏结束场景
class_name GameOverDetect  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类

# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var player_reference:ReferenceNodeResource  # 玩家引用资源（动态跟踪玩家节点）
@export var game_over_scene_path:String  # 游戏结束场景的文件路径（如 "res://scenes/GameOver.tscn"）
@export var wait_time:float = 1.0  # 玩家死亡后延迟切换场景的时间（单位：秒）

# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	# 校验关键资源（调试模式下触发错误，确保配置正确）
	if player_reference == null:
		Log.entry("玩家引用资源未配置", LogManager.LogLevel.ERROR)
		return
	if game_over_scene_path.is_empty():
		Log.entry("游戏结束场景路径未配置", LogManager.LogLevel.ERROR)
		return
	
	# 监听玩家引用变化（当玩家节点被替换或重新生成时触发回调）
	player_reference.listen(self, on_reference_changed)

# -------------------- 核心逻辑：玩家引用变化时重新绑定健康状态监听 --------------------
func on_reference_changed()->void:
	# 玩家节点为空时返回（避免空引用）
	if player_reference.node == null:
		Log.entry("玩家节点为空", LogManager.LogLevel.ERROR)
		return
	
	# 获取玩家节点的资源节点（假设玩家节点包含名为 "ResourceNode" 的子节点）
	var _resource_node:ResourceNode = player_reference.node.get_node("ResourceNode")
	if _resource_node == null:
		Log.entry("玩家节点缺少 ResourceNode 子节点", LogManager.LogLevel.ERROR)
		return
	
	# 从资源节点中获取健康资源（存储玩家生命值的资源）
	var _health_resource:HealthResource = _resource_node.get_resource("health")
	if _health_resource == null:
		Log.entry("ResourceNode 缺少 health 资源", LogManager.LogLevel.ERROR)
		return
	
	# 连接健康资源的死亡信号（玩家生命值归零触发）
	_health_resource.dead.connect(on_player_dead, CONNECT_ONE_SHOT)

# -------------------- 核心逻辑：玩家死亡时触发延迟场景切换 --------------------
func on_player_dead()->void:
	# 创建补间动画（用于延迟切换场景）
	var _tween:Tween = create_tween()
	# 延迟 wait_time 秒后调用 on_delay 方法
	_tween.tween_callback(on_delay).set_delay(wait_time)

# -------------------- 核心逻辑：实际切换游戏结束场景 --------------------
func on_delay()->void:
	# 加载游戏结束场景包
	var next_scene:PackedScene = load(game_over_scene_path)
	if next_scene == null:
		Log.entry("游戏结束场景加载失败：%s" % game_over_scene_path, LogManager.LogLevel.ERROR)
		return
	
	# 获取场景树并切换场景
	var scene_tree:SceneTree = get_tree()
	var err:int = scene_tree.change_scene_to_packed(next_scene)
	if err != OK:
		Log.entry("场景切换失败，错误码：%d" % err, LogManager.LogLevel.ERROR)
		return
