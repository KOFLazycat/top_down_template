# 角色伤害反馈控制器：处理受击动画、音效及死亡特效
class_name ActorDamage  # 定义类名，可在场景中作为伤害反馈节点使用
extends Node  # 继承自基础节点类


# -------------------- 信号（死亡事件通知） --------------------
## 角色死亡时触发（通知外部角色已死亡）
signal actor_died  


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储健康资源）
@export var resource_node:ResourceNode  
## 精灵翻转控制器（用于获取角色当前方向，调整死亡特效方向）
@export var sprite_flip:SpriteFlip  
## 闪烁动画播放器（用于受击时的颜色闪烁效果）
@export var flash_animation_player:AnimationPlayer  
## 闪烁动画名称（受击时播放的具体动画）
@export var flash_animation:StringName  
## 受击音效资源（受击时播放的音效）
@export var sound_resource_damage:SoundResource  
## 死亡音效资源（死亡时播放的音效）
@export var sound_resource_dead:SoundResource  
## 死亡视觉特效实例资源（死亡时生成的VFX）
@export var dead_vfx_instance_resource:InstanceResource  


# -------------------- 生命周期方法（节点初始化与信号绑定） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ActorDamage: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if sprite_flip == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ActorDamage: 精灵翻转控制器（sprite_flip）未配置，无法设置死亡特效方向", LogManager.LogLevel.ERROR)
		return
	if flash_animation_player == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ActorDamage: 闪烁动画播放器（flash_animation_player）未配置，无法播放受击动画", LogManager.LogLevel.ERROR)
		return
	# 从资源节点获取健康资源（用于监听受击和死亡事件）
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if _health_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ActorDamage: 健康资源（health）未配置", LogManager.LogLevel.ERROR)
		return
	# 连接健康资源的受击信号（受击时触发闪烁动画和音效）
	_health_resource.damaged.connect(_play_damaged)
	# 连接健康资源的死亡信号（死亡时触发死亡反馈）
	_health_resource.dead.connect(_play_dead)
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()
	
	# 播放"RESET"动画（重置闪烁动画状态，避免初始状态异常）
	flash_animation_player.play("RESET")
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(
		_remove_connections.bind(_health_resource),  # 绑定断开逻辑与健康资源实例
		CONNECT_ONE_SHOT  # 仅触发一次
	)


# -------------------- 资源清理（断开信号连接） --------------------
## @brief 断开健康资源的信号连接（防止节点销毁后仍触发回调）
## @param health_resource 需断开信号的健康资源实例
func _remove_connections(health_resource:HealthResource)->void:
	health_resource.damaged.disconnect(_play_damaged)  # 断开受击信号
	health_resource.dead.disconnect(_play_dead)       # 断开死亡信号


# -------------------- 受击反馈（动画与音效） --------------------
## @brief 受击时播放闪烁动画和受击音效
## @param _d 受击数值（未使用，保留参数）
func _play_damaged(_d: float)->void:
	# 停止当前动画（避免与其他动画冲突）
	flash_animation_player.stop()
	# 播放受击闪烁动画（使用配置的动画名称）
	flash_animation_player.play(flash_animation)
	# 播放受击音效（使用SoundResource的managed播放模式，自动管理音效实例）
	if sound_resource_damage == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ActorDamage: 受击音效资源（sound_resource_damage）未配置，无法播放音效", LogManager.LogLevel.WARNING)
	else:
		sound_resource_damage.play_managed()


# -------------------- 死亡反馈（音效与特效） --------------------
## @brief 死亡时播放死亡音效、生成死亡特效并通知外部
func _play_dead()->void:
	if sound_resource_dead == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ActorDamage: 死亡音效资源（sound_resource_dead）未配置，无法播放音效", LogManager.LogLevel.WARNING)
	else:
		# 播放死亡音效（managed模式自动管理音效实例）
		sound_resource_dead.play_managed()
	
	# 定义特效配置回调（设置特效位置和方向）
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = owner.global_position  # 特效位置与角色位置同步
		inst.scale.x = sprite_flip.dir  # 特效水平缩放与角色方向一致（1=右，-1=左）
	
	# 延迟实例化死亡特效（避免当前帧逻辑阻塞）
	dead_vfx_instance_resource.instance.call_deferred(_config_callback)
	
	# 发射死亡信号（通知外部角色已死亡）
	actor_died.emit()
