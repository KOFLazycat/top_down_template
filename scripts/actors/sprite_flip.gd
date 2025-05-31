# 精灵翻转控制器：根据输入方向水平翻转精灵节点
class_name SpriteFlip  # 定义类名，可在场景中作为翻转控制节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 资源节点（存储输入资源）
@export var resource_node:ResourceNode  
## 需要翻转的2D节点（通常为Sprite2D、AnimatedSprite2D等可视化节点）
@export var flip_node:Node2D  
## 翻转类型枚举（基于行走方向或瞄准方向）
enum FlipType {WALK_DIR, AIM_DIR}  
## 选择翻转逻辑关联的输入类型（行走/瞄准）
@export var flip_type:FlipType
@export var dead_zone:float = 0.1  # 输入死区（0~1，超过此值才视为有效方向）

# -------------------- 成员变量（运行时状态） --------------------
## 当前方向（1=右，-1=左）
var dir:int = 1  
## 输入资源实例（获取输入轴或瞄准方向）
var input_resource:InputResource  


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("SpriteFlip: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# 从资源节点获取输入资源（确保非空）
	input_resource = resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("SpriteFlip: 输入资源（input）未配置", LogManager.LogLevel.ERROR)
		return
	
	if flip_node == null:
		Log.entry("SpriteFlip: 翻转节点（flip_node）未配置，无法执行翻转逻辑", LogManager.LogLevel.ERROR)
		return
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()


# -------------------- 帧更新（处理翻转逻辑） --------------------
func _process(_delta:float)->void:
	var new_dir:int  # 新方向（根据输入计算）
	
	# 根据翻转类型选择输入源（行走方向或瞄准方向）
	var raw_input:float
	match flip_type:
		FlipType.WALK_DIR:
			raw_input = input_resource.axis.x # 行走输入的x轴方向（-1/0/1）
		FlipType.AIM_DIR:
			raw_input = input_resource.aim_direction.x # 瞄准方向的x轴分量（-1/0/1）
	
	# 过滤死区内的输入（绝对值小于死区时视为0）
	new_dir = sign(raw_input) if abs(raw_input) > dead_zone else 0
	
	# 输入为0（无方向）或方向未变化时跳过
	if new_dir == 0:
		return
	if new_dir == dir:
		return
	
	# 更新方向并翻转精灵
	dir = new_dir
	flip_node.scale.x = dir  # 通过水平缩放的正负实现翻转（1=右，-1=左）
