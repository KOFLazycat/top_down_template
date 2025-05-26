# 输入绑定按钮：根据输入事件类型动态显示对应控制图标（键盘/游戏手柄）
class_name BindingButton  # 定义类名，可在场景中作为按钮类型使用
extends TextureButton  # 继承自带纹理的按钮类


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 按钮标签（显示输入事件文本，如 "A" 或 "X"）
@export var label:Label

## 键盘控制纹理资源（存储键盘按键的纹理）
@export var control_texture_kb:ControlTextureResource

## Xbox 手柄控制纹理资源
@export var control_texture_xbox:ControlTextureResource

## PS 手柄控制纹理资源
@export var control_texture_ps:ControlTextureResource

## Switch 手柄控制纹理资源
@export var control_texture_switch:ControlTextureResource

## 通用手柄控制纹理资源（未识别设备时使用）
@export var control_texture_generic:ControlTextureResource

## 动作资源（存储输入动作映射，需暴露 `get`/`set`/`updated` 接口）
@export var action_resource:ActionResource

## 动作名称（如 "jump"，对应动作资源中的键名）
@export var action_name:StringName

## 动作资源中需操作的事件变量名（如 "keyboard_event"）
@export var event_variable:StringName

## 无输入事件时的默认纹理（如占位图标）
@export var default_texture:Texture

## 输入类型枚举（区分键盘或游戏手柄输入）
enum EventType {KEYBOARD, GAMEPAD}
@export var type:EventType  # 导出为编辑器可配置的枚举值


# -------------------- 成员变量（运行时状态） --------------------

## 保存当前输入事件（用于比较是否需要更新纹理）
var current_event:InputEvent


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	# 初始化各控制纹理资源（假设 initialize() 加载纹理）
	control_texture_kb.initialize()
	control_texture_xbox.initialize()
	control_texture_ps.initialize()
	control_texture_switch.initialize()
	control_texture_generic.initialize()

	# 连接焦点变化信号：焦点进入/退出时触发重绘
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))

	# 初始化时设置当前输入事件（从动作资源中获取）
	_set_event(action_resource.get(event_variable) as InputEvent)

	# 监听动作资源更新信号：输入绑定变更时更新显示
	action_resource.updated.connect(_on_action_resource_update)


# -------------------- 动作资源更新回调（输入绑定变更时触发） --------------------
func _on_action_resource_update()->void:
	# 获取动作资源中当前事件变量的值
	var _current_event:InputEvent = action_resource.get(event_variable)
	# 若事件未变更，直接返回
	if _current_event == current_event:
		return
	# 更新输入事件并刷新显示
	_set_event(_current_event)


# -------------------- 设置输入事件并更新纹理 --------------------
func _set_event(event:InputEvent)->void:
	current_event = event  # 保存当前事件以便后续比较

	if event == null:
		# 事件为空时显示默认纹理或 "EMPTY"
		_set_empty()
		return

	var _texture:Texture
	if type == EventType.KEYBOARD:
		# 键盘输入：从键盘纹理资源获取对应按键纹理
		_texture = control_texture_kb.get_texture(event)
	else:
		# 手柄输入：根据设备类型获取对应的手柄纹理资源
		var _control_texture:ControlTextureResource = _get_gamepad_control_texture(event)
		_texture = _control_texture.get_texture(event)

	if _texture == null:
		# 无匹配纹理时回退到标签显示事件文本
		_label_fallback(event)
		return

	# 设置按钮的正常状态纹理
	texture_normal = _texture


# -------------------- 获取手柄控制纹理资源（根据设备名称） --------------------
func _get_gamepad_control_texture(event:InputEvent)->ControlTextureResource:
	# 获取输入事件对应的手柄设备名称（如 "Xbox Series Controller"）
	var _device_name:String = Input.get_joy_name(event.device)
	
	# 根据设备名称匹配手柄类型（当前仅处理常见设备，可扩展）
	match _device_name:
		"XInput Gamepad", "Xbox Series Controller", "Xbox 360 Controller", "Xbox Wireless Controller", \
		"Xbox One Controller":
			return control_texture_xbox  # 返回 Xbox 纹理资源
		"Sony DualSense", "PS5 Controller", "PS4 Controller", \
		"Nacon Revolution Unlimited Pro Controller":
			return control_texture_ps    # 返回 PS 纹理资源
		"Switch", "Joy-Con (L)", "Joy-Con (R)":
			return control_texture_switch # 返回 Switch 纹理资源
		_:  # 其他设备使用通用纹理
			return control_texture_generic


# -------------------- 处理空事件（无输入绑定时的显示） --------------------
func _set_empty()->void:
	if default_texture != null:
		texture_normal = default_texture  # 使用默认纹理
		label.text = ""  # 清空标签文本
	else:
		texture_normal = null  # 无纹理时设为 null
		label.text = "EMPTY"   # 显示 "EMPTY" 提示


# -------------------- 纹理缺失时的回退处理（显示事件文本） --------------------
func _label_fallback(event:InputEvent)->void:
	texture_normal = null  # 清空纹理
	# 打印日志：提示当前输入事件文本（调试用）
	print("BindingButton [INFO]: ", event.as_text())
	# 提取事件文本的第一个单词（如 "Joypad Button 0" 提取为 "Joypad"）
	label.text = event.as_text().split(" ")[0]


# -------------------- 焦点变化回调（更新按钮视觉反馈） --------------------
func _on_focus_changed(_value:bool)->void:
	queue_redraw()  # 触发 _draw() 重绘焦点边框


# -------------------- 自定义绘制（焦点状态下绘制边框） --------------------
func _draw() -> void:
	if !has_focus():  # 无焦点时不绘制
		return
	# 绘制白色外边框
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 1.0)
	# 绘制黑色内边框（形成描边效果）
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), Color.BLACK, false, 1.0)


# -------------------- 修改输入绑定（外部调用接口） --------------------
func change_binding(event:InputEvent)->void:
	# 移除原有输入绑定（避免冲突）
	var _current_event:InputEvent = action_resource.get(event_variable)
	if _current_event != null:
		action_resource.erase_input(action_name, _current_event)
	
	# 设置新输入绑定
	action_resource.set(event_variable, event)
	
	if event == null:
		_set_event(event)  # 空事件时更新显示
		return
	# 触发动作资源更新信号（自动更新视觉）
	action_resource.set_input(action_name, event)
