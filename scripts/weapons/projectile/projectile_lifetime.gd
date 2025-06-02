# 投射物生命周期管理节点：控制投射物的存活时间，到期后触发退出流程
class_name ProjectileLifetime  # 定义类名，作为投射物生命周期控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 存活时间：投射物从生成到自动销毁的持续时间（秒）
@export var time:float = 1.0  
## 投射物引用：需要管理生命周期的Projectile节点（需绑定具体投射物实例）
@export var projectile:Projectile  


# -------------------- 成员变量（运行时状态） --------------------
var tween:Tween  # 补间动画控制器（用于延迟销毁逻辑，非实际动画，仅作定时器使用）


# -------------------- 生命周期方法（初始化定时器） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ProjectileLifetime: 投射物引用（projectile）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 销毁可能存在的旧补间（避免重复创建）
	if tween != null:
		tween.kill()
	
	# 若存活时间无效（非正数），直接返回（不创建定时器）
	if time <= 0.0:
		return
	
	# 创建新补间作为定时器，延迟time秒后触发_on_timeout
	tween = create_tween()
	tween.tween_callback(_on_timeout).set_delay(time)


# -------------------- 超时回调（触发投射物退出） --------------------
## @brief 存活时间结束时调用，触发投射物的退出流程
func _on_timeout()->void:
	if projectile != null && projectile.is_inside_tree():
		projectile.prepare_exit()  # 调用投射物的退出方法（如播放特效、回收对象池）
