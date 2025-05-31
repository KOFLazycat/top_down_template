# UI 信息追踪节点：监听游戏状态资源变化并更新对应 UI 标签
class_name InfoTracker  # 定义类名，可在场景中作为节点类型使用
extends Node  # 继承自 Godot 基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 分数资源（存储当前游戏分数，需暴露 `value` 变量和 `updated` 信号）
@export var score_resource:ScoreResource

## 战斗模式资源（存储战斗模式开关状态，需暴露 `value` 变量和 `updated` 信号）
@export var fight_mode_resource:BoolResource

## 波次计数资源（存储当前波次数，需暴露 `value` 变量和 `updated` 信号）
@export var wave_count_resource:IntResource

## 敌人计数资源（存储剩余敌人总数，需暴露 `value` 变量和 `updated` 信号）
@export var enemy_count_resource:IntResource

## 敌人实例资源（存储活跃敌人实例列表，需暴露 `active_list` 变量和 `updated` 信号）
@export var enemy_instance_resource:InstanceResource

## 分数显示标签（UI 中显示分数的 Label 节点）
@export var score_label:Label

## 战斗模式状态标签（UI 中显示战斗模式是否开启的 Label 节点）
@export var fight_mode_label:Label

## 波次计数标签（UI 中显示当前波次数的 Label 节点）
@export var wave_count_label:Label

## 剩余敌人标签（UI 中显示剩余敌人数量的 Label 节点）
@export var enemy_count_label:Label

## 活跃敌人标签（UI 中显示当前活跃敌人数量的 Label 节点）
@export var active_count_label:Label

# 定义常量存储标签文本（可根据需求调整或通过翻译资源替换）
const SCORE_SUFFIX:String = "G"
const FIGHT_MODE_PREFIX:String = "Fight Mode: "
const WAVE_PREFIX:String = "Remaining Waves: "
const ENEMY_PREFIX:String = "Remaining Enemies: "
const ACTIVE_PREFIX:String = "Active: "


# -------------------- 生命周期方法（节点初始化完成时调用） --------------------
func _ready()->void:
	# 连接分数资源的 `updated` 信号到分数标签更新方法，并立即初始化显示
	score_resource.updated.connect(update_score_label)
	update_score_label()

	# 连接战斗模式资源的 `updated` 信号到战斗模式标签更新方法，并立即初始化显示
	fight_mode_resource.updated.connect(update_fight_mode_label)
	update_fight_mode_label()

	# 连接波次计数资源的 `updated` 信号到波次标签更新方法，并立即初始化显示
	wave_count_resource.updated.connect(update_wave_count_label)
	update_wave_count_label()

	# 连接敌人计数资源的 `updated` 信号到敌人标签更新方法，并立即初始化显示
	enemy_count_resource.updated.connect(update_enemy_count_label)
	update_enemy_count_label()

	# 连接敌人实例资源的 `updated` 信号到活跃敌人标签更新方法，并立即初始化显示
	enemy_instance_resource.updated.connect(update_active_count_label)
	update_active_count_label()


# -------------------- UI 更新方法（响应资源变化） --------------------

## 更新分数标签（格式：分数值 + "G" 后缀）
func update_score_label()->void:
	if score_resource == null || score_label == null:
		Log.entry("InfoTracker: 分数资源或标签未配置，无法更新", LogManager.LogLevel.ERROR)
		return
	# 将分数资源的 value 转换为字符串，并添加 "G" 后缀（如 "100G"）
	score_label.text = str(score_resource.value) + SCORE_SUFFIX


## 更新战斗模式标签（格式："Fight Mode: ON" 或 "Fight Mode: OFF"）
func update_fight_mode_label()->void:
	if fight_mode_resource == null || fight_mode_label == null:
		Log.entry("InfoTracker: 战斗模式资源或标签未配置，无法更新", LogManager.LogLevel.ERROR)
		return
	# 根据战斗模式资源的 value（布尔值）显示 "ON" 或 "OFF"
	fight_mode_label.text = FIGHT_MODE_PREFIX + ("ON" if fight_mode_resource.value else "OFF")


## 更新波次计数标签（格式："Waves: 3"，假设当前波次为 3）
func update_wave_count_label()->void:
	if wave_count_resource == null || wave_count_label == null:
		Log.entry("InfoTracker: 波次计数资源或标签未配置，无法更新", LogManager.LogLevel.ERROR)
		return
	# 将波次计数资源的 value 转换为字符串，并添加前缀 "Waves: "
	wave_count_label.text = WAVE_PREFIX + str(wave_count_resource.value)


## 更新剩余敌人标签（格式："Remaining Enemies: 5"，假设剩余 5 个敌人）
func update_enemy_count_label()->void:
	if enemy_count_resource == null || enemy_count_label == null:
		Log.entry("InfoTracker: 敌人计数资源或标签未配置，无法更新", LogManager.LogLevel.ERROR)
		return
	# 将敌人计数资源的 value 转换为字符串，并添加前缀 "Remaining Enemies: "
	enemy_count_label.text = ENEMY_PREFIX + str(enemy_count_resource.value)


## 更新活跃敌人标签（格式："Active: 2"，假设当前活跃敌人数量为 2）
func update_active_count_label()->void:
	if enemy_instance_resource == null || active_count_label == null:
		Log.entry("InfoTracker: 敌人实例资源或标签未配置，无法更新", LogManager.LogLevel.ERROR)
		return
	# 检查 active_list 是否为有效数组（非 null）
	if enemy_instance_resource.active_list == null:
		active_count_label.text = ACTIVE_PREFIX + "N/A"  # 或显示 "N/A"
		return
	# 获取敌人实例资源的活跃敌人列表（active_list）的大小，转换为字符串并添加前缀 "Active: "
	active_count_label.text = ACTIVE_PREFIX + str(enemy_instance_resource.active_list.size())


func _exit_tree()->void:
	# 断开分数资源的信号连接
	if score_resource != null:
		score_resource.updated.disconnect(update_score_label)
	
	# 断开战斗模式资源的信号连接
	if fight_mode_resource != null:
		fight_mode_resource.updated.disconnect(update_fight_mode_label)
	
	# 其他资源的信号连接同理断开
	if wave_count_resource != null:
		wave_count_resource.updated.disconnect(update_wave_count_label)
	if enemy_count_resource != null:
		enemy_count_resource.updated.disconnect(update_enemy_count_label)
	if enemy_instance_resource != null:
		enemy_instance_resource.updated.disconnect(update_active_count_label)
