# 玩家输入管理节点：处理玩家输入（移动、瞄准、射击、切换武器等），并同步输入状态到资源
class_name PlayerInput  # 定义类名，作为场景中的玩家输入控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 输入是否启用（控制物理处理和输入响应）
@export var enabled:bool = true  
## 位置参考节点：用于获取鼠标在该节点的本地坐标（通常为玩家角色节点）
@export var position_node:Node2D  
## 瞄准偏移量：调整鼠标瞄准方向到角色的特定位置（如脚部阴影碰撞体）
@export var aim_offset:Vector2  
## 资源节点：存储输入相关资源（InputResource）
@export var resource_node:ResourceNode  
## 动作资源：定义输入动作名称（如移动、瞄准、射击等）
@export var action_resource:ActionResource  
## 输入死区阈值（可在编辑器调整）
@export var input_deadzone:float = 0.01  


# -------------------- 成员变量（运行时状态） --------------------
## 输入资源：存储当前输入状态（方向、瞄准、动作等）
var input_resource:InputResource  


# -------------------- 状态控制方法（启用/禁用输入处理） --------------------
## @brief 切换输入处理的启用状态，控制物理帧更新
## @param value true 启用输入处理，false 禁用输入处理
func set_enabled(value:bool)->void:
	enabled = value
	set_physics_process(enabled)  # 启用/禁用_physics_process的调用


# -------------------- 生命周期方法（节点初始化与资源获取） --------------------
func _ready()->void:
	if position_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerInput: 位置参考节点（position_node）未配置", LogManager.LogLevel.ERROR)
		return
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerInput: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if action_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerInput: 动作资源（action_resource）未配置", LogManager.LogLevel.ERROR)
		return
	# 从资源节点获取输入资源（必须配置，否则输入无法同步）
	input_resource = resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerInput: 输入资源（input）未配置，输入管理失效", LogManager.LogLevel.ERROR)
		return
	
	# 设置物理处理优先级（确保在移动逻辑之前处理输入）
	process_physics_priority -= 1  # 优先级数值越小越先执行
	
	# 初始化输入处理状态（根据enabled属性启用/禁用）
	set_enabled(enabled)
	
	# 配合对象池使用（标记节点准备完成）
	request_ready()


# -------------------- 输入事件处理（实时响应输入设备事件） --------------------
## @brief 处理输入事件（鼠标移动、方向键按下等）
func _input(event:InputEvent)->void:
	# 处理鼠标移动事件（更新鼠标瞄准标志和方向）
	if event is InputEventMouseMotion:
		if position_node == null || !position_node.is_inside_tree():
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "PlayerInput: 位置参考节点（position_node）未配置或已销毁", LogManager.LogLevel.ERROR)
			return
		
		action_resource.mouse_aim = true  # 标记当前使用鼠标瞄准
		# 获取鼠标在position_node的本地坐标（考虑偏移量）
		var aim_direction:Vector2 = position_node.get_local_mouse_position() + aim_offset
		# 标准化方向并更新到输入资源
		input_resource.set_aim_direction(aim_direction.normalized())
		return  # 处理完鼠标移动后跳出
		
	# 处理非鼠标瞄准输入（方向键/手柄），标记为非鼠标瞄准
	# 左瞄准键（如键盘A或手柄左摇杆左）
	if event.is_action(action_resource.aim_left_action):
		action_resource.mouse_aim = false
		return
	# 右瞄准键（如键盘D或手柄左摇杆右）
	if event.is_action(action_resource.aim_right_action):
		action_resource.mouse_aim = false
		return
	# 上瞄准键（如键盘W或手柄左摇杆上）
	if event.is_action(action_resource.aim_up_action):
		# 忽略手柄摇杆死区（值过小视为未操作）
		if event is InputEventJoypadMotion && abs(event.axis_value) < action_resource.aim_deadzone:
			return
		action_resource.mouse_aim = false
		return
	# 下瞄准键（如键盘S或手柄左摇杆下）
	if event.is_action(action_resource.aim_down_action):
		if event is InputEventJoypadMotion && abs(event.axis_value) < action_resource.aim_deadzone:
			return
		action_resource.mouse_aim = false
		return


# -------------------- 物理帧更新（同步输入状态到资源） --------------------
## @brief 每物理帧更新输入状态（移动方向、瞄准、射击等）
func _physics_process(_delta:float)->void:
	# ------------ 移动方向处理 ------------
	# 获取水平/垂直移动轴值（基于ActionResource定义的动作名称）
	var _axis:Vector2 = Vector2(
		Input.get_axis(action_resource.left_action, action_resource.right_action),  # 左右移动轴
		Input.get_axis(action_resource.up_action, action_resource.down_action)       # 上下移动轴
	)
	
	# 标准化方向向量（长度大于0.01时视为有效输入）
	var _length:float = _axis.length()
	if _length > input_deadzone:
		_axis = _axis.normalized()
	
	# 更新输入资源中的移动方向
	input_resource.set_axis(_axis)
	
	# ------------ 瞄准方向处理（非鼠标模式） ------------
	if !action_resource.mouse_aim:  # 当前使用方向键/手柄瞄准
		# 获取瞄准轴值（基于ActionResource定义的瞄准动作名称）
		var _aim:Vector2 = Vector2(
			Input.get_axis(action_resource.aim_left_action, action_resource.aim_right_action),  # 左右瞄准轴
			Input.get_axis(action_resource.aim_up_action, action_resource.aim_down_action)       # 上下瞄准轴
		)
		# 长度大于0.01时更新瞄准方向
		if _aim.length() > 0.01:
			input_resource.set_aim_direction(_aim.normalized())
	
	# ------------ 射击动作处理 ------------
	# 检测射击动作是否按下（如鼠标左键或键盘J键）
	input_resource.set_action(Input.is_action_pressed(action_resource.action_1_action))
	
	# ------------ 武器切换处理 ------------
	# 计算武器切换方向（上一个/下一个武器）
	# 上一个武器键释放（如Q键）
	var weapon_switch_dir:int = int(Input.is_action_just_released(action_resource.previous_action)) - int(Input.is_action_just_released(action_resource.next_action))  # 下一个武器键释放（如E键）
	if weapon_switch_dir != 0:
		input_resource.set_switch_weapon(weapon_switch_dir)  # 更新武器切换方向
	
	# ------------ 冲刺动作处理 ------------
	# 检测冲刺动作是否按下（如Shift键或手柄Y键）
	input_resource.set_action_2(Input.is_action_pressed(action_resource.action_2_action))
