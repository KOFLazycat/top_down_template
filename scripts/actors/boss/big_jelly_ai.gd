# 巨型果冻史莱姆AI控制节点：管理史莱姆的追逐、跳跃和射击行为逻辑
class_name BigJellyAi  # 定义类名，作为场景中的AI核心控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 玩家引用节点：动态获取玩家节点（支持跨场景引用）
@export var player_reference:ReferenceNodeResource  
## 追逐行为组件：处理跳跃追逐逻辑（需绑定BigJellyChase节点）
@export var chase:BigJellyChase  
## 角色伤害组件：监听角色死亡事件（需绑定ActorDamage节点）
@export var actor_damage:ActorDamage  
## 脱离范围距离：当与玩家距离超过此值时触发近距离跳跃
@export var out_of_range_distance:float = 4 * 32  # 4格（假设每格32像素）
## 最大跳跃距离：普通跳跃的最大距离（像素）
@export var max_jump_distance:float = 3 * 32.0  
## 近程最大跳跃距离：距离过远时允许的更大跳跃距离
@export var max_jump_close_in:float = 4 * 32.0  
## 射击控制组件：处理弹丸发射逻辑（需绑定BigJellyShootSlime节点）
@export var shoot_slime:BigJellyShootSlime  


# -------------------- 成员变量（运行时状态） --------------------
var enabled:bool = false  # AI启用状态（玩家存在时激活）
var CLOSE_IN_MAX_JUMPS:int = 4  # 近距离跳跃最大次数（防止无限跳跃）
var close_in_counter:int = 0  # 剩余近距离跳跃次数
var tween_wait:Tween = null  # 补间动画控制器（用于射击冷却）


# -------------------- 生命周期方法（初始化与信号连接） --------------------
func _ready()->void:
	if player_reference == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyAi: 玩家引用节点（player_reference）未配置", LogManager.LogLevel.ERROR)
		return
	if chase == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyAi: 追逐行为组件（chase）未配置", LogManager.LogLevel.ERROR)
		return
	if actor_damage == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyAi: 角色伤害组件（actor_damage）未配置", LogManager.LogLevel.ERROR)
		return
	if shoot_slime == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyAi: 射击控制组件（shoot_slime）未配置", LogManager.LogLevel.ERROR)
		return
	close_in_counter = CLOSE_IN_MAX_JUMPS  # 初始化近距离跳跃计数器
	
	# 追逐行为完成后触发状态更新（延迟到下一帧执行，避免帧同步问题）
	chase.finished.connect(_state_update.call_deferred)
	# 角色死亡时销毁当前节点（owner为史莱姆根节点）
	actor_damage.actor_died.connect(owner.queue_free)
	# 监听玩家引用变化（如玩家重生或切换时更新状态）
	player_reference.listen(self, _on_player_changed)


# -------------------- 玩家引用变更回调（更新AI启用状态） --------------------
func _on_player_changed()->void:
	# 玩家节点有效时启用AI，否则禁用
	enabled = player_reference.node != null
	_state_update.call_deferred()  # 延迟更新状态（确保引用稳定）

# -------------------- 核心状态更新逻辑（决定下一步行为） --------------------
func _state_update()->void:
	if !enabled:  # AI未启用时直接返回
		return
	
	# 近距离跳跃逻辑：当距离过远且还有剩余次数时执行
	if close_in_counter > 0 && _need_move_in_range():
		close_in_counter -= 1  # 消耗一次近距离跳跃次数
		# 计算近程跳跃目标（允许更大的跳跃距离）
		chase.target_calculation(
			player_reference.node.global_position,  # 玩家当前位置
			player_reference.node.velocity,         # 玩家移动速度（用于预测位置）
			max_jump_close_in                       # 近程最大跳跃距离
		)
		chase.jump_at_target()  # 执行跳跃
		return
	# 重置近距离跳跃次数
	close_in_counter = CLOSE_IN_MAX_JUMPS
	# 射击逻辑：尝试向玩家射击（返回是否成功，如受子数量限制）
	if shoot_slime.shoot(player_reference.node.global_position):
		# 创建冷却补间（2秒后再次更新状态，避免连续射击）
		if tween_wait != null:
			tween_wait.kill()
		tween_wait = create_tween()
		tween_wait.tween_callback(_state_update.call_deferred).set_delay(2.0)
		return
	
	# 普通跳跃逻辑：距离合适时执行标准跳跃追逐
	chase.target_calculation(
		player_reference.node.global_position,  # 玩家当前位置
		player_reference.node.velocity,         # 玩家移动速度
		max_jump_distance                       # 普通最大跳跃距离
	)
	chase.jump_at_target()  # 执行跳跃


# -------------------- 距离检测方法（判断是否需要近距离跳跃） --------------------
func _need_move_in_range()->bool:
	# 临时计算到玩家的距离（忽略速度，仅获取当前距离）
	chase.target_calculation(player_reference.node.global_position, Vector2.ZERO, 9999.0)
	# 实际距离超过脱离范围时返回true（需要靠近）
	return chase.distance_length >= out_of_range_distance
