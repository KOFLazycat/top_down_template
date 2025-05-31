# 玩家特效节点：处理玩家受伤时的视觉反馈（屏幕抖动、闪光等）
class_name PlayerJuice  # 定义类名，可在场景中作为玩家特效控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点：存储健康、伤害等资源
@export var resource_node:ResourceNode  
## 敌人造成伤害时的相机抖动资源
@export var enemy_damage_shake:CameraShakeResource  
## 屏幕闪光动画播放器引用节点（需指向场景中的AnimationPlayer节点）
@export var screen_flash_animation_player:ReferenceNodeResource  
## 玩家自身受伤时的相机抖动资源
@export var player_damage_shake:CameraShakeResource
## 可配置的闪光动画名称
@export var flash_animation_name:StringName = "white_flash"  


# -------------------- 生命周期方法（节点初始化与信号连接） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerJuice: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if enemy_damage_shake == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerJuice: 敌人相机抖动资源（enemy_damage_shake）未配置", LogManager.LogLevel.ERROR)
		return
	if screen_flash_animation_player == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerJuice: 屏幕闪光动画播放器引用未设置", LogManager.LogLevel.ERROR)
		return
	if player_damage_shake == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerJuice: 玩家相机抖动资源（player_damage_shake）未配置", LogManager.LogLevel.ERROR)
		return
	# 获取玩家健康资源（监听受伤事件）
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if _health_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerJuice: 健康资源（health）未配置，受伤特效失效", LogManager.LogLevel.ERROR)
		return
	_health_resource.damaged.connect(_on_damaged)  # 玩家受伤时触发视觉反馈
	
	# 获取伤害资源（监听伤害报告事件）
	var _damage_resource:DamageResource = resource_node.get_resource("damage")
	if _damage_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerJuice: 伤害资源（damage）未配置，伤害反馈失效", LogManager.LogLevel.ERROR)
		return
	_damage_resource.report_damage.connect(_on_damage_report)  # 敌人造成伤害时触发抖动
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(_health_resource.damaged.disconnect.bind(_on_damaged), CONNECT_ONE_SHOT)
	tree_exiting.connect(_damage_resource.report_damage.disconnect.bind(_on_damage_report), CONNECT_ONE_SHOT)
	
	# 配合对象池使用（标记节点准备完成）
	request_ready()


# -------------------- 玩家受伤回调（处理自身受伤特效） --------------------
## @brief 玩家受到伤害时触发屏幕闪光和相机抖动
func _on_damaged(_d: float)->void:
	# 校验屏幕闪光动画播放器引用是否有效
	var _flash_player:AnimationPlayer = screen_flash_animation_player.node as AnimationPlayer
	_flash_player.play(flash_animation_name)  # 播放白色闪光动画（动画名称需与AnimationPlayer中的动画一致）
	
	player_damage_shake.play()  # 播放玩家受伤相机抖动效果


# -------------------- 伤害报告回调（处理敌人造成伤害的特效） --------------------
## @brief 敌人对玩家造成伤害时触发相机抖动（如敌人攻击命中反馈）
func _on_damage_report(_damage:DamageDataResource)->void:
	enemy_damage_shake.play()  # 播放敌人造成伤害的相机抖动效果
