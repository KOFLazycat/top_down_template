class_name SpreadShot  # 定义类名，用于创建具有散射效果的射击逻辑
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 投射物生成器：绑定负责生成投射物的组件（需配置角度数组）
@export var projectile_spawner:ProjectileSpawner  
## 随机角度偏移范围：每个投射物角度的随机偏移量（度数，范围0.0~180.0）
@export_range(0.0, 180.0) var random_angle_offset:float  

## 存储初始角度数组：保留投射物生成器的原始角度配置（避免直接修改原始数据）
var stored_projectile_angles:Array[float] = [0.0]  


# -------------------- 生命周期方法（初始化与信号连接） --------------------
func _ready()->void:
	if projectile_spawner == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SpreadShot: 投射物生成器（projectile_spawner）未配置", LogManager.LogLevel.ERROR)
		return
	# 复制投射物生成器的原始角度数组（防止后续操作修改原始配置）
	stored_projectile_angles = projectile_spawner.projectile_angles.duplicate()
	# 监听投射物生成器的"prepare_spawn"信号（生成前调整角度）
	projectile_spawner.prepare_spawn.connect(on_prepare_spawn)


# -------------------- 散射角度计算回调（在生成前调整角度数组） --------------------
## @brief 在投射物生成前，为每个角度添加随机偏移量，实现散射效果
func on_prepare_spawn()->void:
	# 遍历存储的初始角度数组，生成带随机偏移的新角度
	for i in range(stored_projectile_angles.size()):
		# 生成随机偏移角度（范围：-random_angle_offset 到 +random_angle_offset）
		var rand_angle:float = randf_range(-random_angle_offset, random_angle_offset)
		# 更新投射物生成器的角度数组（每个角度基于初始值叠加随机偏移）
		projectile_spawner.projectile_angles[i] = stored_projectile_angles[i] + rand_angle
