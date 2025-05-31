# 敌人波次管理器节点：协调波次生成、敌人数量统计及战斗模式切换
class_name EnemyWaveManager  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 战斗模式布尔资源（控制战斗是否激活，true 为进行中）
@export var fight_mode_resource:BoolResource

## 当前波次编号资源（记录当前进行的波次号）
@export var wave_number_resource:IntResource

## 剩余波次计数资源（记录未生成的波次数量）
@export var remaining_wave_count_resource:IntResource

## 当前波次敌人数量资源（记录当前存活敌人数量）
@export var enemy_count_resource:IntResource

## 敌人管理器节点（负责波次队列和敌人生成逻辑）
@export var enemy_manager:EnemyManager


# -------------------- 生命周期方法（节点初始化与销毁） --------------------
func _ready()->void:
	# 确保关键资源已配置（调试模式校验）
	if fight_mode_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemyWaveManager: 战斗模式资源未配置", LogManager.LogLevel.ERROR)
		return
	if remaining_wave_count_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemyWaveManager: 剩余波次计数资源未配置", LogManager.LogLevel.ERROR)
		return
	if enemy_count_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "EnemyWaveManager: 敌人数量资源未配置", LogManager.LogLevel.ERROR)
		return
	
	# 信号连接：战斗模式激活时初始化波次计数（Setup 1）
	fight_mode_resource.changed_true.connect(_init_wave_count)
	# 信号连接：剩余波次计数更新时重置当前波次敌人数量（Setup 2）
	remaining_wave_count_resource.updated.connect(_reset_enemy_count)
	# 信号连接：敌人数量更新时处理波次推进（Setup 3）
	enemy_count_resource.updated.connect(_update_wave_count)

func _exit_tree() -> void:
	# 清理资源：退出时关闭战斗模式并重置计数
	fight_mode_resource.set_value(false)
	enemy_count_resource.set_value(0)
	remaining_wave_count_resource.set_value(0)
	
	# 信号断开
	fight_mode_resource.changed_true.disconnect(_init_wave_count)
	remaining_wave_count_resource.updated.disconnect(_reset_enemy_count)
	enemy_count_resource.updated.disconnect(_update_wave_count)


# -------------------- 波次初始化逻辑（Setup 1） --------------------
func _init_wave_count()->void:
	# 设置剩余波次数量为敌人管理器中波次队列的总长度
	remaining_wave_count_resource.set_value(enemy_manager.wave_queue.waves.size() - 1)
	# 初始化波次编号为 0（通常波次从 1 开始，此处可能需调整）
	wave_number_resource.set_value(1)


# -------------------- 重置敌人数量逻辑（Setup 2） --------------------
func _reset_enemy_count()->void:
	if remaining_wave_count_resource.value == 0:
		# 若无剩余波次，关闭战斗模式
		fight_mode_resource.set_value(false)
		return
	
	# 获取当前波次列表（从波次队列前端获取）
	var _wave_list:SpawnWaveList = enemy_manager.wave_queue.waves.front()
	var _enemy_count:int = _wave_list.count  # 获取当前波次敌人数量
	
	# TODO：此处应添加敌人强度与生成规则（如随机生成、间隔生成等）
	enemy_count_resource.set_value(_enemy_count)  # 更新敌人数量资源


# -------------------- 波次推进逻辑（Setup 3） --------------------
func _update_wave_count()->void:
	if !fight_mode_resource.value:
		return  # 非战斗模式时跳过
	
	if remaining_wave_count_resource.value == 0:
		return  # 无剩余波次时跳过
	
	if enemy_count_resource.value > 0:
		return  # 仍有敌人存活时跳过
	
	# 推进波次：移除已完成的波次（队列前端弹出）
	enemy_manager.wave_queue.waves.pop_front()
	# 更新剩余波次数量
	remaining_wave_count_resource.set_value(enemy_manager.wave_queue.waves.size())
	
	if enemy_manager.wave_queue.waves.is_empty():
		return  # 所有波次完成时结束
	
	# 波次编号自增（当前波次为弹出后的下一个波次）
	wave_number_resource.set_value(wave_number_resource.value + 1)
