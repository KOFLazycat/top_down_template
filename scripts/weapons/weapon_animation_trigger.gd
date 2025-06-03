# 武器动画触发器：响应射击事件，按顺序循环播放武器动画
class_name WeaponAnimationTrigger  # 定义类名，作为武器动画控制核心组件
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 武器触发组件：监听射击事件以触发动画播放（需绑定WeaponTrigger节点）
@export var weapon_trigger:WeaponTrigger  
## 动画播放器：负责播放武器动画的AnimationPlayer节点
@export var animation_player:AnimationPlayer  
## 动画名称数组：按顺序播放的动画列表（如["shoot_01", "shoot_02", "shoot_03"]）
@export var animation_list:Array[StringName]  


# -------------------- 成员变量（运行时状态） --------------------
var animation_index:int = 0  # 当前播放的动画索引（默认从第一个动画开始）


# -------------------- 生命周期方法（信号连接初始化） --------------------
func _ready()->void:
	if weapon_trigger == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponAnimationTrigger: 武器触发组件（weapon_trigger）未配置", LogManager.LogLevel.ERROR)
		return
	if animation_player == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponAnimationTrigger: 动画播放器（animation_player）未配置", LogManager.LogLevel.ERROR)
		return
	if animation_list.is_empty():
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponAnimationTrigger: 动画列表未配置，动画触发逻辑失效", LogManager.LogLevel.ERROR)
		return
	
	# 连接武器触发组件的射击事件到动画播放方法
	weapon_trigger.shoot_event.connect(play)


# -------------------- 射击事件回调（播放动画） --------------------
## @brief 响应射击事件，按顺序循环播放动画列表中的动画
func play()->void:
	animation_player.stop()  # 停止当前播放的动画（避免动画叠加）
	
	# 播放当前索引对应的动画（确保索引在有效范围内）
	if animation_index < animation_list.size():
		var current_animation = animation_list[animation_index]
		if animation_player.has_animation(current_animation):
			animation_player.play(current_animation)
		else:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponAnimationTrigger: 动画不存在：" + str(current_animation), LogManager.LogLevel.ERROR)
			return
	
	# 更新动画索引（循环播放：0 → 1 → ... → n-1 → 0）
	animation_index = (animation_index + 1) % animation_list.size()
