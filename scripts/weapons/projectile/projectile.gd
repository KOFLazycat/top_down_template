class_name Projectile  # 定义类名，可在场景中作为各类投射物（如子弹、箭矢）的基础控制器
extends Node2D  # 继承自2D节点，支持物理移动和场景树管理


# -------------------- 信号定义（状态通知） --------------------
## 准备退出信号：在投射物即将销毁前触发（用于特效播放或状态同步）
signal prepare_exit_event  


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 移动速度：投射物每秒移动的距离（像素/秒）
@export var speed:float  
## 插值移动时间：到达目标位置所需时间（用于Tween插值移动，与speed互斥）
@export var time:float  
## 移动方向：标准化方向向量（如Vector2.RIGHT表示向右移动）
@export var direction:Vector2 = Vector2.ZERO  
## 目标位置：插值移动的目标点（世界坐标，与direction互斥）
@export var destination:Vector2 = Vector2.ZERO  
## 轴乘数资源：调整X/Y轴移动速度的比例（如Vector2(1, 0.5)表示Y轴速度减半）
@export var axis_multiplier_resource:Vector2Resource  
## 伤害数据资源：包含伤害值、击退强度等属性（需绑定DamageDataResource）
@export var damage_data_resource:DamageDataResource  
## 碰撞掩码：2D物理碰撞层（用于指定检测哪些层的对象）
@export_flags_2d_physics var collision_mask:int  
## 自动释放：是否在退出时自动调用对象池回收（默认启用）
@export var auto_free:bool = true  
## 对象池节点：用于回收投射物节点（需绑定PoolNode）
@export var pool_node:PoolNode  
## 生命周期：投射物存活时间（未实现，TODO：用于延迟销毁）
@export var lifetime:float 

func _ready() -> void:
	if damage_data_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "Projectile: 伤害数据资源（damage_data_resource）未配置", LogManager.LogLevel.ERROR)
		return
	if pool_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "Projectile: 对象池节点（pool_node）未配置", LogManager.LogLevel.ERROR)
		return


# -------------------- 核心方法：准备退出逻辑 --------------------
## @brief 触发投射物退出流程（停止更新、发送信号、回收节点）
func prepare_exit()->void:
	set_physics_process(false)  # 停止物理帧更新（节省性能）
	prepare_exit_event.emit()  # 通知外部投射物即将退出
	if auto_free:  # 自动释放模式下回收节点
		remove()  # 调用回收方法（对象池模式）


# -------------------- 回收方法：返回对象池 --------------------
## @brief 将投射物返回对象池（替代queue_free，支持复用）
func remove()->void:
	if pool_node != null:
		pool_node.pool_return()  # 返回对象池
	else:
		queue_free()  # 无对象池时直接释放
