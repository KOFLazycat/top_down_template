# 活跃敌人实例：管理单个敌人的生命周期，并接入全局树状管理系统
class_name ActiveEnemy  
extends Node  

## 静态成员：全局管理敌人实例与资源树的映射关系
static var instance_dictionary:Dictionary = {}  # 键：敌人节点实例，值：对应的 ActiveEnemyResource
static var root:ActiveEnemyResource = ActiveEnemyResource.new()  # 树状结构根节点（所有敌人的顶级父节点）
static var active_instances:Array[Node2D] = []  # 所有活跃敌人实例列表（用于快速查询）

## 静态方法：向树状结构中插入新敌人实例（支持父-子关系）
static func insert_child(node:Node, parent_branch:ActiveEnemyResource, clear_callback:Callable = Callable()):
	## 创建新资源节点并配置父子关系
	var _resource = ActiveEnemyResource.new()
	_resource.parent = parent_branch
	_resource.clear_callback = clear_callback
	instance_dictionary[node] = _resource  # 建立实例到资源的映射
	
	## 非根节点时添加到父节点的子列表
	if parent_branch != null:
		parent_branch.children.append(_resource)

## 静态方法：递归移除空分支节点（当分支无实例且无子分支时触发）
static func remove_branch(branch:ActiveEnemyResource, caller:ActiveEnemy):
	## 若分支仍有实例或子分支，不执行清理
	if !branch.nodes.is_empty() || !branch.children.is_empty():
		return
	
	## 执行清理回调（如通知 UI 加分）
	if branch.clear_callback.is_valid():
		branch.clear_callback.call(caller)
	
	## 从父节点中移除当前分支，并递归清理空父分支
	if branch.parent != null:
		assert(branch.parent.children.has(branch), "分支未正确添加到父节点")
		branch.parent.children.erase(branch)
		remove_branch(branch.parent, caller)  # 递归清理上层空分支


## 静态方法：销毁分支下的所有子敌人（用于分裂敌人死亡时全灭子单位）
static func destroy_children_enemies(branch:ActiveEnemyResource):
	## 销毁当前分支的直接子实例
	for _enemy in branch.nodes:
		_enemy.self_destruct()  # 触发子敌人自我销毁
	## 递归销毁所有子分支
	for _child_branch in branch.children:
		destroy_children_enemies(_child_branch)


## 实例属性：配置信号监听与销毁策略
@export var listen_node:Node  # 监听信号的目标节点（如生命值节点）
@export var signal_name:StringName  # 监听的信号名称（如 "health_depleted"）
@export var resource_node:ResourceNode  # 资源节点（存储敌人属性，如生命值、攻击力）
@export var destroy_children:bool = false  # 是否在死亡时销毁所有子敌人（适用于母体敌人）

var enemy_resource:ActiveEnemyResource  # 当前实例关联的资源节点


## 实例方法：从树状结构中移除自身及子分支（触发死亡逻辑）
func remove_self():
	## 若需要销毁子敌人，倒序遍历避免索引混乱
	if destroy_children:
		var _children_count = enemy_resource.children.size()
		for i in range(_children_count):  # 原代码中 "for i in _children_count" 应为 "for i in range(_children_count)"
			var _child_branch = enemy_resource.children[_children_count - 1 - i]
			destroy_children_enemies(_child_branch)
	
	## 从资源节点中移除当前实例，并触发分支清理
	enemy_resource.nodes.erase(self)
	remove_branch(enemy_resource, self)


## 生命周期方法：节点初始化时连接信号
func _ready():
	if listen_node != null:
		assert(listen_node.has_signal(signal_name), "目标节点无指定信号")
		if !listen_node.is_connected(signal_name, remove_self):
			listen_node.connect(signal_name, remove_self)  # 监听信号以触发死亡逻辑

## 生命周期方法：节点进入场景树时注册到全局管理系统
func _enter_tree():
	## 从映射表或根节点获取资源分支
	if instance_dictionary.has(owner):
		enemy_resource = instance_dictionary[owner]
		instance_dictionary.erase(owner)
	else:
		enemy_resource = root  # 无父节点时默认关联到根节点
	
	## 添加到资源节点的实例列表和全局活跃列表
	enemy_resource.nodes.append(self)
	active_instances.append(owner)
	
	## 退出场景时清理引用（确保内存释放）
	tree_exiting.connect(_on_exiting_tree.bind(owner), CONNECT_ONE_SHOT)


## 生命周期方法：节点退出场景树时移除全局引用
func _on_exiting_tree(owner_reference:Node2D):
	assert(owner_reference != null, "敌人实例已销毁")
	active_instances.erase(owner_reference)  # 从活跃列表中移除

## 实例方法：触发自我销毁（如生命值归零）
func self_destruct():
	## 获取生命值资源并立即击杀（触发死亡信号）
	var _health_resource = resource_node.get_resource("health") as HealthResource
	if _health_resource != null:
		_health_resource.insta_kill()
