# 安全瓷砖追踪节点：检测角色所在的安全瓷砖（非障碍物瓷砖），并提供自动回退到安全位置的功能
class_name SafeTileTracker  # 定义类名，可在场景中作为瓷砖安全检测控制器
extends Node  # 继承自基础节点类

# -------------------- 导出变量（编辑器可视化配置） --------------------
## 障碍物瓷砖地图引用节点：指向场景中的TileMap层（用于检测障碍物瓷砖）
@export var obstacle_tilemap_reference:ReferenceNodeResource  
## 角色节点：需要追踪安全位置的角色（如玩家或NPC）
@export var actor:Node2D  

# -------------------- 成员变量（运行时状态） --------------------
var safe_tile:Vector2i  # 安全瓷砖坐标（地图坐标系）
var tile_map_layer:TileMapLayer  # 障碍物瓷砖地图层引用（TileMap的子层）

# -------------------- 生命周期方法（节点初始化与监听配置） --------------------
func _ready()->void:
	if obstacle_tilemap_reference == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SafeTileTracker: 障碍物瓷砖地图引用节点（obstacle_tilemap_reference）未配置", LogManager.LogLevel.ERROR)
		return
	if actor == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "SafeTileTracker: 角色节点（actor）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 节点进入场景树时触发初始化
	tree_entered.connect(on_tree_enter)
	on_tree_enter()  # 立即执行一次初始化（处理可能已在场景中的情况）


# -------------------- 场景树进入回调（初始化瓷砖层监听） --------------------
func on_tree_enter()->void:
	# 监听障碍物瓷砖地图引用的变化（如动态加载TileMap时更新引用）
	obstacle_tilemap_reference.listen(self, _tilemap_layer_changed)


# -------------------- 瓷砖层变更回调（更新瓷砖层引用并初始化安全瓷砖） --------------------
func _tilemap_layer_changed()->void:
	if !is_inside_tree():  # 确保节点已加入场景树
		return
	if obstacle_tilemap_reference.node == null:  # 校验引用节点有效性
		return
	
	tile_map_layer = obstacle_tilemap_reference.node  # 获取瓷砖层实例
	var _actor_pos:Vector2 = actor.global_position  # 获取角色全局位置
	safe_tile = tile_map_layer.local_to_map(_actor_pos)  # 将角色位置转换为瓷砖坐标


# -------------------- 物理帧更新（实时检测安全瓷砖） --------------------
## @brief 每帧检测角色当前瓷砖是否为安全瓷砖（非障碍物）
func _physics_process(_delta:float)->void:
	if tile_map_layer == null:  # 防止瓷砖层未初始化
		return
	
	# 计算角色在瓷砖层的本地位置（相对于瓷砖层原点）
	var _actor_local_pos:Vector2 = actor.global_position - tile_map_layer.global_position
	var _current_tile:Vector2i = tile_map_layer.local_to_map(_actor_local_pos)  # 当前瓷砖坐标
	
	if _current_tile == safe_tile:  # 未离开安全瓷砖，无需处理
		return
	
	# 获取当前瓷砖的源ID（-1表示无瓷砖，即安全区域）
	var _tile_id:int = tile_map_layer.get_cell_source_id(_current_tile)
	if _tile_id == -1:  # 当前瓷砖为安全瓷砖（无障碍物）
		safe_tile = _current_tile  # 更新安全瓷砖坐标
	else:
		# 否则不更新安全瓷砖（保持上次的安全位置）
		pass


# -------------------- 公有方法：移动角色到安全瓷砖位置 --------------------
## @brief 将角色移动到已记录的安全瓷砖中心位置
func move_to_safe_position()->void:
	if tile_map_layer == null:
		return
	
	# 将安全瓷砖坐标转换为世界坐标
	var _pos:Vector2 = tile_map_layer.map_to_local(safe_tile)
	actor.global_position = _pos + tile_map_layer.global_position
