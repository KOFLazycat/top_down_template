# 角色状态机：管理角色动画状态（空闲、行走）并根据输入切换
class_name CharacterStates  # 定义类名，可在场景中作为角色状态管理节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 状态机是否启用（控制_process回调执行）
@export var enabled:bool = true  
## 资源节点（存储输入资源）
@export var resource_node:ResourceNode  
## 动画播放器（控制角色动画播放）
@export var animation_player:AnimationPlayer  
## 角色状态枚举（NONE：未初始化/空状态，IDLE：空闲，WALK：行走）
enum State {NONE, IDLE, WALK}  
## 当前状态（默认：NONE，需在_ready中初始化）
@export var state:State = State.NONE  
## 输入死区阈值（可在编辑器调整）
@export var dead_zone:float = 0.1  


# -------------------- 常量与成员变量（运行时状态） --------------------
## 状态与动画名称映射数组（索引对应State枚举值）
## [State.NONE: "idle", State.IDLE: "idle", State.WALK: "walk"]
const animation_list:Array[StringName] = ["idle", "idle", "walk"]  
## 输入资源实例（获取玩家输入轴）
var input_resource:InputResource  


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CharacterStates: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# 从资源节点获取输入资源（确保非空）
	input_resource = resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "CharacterStates: 输入资源（input）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 初始化状态机启用状态
	set_enabled(enabled)
	
	# 保存初始状态并强制更新（确保状态切换逻辑触发）
	var init_state:State = state  # 修正语法错误：移除多余的冒号
	state = State.NONE       # 设置临时状态以触发_set_state
	_set_state(init_state)   # 应用初始状态（确保动画正确播放）
	
	# 确保节点准备完成（配合对象池使用）
	request_ready()


# -------------------- 状态控制方法（启用/禁用状态机） --------------------
## @brief 切换状态机启用状态（控制_process是否执行）
func set_enabled(value:bool)->void:
	enabled = value
	set_process(enabled)  # 根据enabled状态设置帧回调执行
	#print("CharacterStates [INFO]: 状态机已%s" % ("启用" if value else "禁用"))


# -------------------- 核心逻辑：设置角色状态并播放动画 --------------------
## @brief 切换角色状态并播放对应动画（忽略相同状态请求）
## @param value 目标状态（State枚举值）
func _set_state(value:State)->void:
	if state == value:  # 状态未变更时直接返回
		return
	
	state = value  # 更新当前状态
	
	# 根据状态获取动画名称（使用枚举值作为数组索引）
	var animation:StringName = animation_list[state]
	animation_player.play(animation)  # 播放目标动画
	
	#print("CharacterStates [INFO]: 切换至状态：%s（动画：%s）" % (state, animation))


# -------------------- 帧更新（输入检测与状态切换） --------------------
## @brief 根据输入轴判断当前状态（行走/空闲）
func _process(_delta:float)->void:
	# 计算输入轴长度平方（避免浮点精度问题）
	var input_magnitude_sq:float = input_resource.axis.length_squared()
	
	# 输入轴长度超过阈值时切换为行走状态，否则切换为空闲状态
	if input_magnitude_sq > dead_zone * dead_zone:  # 输入死区（避免轻微抖动触发状态切换）
		_set_state(State.WALK)
	else:
		_set_state(State.IDLE)
