# 投射物发射间隔控制器：管理武器的发射间隔，避免连续射击
class_name ProjectileInterval  # 定义类名，作为武器发射间隔控制组件
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 武器触发组件：监听射击事件并控制发射状态（需绑定WeaponTrigger节点）
@export var weapon_trigger:WeaponTrigger  
## 发射间隔：两次射击之间的最小间隔时间（秒）
@export var interval:float = 0.5  


# -------------------- 成员变量（运行时状态） --------------------
var tween:Tween  # 补间动画控制器（用作定时器，控制间隔逻辑）


# -------------------- 生命周期方法（信号连接） --------------------
func _ready()->void:
	# 当武器触发组件发出射击事件时，启动间隔控制逻辑
	weapon_trigger.shoot_event.connect(start)


# -------------------- 射击开始回调（启动间隔计时） --------------------
## @brief 响应射击事件，禁用连续射击并启动间隔定时器
func start()->void:
	# 禁用武器的射击能力（防止在间隔期间再次发射）
	weapon_trigger.set_can_shoot(false)
	
	# 销毁已存在的补间（避免多个定时器同时运行）
	if tween != null:
		tween.kill()
	
	# 创建新的补间作为定时器，延迟指定间隔时间后触发超时回调
	tween = create_tween()
	tween.tween_callback(timeout).set_delay(interval)


# -------------------- 间隔超时回调（恢复射击能力） --------------------
## @brief 间隔时间结束后，恢复武器的射击能力并允许重新触发
func timeout()->void:
	# 启用武器的射击能力
	weapon_trigger.can_shoot = true
	
	# 检查是否可以重新触发射击（如连射模式下自动再次发射）
	if weapon_trigger.can_retrigger():
		weapon_trigger.on_shoot()  # 自动触发下一次射击（需根据武器逻辑决定是否启用）
