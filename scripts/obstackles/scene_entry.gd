# 场景入口节点：通过区域检测触发场景切换，管理玩家跨场景的位置同步
class_name SceneEntry  # 定义类名，可在场景中作为区域节点使用
extends Area2D  # 继承自 2D 区域节点（用于物理碰撞检测）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var tag:String  # 入口标签（用于标识当前入口，需与目标场景的 connect_tag 匹配）
@export var connect_tag:String  # 连接标签（目标场景中匹配的入口 tag）
@export var scene_path:String  # 目标场景文件路径（切换后的目标场景）
@export var scene_transition_resource:SceneTransitionResource  # 场景过渡资源（管理切换逻辑与数据）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	# 确保关键标签和路径已配置（调试模式生效）
	if tag.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SceneEntry: 场景入口标签（tag）未配置", LogManager.LogLevel.ERROR)
		return
	if connect_tag.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SceneEntry: 连接标签（connect_tag）未配置", LogManager.LogLevel.ERROR)
		return
	if scene_path.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SceneEntry: 连接标签（connect_tag）未配置", LogManager.LogLevel.ERROR)
		return
	if scene_transition_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SceneEntry: 场景过渡资源（scene_transition_resource）未配置，节点：%s" % name, LogManager.LogLevel.ERROR)
		return
	
	# 配置区域禁用模式：暂停时保持活动状态（避免物理线程中断导致检测失效）
	disable_mode = DISABLE_MODE_KEEP_ACTIVE
	
	# 检查是否为场景入口标记（由场景过渡资源指定）
	if scene_transition_resource.entry_tag == tag:
		# 标记为场景入口匹配节点（用于过渡时的位置同步）
		scene_transition_resource.entry_match = self
		# 玩家离开区域时触发回调（单次连接避免重复触发）
		body_exited.connect(_on_body_exited, CONNECT_ONE_SHOT)
		return
	
	# 非入口标记时：玩家进入区域时触发场景切换（单次连接避免重复触发）
	body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)


# -------------------- 核心逻辑：玩家进入区域时触发场景切换 --------------------
func _on_body_entered(_body:Node2D)->void:
	# 设置下一个场景路径与连接标签（通知过渡资源准备切换）
	scene_transition_resource.set_next_scene(scene_path, connect_tag)


# -------------------- 核心逻辑：玩家离开区域时重新监听进入事件 --------------------
func _on_body_exited(_body:Node2D)->void:
	# 重新连接进入事件（确保离开后可再次触发切换）
	body_entered.connect(_on_body_entered, CONNECT_ONE_SHOT)
