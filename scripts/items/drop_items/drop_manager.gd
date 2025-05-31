# 掉落管理器节点：处理敌人死亡后的物品掉落逻辑
class_name DropManager  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类

# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var enemy_spawner:EnemySpawner  # 敌人生成器引用（用于监听敌人死亡信号）
@export var coin_instance:InstanceResource  # 金币预制体（敌人死亡时必掉的物品）
@export var health_pickup_instance:InstanceResource  # 血包预制体（概率掉落的物品）
@export var luck_resource:FloatResource  # 幸运值资源（未使用，可用于调整掉落概率）
@export var drop_chance:float = 0.3  # 血包的基础掉落概率（0.3 表示 30%）

# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	# 连接敌人生成器的敌人死亡信号到 _on_killed 方法
	enemy_spawner.enemy_killed.connect(_on_killed)

# -------------------- 核心逻辑：敌人死亡时生成掉落物 --------------------
func _on_killed(enemy:ActiveEnemy)->void:
	if coin_instance == null || health_pickup_instance == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DropManager: 掉落预制体未配置，请检查资源！", LogManager.LogLevel.ERROR)
		return
	
	# 获取敌人死亡时的位置（用于掉落物生成）
	var _position:Vector2 = enemy.owner.global_position
	
	# 定义金币生成的回调函数（设置生成位置）
	var _config_callback:Callable = func (inst:Node2D)->void:
		inst.global_position = _position
	
	# 必掉金币：实例化金币预制体并设置位置
	coin_instance.instance(_config_callback)
	
	# 概率掉落血包：生成随机数判断是否触发掉落
	var _rand:float = randf_range(0.0, 1.0)  # 生成 0-1 的随机数
	if _rand > drop_chance:  # 随机数大于掉落概率时不生成血包
		return
	# 生成血包：实例化血包预制体并设置位置
	health_pickup_instance.instance(_config_callback)
