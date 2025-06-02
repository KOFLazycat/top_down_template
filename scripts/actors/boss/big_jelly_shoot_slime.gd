# 巨型果冻史莱姆射击控制节点：处理史莱姆向目标位置射击弹丸的逻辑
class_name BigJellyShootSlime  # 定义类名，作为场景中史莱姆的射击控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 弹丸实例资源：用于生成射击弹丸的预制体（需包含Projectile组件）
@export var projectile_instance:InstanceResource  
## 发射原点节点：弹丸生成的参考位置节点（通常为史莱姆的发射口节点）
@export var origin_node:Node2D  
## 活跃敌人节点：关联当前史莱姆的敌人资源（用于管理子敌人数量）
@export var active_enemy:ActiveEnemy  
## 轴乘数资源：调整发射方向在不同轴上的缩放（如水平/垂直方向速度差异）
@export var axis_multiply:Vector2Resource  
## 发射半径：弹丸生成位置与发射原点的距离（控制弹丸生成范围）
@export var spawn_radius:float = 32.0  
## 射击音效资源：发射弹丸时播放的音效
@export var shoot_sound:SoundResource  
## 子敌人数量限制：避免生成过多子敌人导致性能问题
@export var child_limit:int = 8  


# -------------------- 生命周期方法（初始化静态变量） --------------------
func _ready() -> void:
	if projectile_instance == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyShootSlime: 弹丸实例资源（projectile_instance）未配置", LogManager.LogLevel.ERROR)
		return
	if origin_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyShootSlime: 发射原点节点（origin_node）未配置", LogManager.LogLevel.ERROR)
		return
	if active_enemy == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyShootSlime: 活跃敌人节点（active_enemy）未配置", LogManager.LogLevel.ERROR)
		return
	if shoot_sound == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellyShootSlime: 射击音效资源（shoot_sound）未配置", LogManager.LogLevel.ERROR)
		return
	# 设置静态变量：将当前敌人资源分支赋值给BigJellySlimeSpawner的全局引用
	# 注：静态变量可能导致多实例冲突，需确保唯一性
	BigJellySlimeSpawner.active_enemy_branch = active_enemy.enemy_resource


# -------------------- 核心射击方法（返回是否射击成功） --------------------
## @brief 向目标位置发射弹丸，受子敌人数量限制
## @param target_position 目标位置（世界坐标）
## @return bool 射击是否成功（超过数量限制时返回false）
func shoot(target_position:Vector2)->bool:
	# 检查子敌人数量是否超过限制（防止性能过载）
	var _child_count:int = active_enemy.enemy_resource.children.size()
	if _child_count > child_limit:
		return false  # 超过限制，射击失败
	
	# 计算发射方向：目标位置相对于发射原点的标准化向量
	var _direction:Vector2 = (target_position - origin_node.global_position).normalized()
	# 处理零向量方向（避免除以零错误）
	if _direction.length_squared() < 0.001:
		_direction = Vector2.RIGHT  # 默认向右发射
	
	# 计算弹丸生成位置：发射原点 + 方向 * 发射半径 * 轴乘数
	var _pos:Vector2 = origin_node.global_position + (spawn_radius * _direction * axis_multiply.value)
	
	# 定义弹丸实例化配置回调：设置弹丸位置和目标点
	var _config_callback:Callable = func (inst:Projectile)->void:
		inst.global_position = _pos  # 设置弹丸生成位置
		inst.destination = target_position  # 设置弹丸目标位置
		# WARNING: 若史莱姆在弹丸活跃期间死亡，可能导致引用失效
		# 建议：添加弹丸生命周期管理或弱引用
	
	# 实例化弹丸并应用配置回调
	projectile_instance.instance(_config_callback)
	
	# 播放射击音效（使用managed模式自动管理音效生命周期）
	shoot_sound.play_managed()
	
	return true  # 射击成功
