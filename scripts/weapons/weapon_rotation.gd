# 武器旋转控制器：根据鼠标/输入方向调整武器的旋转角度和翻转状态，实现视觉跟随
class_name WeaponRotation  # 定义类名，作为武器旋转逻辑的核心组件
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 武器引用：绑定需要控制旋转的Weapon节点（提供输入资源和状态）
@export var weapon:Weapon  
## 旋转节点：需要旋转的视觉节点（如武器Sprite2D，控制其rotation属性）
@export var rotate_node:Node2D  
## 垂直翻转开关：启用时根据水平方向翻转节点Y轴缩放（保持武器底部朝下）
@export var flip_vertically:bool = true  

# -------------------- 成员变量（运行时状态） --------------------
## 当前翻转状态：1表示正常，-1表示翻转（用于避免重复设置缩放）
var current_flip:int = 1  
## 输入资源：从武器资源节点获取的输入数据（包含瞄准方向等输入信息）
var input_resource:InputResource  


# -------------------- 生命周期方法（资源初始化） --------------------
func _ready()->void:
	if weapon == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponRotation: 武器引用节点（weapon）未配置", LogManager.LogLevel.ERROR)
		return
	if rotate_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponRotation: 旋转节点（rotate_node）未配置", LogManager.LogLevel.ERROR)
		return
	if weapon.resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponRotation: 武器资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# 从武器的资源节点中获取输入资源（假设资源节点名为"input"）
	input_resource = weapon.resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponRotation: 输入资源（input_resource）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 当节点是池化节点（如对象池复用）时，确保子节点完成初始化
	request_ready()  


# -------------------- 每帧更新逻辑（同步输入方向与武器旋转） --------------------
## @brief 根据输入的瞄准方向更新武器的旋转角度和翻转状态
## @param _delta 帧间隔时间（未使用，因输入方向为即时数据）
func _process(_delta:float)->void:
	# 获取输入资源中的瞄准方向（由输入系统提供的标准化向量，如鼠标相对于武器的位置）
	var direction:Vector2 = input_resource.aim_direction
	
	# 计算方向向量的X轴符号（1：向右，-1：向左，0：无水平方向）
	var dir_x:int = sign(direction.x)
	
	# 垂直翻转逻辑：当启用翻转且水平方向变化时调整节点缩放
	if flip_vertically && (dir_x != 0 && dir_x != current_flip):
		current_flip = dir_x  # 更新当前翻转状态
		rotate_node.scale.y = current_flip  # 通过Y轴缩放实现垂直翻转（1保持原样，-1上下翻转）
	
	# 设置旋转节点的角度（根据瞄准方向的弧度角，实现武器指向鼠标位置）
	rotate_node.rotation = direction.angle()
