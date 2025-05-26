# 波次队列资源：管理多个波次的顺序和配置
class_name SpawnQueueResource  # 定义资源类名
extends Resource  # 继承自 Godot 资源类

## 波次列表数组（按顺序存储 SpawnWaveList 实例）
@export var waves:Array[SpawnWaveList]
