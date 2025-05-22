class_name BindingMenu
extends ColorRect

# 导出的绑定按钮列表（需在编辑器中配置）
@export var button_list: Array[BindingButton]

# 选择按钮组的父容器（用于切换可见性）
@export var choice_button_group: Control

# 显示输入监听提示信息的标签
@export var info_label: Label

# 多个功能按钮的引用
@export var focus_button: Button
@export var new_button: Button
@export var delete_button: Button
@export var cancel_button: Button
@export var back_button: Button
@export var reset_button: Button

# 当前操作的绑定按钮
var current_button: BindingButton

# 选择类型枚举
enum ChoiceType {NEW, DELETE, CANCEL}

func _ready() -> void:
	# 初始隐藏界面并禁用输入处理
	visible = false
	set_process_input(false)
	
	# 连接选择按钮信号
	new_button.pressed.connect(_on_choice.bind(ChoiceType.NEW))
	delete_button.pressed.connect(_on_choice.bind(ChoiceType.DELETE))
	cancel_button.pressed.connect(_on_choice.bind(ChoiceType.CANCEL))
	
	# 绑定所有按钮的按下信号
	for _button: BindingButton in button_list:
		_button.pressed.connect(_on_button.bind(_button))

# 绑定按钮按下回调
func _on_button(button: BindingButton) -> void:
	if not is_instance_valid(button):
		Log.entry("无效的按钮实例", LogManager.LogLevel.ERROR)
		return
	current_button = button
	_open()
	if new_button:
		new_button.grab_focus.call_deferred() # 延迟获取焦点

# 处理用户选择
func _on_choice(choice: ChoiceType) -> void:
	match choice:
		ChoiceType.CANCEL:
			_close()
			current_button.grab_focus.call_deferred()
		ChoiceType.DELETE:
			_close()
			current_button.change_binding(null)  # 清除绑定
			current_button.grab_focus.call_deferred()
		ChoiceType.NEW:
			info_label.visible = true
			choice_button_group.visible = false
			set_process_input(true)  # 开始监听输入

# 打开菜单界面
func _open() -> void:
	visible = true
	choice_button_group.visible = true
	info_label.visible = false
	# 禁用非活动按钮焦点
	back_button.focus_mode = Control.FOCUS_NONE
	reset_button.focus_mode = Control.FOCUS_NONE
	for _button: BindingButton in button_list:
		_button.focus_mode = Control.FOCUS_NONE

# 关闭菜单界面
func _close() -> void:
	set_process_input(false)
	visible = false
	choice_button_group.visible = true
	info_label.visible = false
	# 恢复按钮焦点
	back_button.focus_mode = Control.FOCUS_ALL
	reset_button.focus_mode = Control.FOCUS_ALL
	for _button: BindingButton in button_list:
		_button.focus_mode = Control.FOCUS_ALL

# 输入事件处理（绑定新按键时）
func _input(event: InputEvent) -> void:
	if !event.is_released():  # 仅处理释放事件
		return
	
	# 根据按钮类型处理输入
	match current_button.type:
		BindingButton.EventType.KEYBOARD:
			if event is InputEventKey or event is InputEventMouseButton:
				_handle_input_event(event)
		BindingButton.EventType.GAMEPAD:
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				_handle_input_event(event)

# 处理有效输入事件（内部方法）
func _handle_input_event(event: InputEvent) -> void:
	current_button.change_binding.call_deferred(event)
	_close()
	current_button.grab_focus.call_deferred()
