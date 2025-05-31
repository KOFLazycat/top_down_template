# 冲刺能力节点：实现角色冲刺效果，包含冷却时间、残影生成和冲量应用
class_name DashAbility  # 定义类名，可在场景中作为冲刺能力控制节点
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 能力是否启用（控制输入响应和逻辑执行）
@export var enabled:bool = true  
## 资源节点（存储冲刺相关资源，如推力、状态布尔值）
@export var resource_node:ResourceNode  
## 冲刺冲量强度（决定冲刺速度和距离）
@export var impulse_strength:float = 88.0  
## 冷却时间（秒）：冲刺后无法立即再次使用的间隔
@export var cooldown_time:float = 0.8  
## 激活时间（秒）：冲刺状态持续时间（如无敌或穿地形状态）
@export var active_time:float = 0.48  
## 残影实例资源：冲刺时生成的残影视觉效果预制体
@export var after_image_instance:InstanceResource  
## 角色精灵节点：用于获取精灵属性生成残影
@export var sprite:Sprite2D
# 输入死区阈值（可在编辑器调整）
@export var input_dead_zone:float = 0.1  

# -------------------- 成员变量（运行时状态） --------------------
## 冷却状态标记：true表示当前处于冷却中，无法触发冲刺
var is_cooldown:bool = false  
## 冲刺状态布尔资源：用于同步冲刺状态（如无敌标记）
var dash_bool:BoolResource  
## 推力资源：用于施加冲刺冲量（通常关联物理节点）
var push_resource:PushResource  
## 输入资源：获取冲刺触发输入（如按键或手柄按钮）
var input_resource:InputResource  


# -------------------- 生命周期方法（节点初始化与资源获取） --------------------
func _ready()->void:
	# 获取推力资源（确保非空，否则冲刺无法施加冲量）
	push_resource = resource_node.get_resource("push")
	if push_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DashAbility: 推力资源（push）未配置，冲刺能力失效", LogManager.LogLevel.ERROR)
		return
	# 获取冲刺状态布尔资源（用于同步状态，如无敌）
	dash_bool = resource_node.get_resource("dash")
	if dash_bool == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DashAbility: 冲刺状态资源（dash）未配置，状态同步失效", LogManager.LogLevel.ERROR)
		return
	
	# 获取输入资源（确保非空，否则无法接收冲刺输入）
	input_resource = resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "DashAbility: 输入资源（input）未配置，无法触发冲刺", LogManager.LogLevel.ERROR)
		return
	
	# 初始化能力启用状态（连接或断开输入信号）
	set_enabled(enabled)
	
	# 配合对象池使用（标记节点准备完成）
	request_ready()


# -------------------- 状态控制方法（启用/禁用冲刺能力） --------------------
## @brief 切换冲刺能力的启用状态，管理输入信号连接
## @param value true 启用能力，false 禁用能力
func set_enabled(value:bool)->void:
	enabled = value
	if enabled:
		# 启用时连接输入信号（冲刺触发按键）
		if !input_resource.action_2_pressed.is_connected(_dash_pressed):
			input_resource.action_2_pressed.connect(_dash_pressed)
	else:
		# 禁用时断开输入信号
		if input_resource.action_2_pressed.is_connected(_dash_pressed):
			input_resource.action_2_pressed.disconnect(_dash_pressed)


# -------------------- 核心逻辑：冲刺触发处理 --------------------
## @brief 处理冲刺按键按下事件，执行冲刺逻辑
func _dash_pressed()->void:
	if is_cooldown:
		return  # 处于冷却中，跳过
	
	# 检查输入轴是否有效（避免在静止时触发冲刺）
	if input_resource.axis.length_squared() < input_dead_zone:
		return
	
	# 施加冲刺冲量（方向为输入轴方向，强度由impulse_strength控制）
	push_resource.add_impulse(input_resource.axis * impulse_strength)
	
	# 进入冷却状态
	is_cooldown = true
	
	# 创建冷却时间补间（延迟后重置冷却状态）
	var _tween:Tween = create_tween()
	_tween.tween_callback(_cooldown_over).set_delay(cooldown_time)
	
	# 激活冲刺状态（如无敌）并设置持续时间
	dash_bool.set_value(true)
	var _tween2:Tween = create_tween()
	_tween2.tween_callback(dash_bool.set_value.bind(false)).set_delay(active_time)
	
	# 创建残影生成补间（循环3次，每次间隔0.1秒）
	var _tween3:Tween = create_tween().set_loops(3)
	_tween3.tween_callback(_spawn_after_image).set_delay(0.1)
	_spawn_after_image()  # 立即生成第一帧残影（补间循环会自动触发后续生成）


# -------------------- 冷却结束回调 --------------------
## @brief 冷却时间结束后重置状态，允许再次触发冲刺
func _cooldown_over()->void:
	is_cooldown = false
	# 若输入仍按住，自动再次触发冲刺（需注意防抖，可能非预期行为）
	if input_resource.action_2:
		_dash_pressed()


# -------------------- 辅助方法：生成冲刺残影 --------------------
## @brief 实例化残影效果并传递精灵参数
func _spawn_after_image()->void:
	var _config_callback:Callable = func (inst:AfterImageVFX)->void:
		# 传递精灵当前状态到残影效果（纹理、帧信息、位置等）
		inst.setup(
			sprite.texture,         # 精灵纹理
			sprite.hframes,         # 水平帧数量
			sprite.vframes,         # 垂直帧数量
			sprite.frame,           # 当前帧索引
			sprite.centered,        # 是否居中
			sprite.offset,          # 偏移量
			sprite.position,        # 本地位置
			owner.global_position   # 世界位置
		)
	# 实例化残影预制体并应用配置回调
	after_image_instance.instance(_config_callback)
