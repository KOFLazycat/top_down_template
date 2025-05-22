class_name MenuTraverseManager
extends Node

## 菜单层级结构（字典类型）
## 键：目录路径（字符串），值：目标节点的 NodePath
## 示例：{"Main/Menu": ^"MainMenu", "Main/Settings": ^"SettingsPanel"}
@export var menu_path:  Dictionary[String, NodePath]

## 目录节点存储键（默认保留字段）
## 用于在目录字典中存储关联的菜单节点引用
@export var node_key: String = "_node_"

## 焦点节点配置（字典类型）
## 键：目录路径（字符串），值：需要聚焦的控件节点路径
## 示例：{"Main/Menu": ^"MainMenu/StartButton", "Main/Settings": ^"SettingsPanel/BackButton"}
@export var focused_node: Dictionary[String, NodePath]

## 返回音效资源
@export var back_sound: SoundResource

## 目录管理资源（需实现 DictionaryDirectoryResource 类）
var directory_resource: DictionaryDirectoryResource = DictionaryDirectoryResource.new()

## 当前目录缓存
var current_directory: Dictionary

func _ready() -> void:
	## 初始化菜单节点
	for key: String in menu_path.keys():
		var path: NodePath = NodePath(key)                   # 将字符串路径转为 NodePath
		var node: Node = get_node(menu_path[key])            # 获取实际节点
		node.visible = false                                 # 初始隐藏所有菜单
		directory_resource.add_item(path, node, node_key)    # 注册到目录资源
		
	## 连接目录变更信号
	directory_resource.selected_directory_changed.connect(directory_changed)
	
	## 初始化目录状态
	directory_changed()
	
	## 延迟获取初始焦点（确保节点树构建完成）
	directory_grab_focus.call_deferred(".")                  # 参数"."存在问题，应为具体路径

## 目录变更回调：切换菜单显示
func directory_changed() -> void:
	## 隐藏旧目录节点
	var node: Node = directory_get_node(node_key)
	if node != null:
		node.visible = false
	
	## 更新当前目录引用
	current_directory = directory_resource.directory_get_current()
	
	## 显示新目录节点
	node = directory_get_node(node_key)
	if node != null:
		node.visible = true

## 从当前目录获取指定键的节点
func directory_get_node(key: String) -> Node:
	return current_directory.get(key) if current_directory.has(key) else null

## 打开指定目录路径
func open(value: String) -> void:
	directory_resource.directory_open(value)     # 委托给目录资源处理
	directory_grab_focus(value)                 # 尝试聚焦控件

## 聚焦目标控件
func directory_grab_focus(value: String) -> void:
	if not focused_node.has(value):
		return
	
	var node_path: NodePath = focused_node[value]
	assert(has_node(node_path), "焦点节点路径不存在: %s" % node_path)  # 调试断言
	var node: Control = get_node(node_path)
	if node != null:
		node.set_focus_mode(Control.FOCUS_ALL)
		node.grab_focus()                       # 实际获取焦点

## 返回上一级目录
func back() -> void:
	directory_resource.directory_back()          # 委托给目录资源
	if back_sound != null:
		back_sound.play_managed()                # 播放返回音效
