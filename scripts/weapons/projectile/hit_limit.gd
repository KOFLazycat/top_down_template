# 命中次数限制节点：控制投射物的最大命中次数，达到限制后触发投射物退出
class_name HitLimit  # 定义类名，可在场景中作为命中次数控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 投射物引用：需要限制命中次数的投射物节点（如子弹、箭矢）
@export var projectile:Projectile  
## 数据传输器：监听命中成功信号（如伤害传输器）
@export var data_transmitter:DataChannelTransmitter  
## 目标命中限制：允许的最大命中次数，负数表示无限次
@export var target_hit_limit:int = 1  

# -------------------- 成员变量（运行时状态） --------------------
var remaining_hits:int  # 剩余命中次数（初始为target_hit_limit，负数时视为无限）


# -------------------- 生命周期方法（初始化命中次数与信号连接） --------------------
func _ready()->void:
	if projectile == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "HitLimit: 投射物引用（projectile）未配置", LogManager.LogLevel.ERROR)
		return
	if data_transmitter == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "HitLimit: 数据传输器（data_transmitter）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 处理无限命中情况（target_hit_limit < 1时不限制次数）
	if target_hit_limit < 1:
		return
	
	remaining_hits = target_hit_limit  # 初始化剩余次数
	
	# 连接数据传输器的命中成功信号（每次命中时触发回调）
	if !data_transmitter.success.is_connected(on_hit):
		data_transmitter.success.connect(on_hit)


# -------------------- 命中回调（处理命中次数递减与投射物退出） --------------------
## @brief 当数据传输器检测到命中时调用
func on_hit()->void:
	if target_hit_limit < 1:
		return  # 无限次数时直接返回
	
	if remaining_hits < 1:
		return  # 剩余次数已耗尽，跳过处理
	
	remaining_hits -= 1  # 消耗一次命中次数
	
	# 剩余次数为0时触发投射物退出
	if remaining_hits == 0:
		if projectile != null && projectile.is_inside_tree():
			projectile.prepare_exit()  # 调用投射物的退出逻辑（如销毁或回收）
