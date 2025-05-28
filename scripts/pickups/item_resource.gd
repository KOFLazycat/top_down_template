# 物品资源类：封装物品的基础属性，用于编辑器配置和代码逻辑调用
class_name ItemResource  # 定义资源类名（可在编辑器中创建实例）
extends Resource  # 继承自 Godot 资源类（支持数据序列化与编辑器配置）


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var icon:Texture2D  # 物品图标（用于 UI 显示，如背包、商店中的物品图标）
@export var scene_path:String  # 物品实例的场景路径（如 "res://items/weapon_sword.tscn"）
enum ItemType {  # 物品类型枚举（当前仅定义武器类型，可扩展其他类型）
	WEAPON,       # 武器
	ARMOR,        # 防具
	CONSUMABLE,   # 消耗品
	MATERIAL      # 材料
}
@export var type:ItemType  # 物品类型（指定当前物品属于哪种类型）
@export var unlocked:bool = false # 解锁状态（是否已解锁，可用于控制物品是否可用/显示）
