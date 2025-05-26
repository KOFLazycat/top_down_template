# 敌人波次列表资源：定义单个波次的敌人配置
class_name SpawnWaveList  # 定义资源类名
extends Resource  # 继承自 Godot 资源类

## 是否为 BOSS 波次（用于标记特殊波次，如触发 BOSS 战）
@export var is_boss:bool

## 波次中的敌人数量（若为 BOSS 波次，可能为 1）
@export var count:int

## 敌人实例资源列表（每个元素对应一个敌人的场景资源）
@export var instance_list:Array[InstanceResource]
