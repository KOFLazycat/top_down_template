class_name AudioManager
extends Node

## 存储音频总线滑动条的容器数组（容器节点名称应对应音频总线名称）
@export var slider_container: Array[Node]

## 音频设置资源配置（需实现 AudioSettingsResource 类）
@export var audio_settings_resource: AudioSettingsResource

## 保存按钮引用
@export var save_button: Button

func _ready() -> void:
	# 连接保存按钮信号
	save_button.pressed.connect(save)
	
	# 初始化滑块位置
	update_sliders()
	
	# 遍历所有滑块容器
	for node in slider_container:
		var _bus_name: String = node.name  # 总线名称取自容器节点名
		#var _slider: Slider = node.get_node("Slider")  # 获取子节点Slider
		var _slider := node.get_node_or_null("Slider") as Slider
		if not _slider:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "AudioManager: Slider not found in container: %s" % node.name, LogManager.LogLevel.ERROR)
			continue
		
		# 连接滑块值变化信号（注意这里实际连接的是 value_changed）
		_slider.value_changed.connect(on_drag_end.bind(_bus_name, _slider))

## 更新所有滑块到当前音频设置
func update_sliders() -> void:
	for node in slider_container:
		var _bus_name: String = node.name
		var _slider: Slider = node.get_node("Slider")  # 硬编码获取Slider
		_slider.value = audio_settings_resource.get_bus_volume(_bus_name)

## 滑块拖动结束回调
func on_drag_end(_new_value: float, _bus_name: String, slider: Slider) -> void:
	audio_settings_resource.set_bus_volume(_bus_name, slider.value)

## 滑块值变化回调（未实际使用）
func on_value_changed(value: float, _bus_name: String, slider: Slider) -> void:
	audio_settings_resource.set_bus_volume(_bus_name, slider.value)

## 保存音频设置
func save() -> void:
	if not audio_settings_resource:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "AudioManager: AudioSettingsResource not assigned!", LogManager.LogLevel.ERROR)
		return
	audio_settings_resource.save_resource()
