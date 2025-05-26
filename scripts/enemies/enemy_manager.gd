# 敌人管理器节点：处理波次队列的初始化和深拷贝（修复资源引用问题）
class_name EnemyManager  # 定义节点类名
extends Node  # 继承自 Godot 基础节点类

## 波次队列资源（存储所有波次的配置信息）
@export var wave_queue:SpawnQueueResource

func _ready()->void:
	if wave_queue == null:
		return  # 若未配置波次队列，直接返回
	
	if wave_queue.waves.is_empty():
		Log.entry("波次队列为空，无敌人可生成", LogManager.LogLevel.ERROR)
		return
	
	## BUG 修复：解决 PackedScene 中资源引用的浅拷贝问题
	## 背景：Godot 在加载 PackedScene 时可能共享资源引用，导致修改影响原数据
	## 方案：通过深拷贝创建独立副本
	wave_queue = wave_queue.duplicate()  # 复制波次队列资源
	
	# 深拷贝波次列表中的每个波次（避免引用同一 SpawnWaveList 实例）
	wave_queue.waves = wave_queue.waves.duplicate()
	
	for i:int in wave_queue.waves.size():
		if wave_queue.waves[i] is not SpawnWaveList:
			Log.entry("第 %d 波数据类型不是 SpawnWaveList" % i, LogManager.LogLevel.ERROR)
			continue
		# 对每个波次进行深拷贝（确保每个波次的数据独立）
		wave_queue.waves[i] = wave_queue.waves[i].duplicate()
