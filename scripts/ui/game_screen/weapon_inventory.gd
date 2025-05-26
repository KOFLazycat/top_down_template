# 武器背包界面组件：动态生成武器槽位并管理选中状态
class_name WeaponInventory  # 定义类名，可在场景中作为水平布局容器使用
extends HBoxContainer  # 继承自水平布局容器（子节点水平排列）


# -------------------- 导出变量（编辑器可视化配置） --------------------

## 槽位预制体节点（需包含图标子节点，如 TextureRect）
@export var prefab_slot_node:Control

## 图标子节点的节点路径（相对于槽位预制体的根节点）
@export var prefab_icon_nodepath:NodePath = "Icon"

## 物品集合资源（存储武器列表、选中索引等数据）
@export var inventory_resource:ItemCollectionResource

## 选中状态的槽位纹理（用于高亮显示当前选中槽位）
@export var selected_texture:Texture2D

## 普通状态的槽位纹理（未选中时的默认纹理）
@export var slot_texture:Texture2D


# -------------------- 成员变量（运行时状态） --------------------

var slot_scene:PackedScene  # 槽位预制体的打包场景（用于实例化）
var slot_list:Array[TextureRect]  # 存储所有槽位的 TextureRect 实例
var icon_list:Array[TextureRect]   # 存储每个槽位中的图标 TextureRect 实例


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if inventory_resource == null:
		Log.entry("未配置物品集合资源（inventory_resource）", LogManager.LogLevel.ERROR)
		return
	
	# 将预制槽位节点打包为 PackedScene（Godot 4 建议使用 PackedScene 替代 ScenePacker）
	slot_scene = ScenePacker.create_package(prefab_slot_node, true)
	
	# 清理已有子节点（确保初始化时界面干净）
	for _child:Node in get_children():
		remove_child(_child)
		_child.queue_free()
	
	# 清空槽位和图标列表
	slot_list.clear()
	icon_list.clear()
	
	# 根据物品集合资源的最大物品数创建槽位
	for i:int in inventory_resource.max_items:
		var _slot:TextureRect = slot_scene.instantiate()  # 实例化槽位预制体
		_slot.name = "Slot%d" % i  # 命名槽位（便于调试）
		add_child(_slot)  # 添加到水平布局容器
		slot_list.append(_slot)  # 保存槽位引用
		
		 # 校验图标节点是否存在
		if !_slot.has_node(prefab_icon_nodepath):
			Log.entry("槽位预制体中未找到图标节点：%s" % prefab_icon_nodepath, LogManager.LogLevel.ERROR)
			continue
		# 获取槽位内的图标节点并保存引用
		icon_list.append(_slot.get_node(prefab_icon_nodepath))
	
	# 监听物品集合资源的更新信号（物品列表变更时刷新图标）
	inventory_resource.updated.connect(_on_update)
	_on_update()  # 初始化图标显示
	
	# 监听物品集合资源的选中变更信号（选中索引变更时刷新选中状态）
	inventory_resource.selected_changed.connect(_on_selected_changed)
	_on_selected_changed()  # 初始化选中状态


# -------------------- 物品列表更新回调（刷新图标显示） --------------------
func _on_update()->void:
	for i:int in inventory_resource.max_items:
		if i < inventory_resource.list.size():
			# 若槽位索引小于物品列表长度，显示对应物品的图标
			icon_list[i].texture = inventory_resource.list[i].icon
		else:
			# 否则清空图标（槽位无物品时显示空）
			icon_list[i].texture = null


# -------------------- 选中状态变更回调（刷新槽位选中效果） --------------------
func _on_selected_changed()->void:
	for i:int in slot_list.size():
		if i == inventory_resource.selected:
			# 选中槽位显示选中纹理
			slot_list[i].texture = selected_texture
		else:
			# 未选中槽位显示普通纹理
			slot_list[i].texture = slot_texture
