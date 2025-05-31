class_name GraphicsManager
extends Node

# 图形配置资源（需实现 GraphicsResource 类）
@export var graphics_resource: GraphicsResource:
	set(value):
		if not value is GraphicsResource:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "GraphicsManager: 必须设置 GraphicsResource 类型", LogManager.LogLevel.ERROR)
			return
		graphics_resource = value

# 全屏切换按钮引用
@export var fullscreen_button: Button

# 全屏状态显示标签
@export var fullscreen_label: Label

# 设置保存按钮引用（变量名不规范）
@export var save_button: Button  # 应重命名为 save_button

# 添加国际化支持
const LOCALIZATION_KEYS := {
	"fullscreen_on": "FULLSCREEN_ON",
	"fullscreen_off": "FULLSCREEN_OFF"
}

func _ready() -> void:
	if not graphics_resource:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "GraphicsManager: 未配置 GraphicsResource", LogManager.LogLevel.ERROR)
		return
	# 初始化文案
	fullscreen_label.text = LOCALIZATION_KEYS["fullscreen_on"]
	
	# 连接全屏按钮信号
	fullscreen_button.pressed.connect(toggle_fullscreen)
	
	# 连接保存按钮信号（按钮命名冗余）
	save_button.pressed.connect(save_settings)
	
	# 启用窗口尺寸变化追踪
	graphics_resource.enable_resize_tracking(get_viewport())
	
	# 连接窗口模式变更信号
	graphics_resource.window_mode_changed.connect(update_label)

# 切换全屏状态
func toggle_fullscreen() -> void:
	graphics_resource.toggle_fullscreen()

# 更新全屏状态标签
func update_label() -> void:
	if graphics_resource.is_fullscreen():
		fullscreen_label.text = LOCALIZATION_KEYS["fullscreen_on"]
	else:
		fullscreen_label.text = LOCALIZATION_KEYS["fullscreen_off"]

# 保存图形设置
func save_settings() -> void:
	graphics_resource.save_resource()  # 无错误处理
