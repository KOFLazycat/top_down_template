# 健康状态资源类：管理血量、最大血量及状态变更（支持存档）
class_name HealthResource  # 定义类名，可在编辑器中作为资源类型使用
extends SaveableResource  # 继承自可保存资源


# -------------------- 状态变更信号（通知外部状态变化） --------------------

## 受伤信号（当血量减少时触发），d 伤害值
signal damaged(d: float)

## 恢复血量信号（当血量增加时触发），r 恢复值
signal restored(r: float)

## 死亡信号（当血量归零且 is_dead 为 true 时触发）
signal dead

## 血量变更信号（任何血量变化时触发）
signal hp_changed

## 最大血量变更信号（当最大血量变化时触发）
signal max_hp_changed

## 满血信号（当血量等于最大血量时触发）
signal full

## 重置完成信号（当资源重置到初始状态时触发）
signal reset_update


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 当前血量（游戏运行时动态变化）
@export var hp:float = 5 :
	get: return hp
	set(value):
		var init_hp: float = hp
		hp = clamp(value, 0.0, max_hp)
		if init_hp != hp:
			hp_changed.emit()

## 最大血量（限制当前血量的上限）
@export var max_hp:float = 5 : set = set_max_hp

## 重置时的血量（调用 reset_resource 时恢复的血量）
@export var reset_hp:float = 5

## 重置时的最大血量（调用 reset_resource 时恢复的最大血量）
@export var reset_max_hp:float = 5

## 是否死亡（血量归零后标记为 true）
@export var is_dead:bool


# -------------------- 核心方法（状态管理） --------------------

## 设置最大血量（触发最大血量变更信号）
## @param value: 新的最大血量值
func set_max_hp(value:float)->void:
	var init_max_hp: float = max_hp
	max_hp = max(value, 0.0)  # 代码层限制最小值为 0
	# TODO：最大血量降低导致的前血量降低，是否需要触发damaged、hp_changed、full信号？
	if hp == init_max_hp:
		hp = max_hp
	else:
		hp = clamp(hp, 0.0, max_hp)  # 新增：确保当前血量不超过新的最大血量
	max_hp_changed.emit()  # 通知外部最大血量已变更


## 重置资源到初始状态（用于复活或重新开始）
func reset_resource()->void:
	is_dead = false  # 清除死亡标记
	max_hp = reset_max_hp  # 恢复初始最大血量
	hp = reset_hp  # 恢复初始当前血量
	hp_changed.emit()  # 通知血量变更
	reset_update.emit()  # 通知重置完成


## 从存档数据中加载状态（用于读档）
## @param data: 存档的 HealthResource 实例（需包含 is_dead、hp、max_hp）
func prepare_load(data:Resource)->void:
	if !data is HealthResource:
		Log.entry("存档数据类型错误：期望 HealthResource，实际 %s" % [data.get_class()], LogManager.LogLevel.ERROR)
		return
	is_dead = data.is_dead  # 加载死亡状态
	hp = data.hp  # 加载当前血量
	max_hp = data.max_hp  # 加载最大血量
	hp_changed.emit()  # 通知血量变更（确保 UI 同步）


## 检查是否满血（当前血量等于最大血量）
## @return: 满血返回 true，否则返回 false
func is_full()->bool:
	return hp == max_hp


## 增减血量（自动处理死亡、受伤、满血状态）
## @param value: 血量变化值（正数为加血，负数为扣血）
func add_hp(value:float)->void:
	var old_hp: float = hp
	# 限制血量在 0 到 max_hp 之间（避免负数或超上限）
	hp = clamp(hp + value, 0.0, max_hp)

	if value < 0.0:
		damaged.emit(absf(value))  # 扣血时触发受伤信号
	if value > 0.0:
		restored.emit(value)  # 回血时触发受伤信号

	if hp == 0.0:
		is_dead = true  # 血量归零标记死亡
		dead.emit()  # 触发死亡信号
		return  # 提前返回，避免重复触发

	if old_hp != max_hp and hp == max_hp:
		full.emit()  # 血量满时触发满血信号
		return  # 提前返回，避免重复触发


## 立即击杀（清空当前血量）
func insta_kill()->void:
	add_hp(-hp)  # 扣除当前所有血量（触发死亡流程）
