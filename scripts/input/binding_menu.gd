# 输入绑定菜单：管理输入绑定的可视化操作（选择/新建/删除绑定）
class_name BindingMenu  # 定义类名，可在场景中作为界面节点使用
extends ColorRect  # 继承带颜色背景的矩形节点（用于界面背景）


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 绑定按钮列表（需在编辑器中拖入所有 `BindingButton` 实例）
@export var button_list: Array[BindingButton]

## 选择按钮组容器（包含 "新建"/"删除"/"取消" 按钮）
@export var choice_button_group: Control

## 输入监听提示标签（显示 "请按下新按键..." 等提示）
@export var info_label: Label

## 功能按钮引用（用于焦点管理和交互）
@export var focus_button: Button  # 焦点控制按钮（可能用于初始焦点）
@export var new_button: Button     # 新建绑定按钮
@export var delete_button: Button  # 删除绑定按钮
@export var cancel_button: Button  # 取消操作按钮
@export var back_button: Button    # 返回上级菜单按钮
@export var reset_button: Button   # 重置绑定按钮


# -------------------- 成员变量（运行时状态） --------------------

## 当前操作的绑定按钮（记录用户选择的待配置按钮）
var current_button: BindingButton

## 选择类型枚举（定义用户操作类型）
enum ChoiceType {NEW, DELETE, CANCEL}  # 新建/删除/取消


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready() -> void:
	# 初始隐藏菜单并禁用输入处理（避免未激活时响应输入）
	visible = false
	set_process_input(false)
	
	# 连接选择按钮的点击信号到 `_on_choice` 回调（传递操作类型）
	new_button.pressed.connect(_on_choice.bind(ChoiceType.NEW))
	delete_button.pressed.connect(_on_choice.bind(ChoiceType.DELETE))
	cancel_button.pressed.connect(_on_choice.bind(ChoiceType.CANCEL))
	
	# 遍历所有绑定按钮，连接其点击信号到 `_on_button` 回调（传递按钮实例）
	for _button: BindingButton in button_list:
		if not _button:
			Log.entry("绑定按钮列表中存在空值，可能导致功能异常", LogManager.LogLevel.ERROR)
			continue
		_button.pressed.connect(_on_button.bind(_button))
	
	if !new_button || !delete_button || !cancel_button:
		Log.entry("选择按钮未配置，菜单功能将失效", LogManager.LogLevel.ERROR)


# -------------------- 绑定按钮点击回调（选择待配置的按钮） --------------------
func _on_button(button: BindingButton) -> void:
	# 校验按钮实例有效性（避免空引用）
	if not is_instance_valid(button):
		Log.entry("无效的按钮实例", LogManager.LogLevel.ERROR)  # 输出错误日志（假设 Log 为自定义日志工具）
		return
	
	# 记录当前操作的绑定按钮
	current_button = button
	
	# 打开菜单界面（显示并配置交互状态）
	_open()
	
	# 延迟让 "新建" 按钮获取焦点（避免立即触发输入监听）
	if new_button:
		new_button.grab_focus.call_deferred()


# -------------------- 用户选择操作回调（处理新建/删除/取消） --------------------
func _on_choice(choice: ChoiceType) -> void:
	match choice:
		ChoiceType.CANCEL:  # 取消操作
			_close()  # 关闭菜单
			current_button.grab_focus.call_deferred()  # 焦点回到当前绑定按钮
		ChoiceType.DELETE:  # 删除绑定
			_close()  # 关闭菜单
			current_button.change_binding(null)  # 调用绑定按钮的清除绑定方法
			current_button.grab_focus.call_deferred()  # 焦点回到当前绑定按钮
		ChoiceType.NEW:  # 新建绑定（进入输入监听状态）
			info_label.visible = true  # 显示输入提示标签（如 "请按下新按键..."）
			choice_button_group.visible = false  # 隐藏选择按钮组（避免干扰输入）
			set_process_input(true)  # 启用输入处理（开始监听用户输入）


# -------------------- 打开菜单界面（配置交互状态） --------------------
func _open() -> void:
	visible = true  # 显示菜单
	choice_button_group.visible = true  # 显示选择按钮组
	info_label.visible = false  # 隐藏输入提示标签（未进入新建状态时）
	
	# 禁用非活动按钮的焦点（防止误操作其他按钮）
	back_button.focus_mode = Control.FOCUS_NONE  # 禁用返回按钮焦点
	reset_button.focus_mode = Control.FOCUS_NONE  # 禁用重置按钮焦点
	for _button: BindingButton in button_list:
		_button.focus_mode = Control.FOCUS_NONE  # 禁用其他绑定按钮焦点


# -------------------- 关闭菜单界面（恢复交互状态） --------------------
func _close() -> void:
	set_process_input(false)  # 禁用输入处理（停止监听输入）
	visible = false  # 隐藏菜单
	choice_button_group.visible = true  # 恢复选择按钮组可见性
	info_label.visible = false  # 隐藏输入提示标签
	
	# 恢复按钮焦点（允许用户操作其他按钮）
	back_button.focus_mode = Control.FOCUS_ALL  # 启用返回按钮焦点
	reset_button.focus_mode = Control.FOCUS_ALL  # 启用重置按钮焦点
	for _button: BindingButton in button_list:
		_button.focus_mode = Control.FOCUS_ALL  # 启用其他绑定按钮焦点


# -------------------- 输入事件处理（新建绑定时监听输入） --------------------
func _input(event: InputEvent) -> void:
	if !event.is_released():  # 仅处理按键/按钮释放事件（避免重复触发）
		return
	
	# 根据当前绑定按钮的类型（键盘/手柄）过滤输入事件
	match current_button.type:
		BindingButton.EventType.KEYBOARD:  # 键盘类型
			# 仅响应键盘按键或鼠标按钮事件（如键盘按键、鼠标左右键）
			if event is InputEventKey or event is InputEventMouseButton:
				_handle_input_event(event)  # 处理有效输入事件
		BindingButton.EventType.GAMEPAD:  # 手柄类型
			# 仅响应手柄按钮或手柄轴运动事件（如手柄按键、摇杆移动）
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				_handle_input_event(event)  # 处理有效输入事件


# -------------------- 处理有效输入事件（设置新绑定） --------------------
func _handle_input_event(event: InputEvent) -> void:
	# 延迟调用绑定按钮的 `change_binding` 方法（避免当前帧事件干扰）
	current_button.change_binding.call_deferred(event)
	_close()  # 关闭菜单
	current_button.grab_focus.call_deferred()  # 焦点回到当前绑定按钮


func _exit_tree() -> void:
	# 断开选择按钮的点击信号
	new_button.pressed.disconnect(_on_choice.bind(ChoiceType.NEW))
	delete_button.pressed.disconnect(_on_choice.bind(ChoiceType.DELETE))
	cancel_button.pressed.disconnect(_on_choice.bind(ChoiceType.CANCEL))
	# 断开绑定按钮的点击信号
	for _button in button_list:
		_button.pressed.disconnect(_on_button.bind(_button))
