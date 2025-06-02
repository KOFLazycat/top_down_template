# 巨型果冻史莱姆生成器：在特定事件（如弹丸退出）触发时，生成多个史莱姆敌人
class_name BigJellySlimeSpawner  # 定义类名，作为场景中的史莱姆生成控制器
extends Node  # 继承自基础节点类


# -------------------- 静态变量（全局敌人管理） --------------------
## 活跃敌人分支：静态变量，用于存储全局活跃敌人的资源引用（通常由EnemyManager等全局节点管理）
static var active_enemy_branch:ActiveEnemyResource  


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 弹丸引用：触发生成事件的弹丸（如史莱姆发射的子弹，退出时触发生成）
@export var projectile:Projectile  
## 实例资源：用于生成史莱姆敌人的预制体资源（包含敌人的场景或脚本）
@export var instance_resource:InstanceResource  
## 生成角度数组：相对于弹丸方向的角度偏移（单位：度，例如[30, -30]表示左右各30度）
@export var angles:Array[float]  
## 生成距离：史莱姆生成位置与弹丸当前位置的距离（单位：像素）
@export var spawn_distance:float = 8.0  
## 轴乘数资源：用于调整生成方向的缩放（例如Vector2(1,0.5)可使Y轴方向缩短）
@export var axis_multiplication:Vector2Resource  
## 生成位置随机偏移范围（像素）
@export var spawn_random_offset:float = 2.0  

# -------------------- 生命周期方法（初始化与信号连接） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellySlimeSpawner: 弹丸引用节点未配置", LogManager.LogLevel.ERROR)
		return
	if instance_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellySlimeSpawner: 实例资源（instance_resource）未配置", LogManager.LogLevel.ERROR)
		return
	if angles.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "BigJellySlimeSpawner: 生成角度数组（angles）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 监听弹丸的"prepare_exit"（准备退出）事件（通常在弹丸即将销毁时触发）
	projectile.prepare_exit_event.connect(_on_prepare_exit)


# -------------------- 弹丸退出回调（生成史莱姆敌人） --------------------
## @brief 当弹丸准备退出时，根据配置生成多个史莱姆敌人
func _on_prepare_exit()->void:
	# 获取弹丸的当前方向（运动方向）和全局位置
	var _direction:Vector2 = projectile.direction
	var _pos:Vector2 = projectile.global_position
	
	# 遍历角度数组，为每个角度生成一个史莱姆敌人
	for _degree:float in angles:
		# 定义实例化配置回调：设置敌人的方向、位置并加入活跃敌人分支
		var _config_callback:Callable = func (inst:Node)->void:
			var _random_offset = Vector2(randf_range(-spawn_random_offset, spawn_random_offset), randf_range(-spawn_random_offset, spawn_random_offset))
			# 计算生成方向：弹丸方向旋转指定角度后，乘以轴乘数，再归一化（确保方向单位长度）
			var _dir:Vector2 = (_direction.rotated(deg_to_rad(_degree)) * axis_multiplication.value).normalized()
			# 设置敌人的全局位置：弹丸位置 + 生成方向 * 生成距离（确保在弹丸周围指定距离生成）
			inst.global_position = _pos + spawn_distance * _dir + _random_offset
			
			# 将敌人实例插入到活跃敌人分支下（由全局资源管理敌人生命周期）
			ActiveEnemy.insert_child(inst, active_enemy_branch)
		
		# 使用实例资源生成敌人，并应用配置回调
		instance_resource.instance(_config_callback)
