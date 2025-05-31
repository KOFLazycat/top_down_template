# 血迹粒子轨迹节点：管理跟随特定节点的血滴粒子效果
class_name BloodTrail  # 定义类名，可在场景中作为血迹效果控制节点
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 位置节点：用于获取粒子生成和跟随的目标位置（通常为角色或敌人节点）
@export var position_node:Node2D  
## 血迹粒子实例资源：用于生成血滴效果的GPUParticles2D预制体
@export var blood_particle_instance:InstanceResource  
## 0.1秒更新一次血迹粒子位置（可配置）
@export var update_interval:float = 0.1  


# -------------------- 成员变量（运行时状态） --------------------
var particles:GPUParticles2D  # 粒子节点实例（保存生成的GPUParticles2D引用）
var _last_update_time:float = 0.0

# -------------------- 生命周期方法（节点初始化与粒子实例化） --------------------
func _ready() -> void:
	if position_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BloodTrail: 位置节点（position_node）未配置，血迹粒子无法初始化", LogManager.LogLevel.ERROR)
		return
	if blood_particle_instance == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BloodTrail: 血迹粒子资源（blood_particle_instance）未配置，效果无法生成", LogManager.LogLevel.ERROR)
		return
	
	## 粒子实例化配置回调：在粒子节点创建后执行初始化
	var _config_callback:Callable = func (inst:Node)->void:
		particles = inst as GPUParticles2D  # 将实例转换为GPUParticles2D类型
		if particles == null:
			return  # 类型不匹配时跳过
		particles.emitting = true  # 启用粒子发射
		particles.global_position = position_node.global_position  # 初始化位置为目标节点位置
		particles.name = "BloodParticles"  # 重命名节点便于调试
	
	# 实例化粒子资源并应用配置回调
	blood_particle_instance.instance(_config_callback)
	
	# 配合对象池使用（确保节点准备完成标记）
	request_ready()


# -------------------- 物理帧更新（同步粒子位置） --------------------
## @brief 每帧同步粒子位置到目标节点的当前位置
func _physics_process(delta: float) -> void:
	if particles == null || !particles.is_inside_tree():
		return
	
	# 每帧更新粒子位置可能不必要，可降低更新频率
	_last_update_time += delta
	if _last_update_time < update_interval:
		return
	
	particles.global_position = position_node.global_position  # 更新粒子位置跟随目标节点


# -------------------- 节点退出处理（清理粒子效果） --------------------
## @brief 节点退出场景树时停止粒子发射并延迟销毁
func _exit_tree() -> void:
	if particles == null:
		return  # 粒子已销毁时跳过
	
	particles.emitting = false  # 停止粒子发射
	
	# 创建补间动画：延迟3秒后销毁粒子节点（确保粒子自然消失）
	var _tween:Tween = create_tween()
	_tween.tween_callback(particles.queue_free).set_delay(3.0)
	particles = null  # 清空引用防止悬垂
