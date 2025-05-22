class_name ButtonAnimator
extends Node

# 导出的按钮节点引用（需在编辑器中拖拽赋值）
@export var button: Button

# 关联的文本标签节点（用于文字动画）
@export var label: Label

# 按钮按下时的音效资源
@export var pressed_sound: SoundResource

# 默认着色器参数配置（未实际使用）
var default_shader_parameters: = {
	scale = 1.0,
	rotation = 0.0,
	skew = Vector2.ZERO,
}

# 动画样式框引用（核心动画资源）
var style_box: AnimatedStyleBoxFlat

# 存储按钮各状态样式资源的字典（normal/pressed/hover等）
var style_dictionary: Dictionary = {}

# 存储样式属性补间动画的字典
var tweens_style: Dictionary = {}

# 存储着色器属性补间动画的字典
var tweens_shader: Dictionary = {}

# 按钮状态跟踪变量
var is_down: bool
var is_hover: bool
var is_focused: bool
var should_focus: bool

# 按钮的材质实例引用
var material: ShaderMaterial

func _ready() -> void:
	setup_style()  # 初始化样式系统
	
	# 连接按钮信号
	button.button_down.connect(set_is_down.bind(true))
	button.button_up.connect(set_is_down.bind(false))
	button.mouse_entered.connect(set_is_hover.bind(true))
	button.mouse_exited.connect(set_is_hover.bind(false))
	button.focus_entered.connect(set_is_focused.bind(true))
	button.focus_exited.connect(set_is_focused.bind(false))
	button.visibility_changed.connect(visibility_changed)
	
	# 复制按钮材质以避免共享实例
	if button.material != null:
		material = button.material.duplicate()
		button.material = material

# 初始化按钮各状态样式（核心方法）
func setup_style() -> void:
	collect_style("normal")  # 收集默认状态样式
	collect_style("pressed") # 按下状态
	collect_style("hover")   # 悬停状态
	collect_style("focus")   # 聚焦状态
	collect_style("disabled")# 禁用状态
	
	# 复制默认样式作为动画基础
	style_box = style_dictionary["normal"].duplicate()
	# 复制标签设置
	label.label_settings = style_box.label_settings.duplicate()
	# 覆盖所有状态样式为统一动画样式
	button.add_theme_stylebox_override("normal", style_box)
	button.add_theme_stylebox_override("pressed", style_box)
	button.add_theme_stylebox_override("hover", style_box)
	button.add_theme_stylebox_override("focus", style_box)
	button.add_theme_stylebox_override("disabled", style_box)

# 收集指定状态的样式资源
func collect_style(state_name: String) -> void:
	var current_style: StyleBox = button.get_theme_stylebox(state_name)
	
	# 断言验证样式有效性
	assert(current_style != null, "按钮状态%s未分配样式" % state_name)
	assert(current_style is AnimatedStyleBoxFlat, "%s状态样式类型错误" % state_name)
	
	# 存储复制的样式实例
	style_dictionary[state_name] = current_style.duplicate()

# 处理按下状态变化
func set_is_down(value: bool) -> void:
	is_down = value
	if is_down:
		set_style_tween(style_dictionary["pressed"])  # 播放按下动画
		if pressed_sound != null:
			pressed_sound.play_managed()  # 播放音效
	elif is_focused:
		set_style_tween(style_dictionary["focus"])    # 聚焦状态
	elif is_hover:
		set_style_tween(style_dictionary["hover"])    # 悬停状态
	else:
		set_style_tween(style_dictionary["normal"])   # 默认状态

# 处理悬停状态变化（逻辑与聚焦状态互斥）
func set_is_hover(value: bool) -> void:
	is_hover = value
	if is_focused: return  # 优先处理聚焦状态
	set_style_tween(style_dictionary["hover" if is_hover else "normal"])

# 处理聚焦状态变化
func set_is_focused(value: bool) -> void:
	is_focused = value
	if is_focused:
		set_style_tween(style_dictionary["focus"])
	elif is_hover:
		set_style_tween(style_dictionary["hover"])
	else:
		set_style_tween(style_dictionary["normal"])
	# 处理不可见时的焦点延迟获取
	if !button.is_visible_in_tree():
		should_focus = true

# 可见性变化回调
func visibility_changed() -> void:
	if !button.visible: return
	if should_focus:
		button.grab_focus()  # 延迟获取焦点
		should_focus = false

# 核心动画方法：创建属性补间动画
func set_style_tween(animated_style: AnimatedStyleBoxFlat) -> void:
	if is_queued_for_deletion() || !is_inside_tree():
		return  # 防止无效状态调用
	
	# 处理样式框属性动画
	for property in animated_style.tween_list:
		# 管理补间实例
		if !tweens_style.has(property):
			tweens_style[property] = null
		
		var _tween: Tween = tweens_style[property]
		if _tween != null:
			_tween.kill()  # 终止旧动画
		
		_tween = create_tween()
		tweens_style[property] = _tween
		_tween.tween_property(style_box, NodePath(property), 
			animated_style.get(property), 
			animated_style.tween_time
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 处理标签属性动画
	for property in animated_style.label_tween_list:
		if !tweens_style.has(property):
			tweens_style[property] = null
		
		var _tween: Tween = tweens_style[property]
		if _tween != null:
			_tween.kill()
		
		_tween = create_tween()
		tweens_style[property] = _tween
		_tween.tween_property(label.label_settings, NodePath(property),
			animated_style.label_settings.get(property),
			animated_style.tween_time
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# 着色器参数动画方法（当前未完成）
func set_shader_tween(_animated_style: AnimatedStyleBoxFlat, parameter_list: Array[StringName]) -> void:
	material.set_shader_parameter("size", button.size)  # 更新尺寸参数
	for parameter in parameter_list:
		if !tweens_shader.has(parameter):
			tweens_shader[parameter] = null
		
		var _tween: Tween = tweens_shader[parameter]
		if _tween != null:
			_tween.kill()
		
		_tween = create_tween()
		tweens_shader[parameter] = _tween
		# 当前仅设置默认值，未实现补间动画
		material.set_shader_parameter(parameter, default_shader_parameters[parameter])
