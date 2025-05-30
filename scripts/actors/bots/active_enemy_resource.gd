# 活跃敌人资源树节点：以树状结构存储敌人实例的父子关系（支持分裂/进化等层级逻辑）
class_name ActiveEnemyResource  
extends Resource  

## 父资源节点（形成双向链表结构）
var parent:ActiveEnemyResource  

## 子资源节点列表（存储分裂/召唤的子敌人）
var children:Array[ActiveEnemyResource] = []  

## 关联的敌人实例列表（指向 ActiveEnemy 节点）
var nodes:Array[ActiveEnemy] = []  

## 节点清理时的回调函数（如播放死亡特效、增加分数）
var clear_callback:Callable
