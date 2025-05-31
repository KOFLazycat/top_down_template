# 洞穴恢复节点：处理角色踏入洞穴时的伤害计算与安全位置恢复
class_name HoleRecovery  # 定义类名，可在场景中作为洞穴伤害处理控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 安全瓷砖追踪节点：用于获取角色的安全位置并移动角色
@export var safe_tile_tracker:SafeTileTracker  
## 资源节点：存储健康资源（HealthResource）
@export var resource_node:ResourceNode  
## 洞穴触发节点：检测角色是否踏入洞穴区域
@export var hole_trigger:HoleTrigger  
## 洞穴伤害值：角色踏入洞穴时受到的伤害（负值表示扣血）
@export var hole_damage:int = 10  

# -------------------- 成员变量（运行时状态） --------------------
var health_resource:HealthResource  # 角色的健康资源（用于处理伤害）


# -------------------- 生命周期方法（节点初始化与信号连接） --------------------
func _ready()->void:
	if safe_tile_tracker == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "HoleRecovery: 安全瓷砖追踪节点（safe_tile_tracker）未配置", LogManager.LogLevel.ERROR)
		return
	if resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "HoleRecovery: 资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	if hole_trigger == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "HoleRecovery: 洞穴触发节点（hole_trigger）未配置", LogManager.LogLevel.ERROR)
		return
	# 获取健康资源（必须配置，否则无法处理伤害）
	health_resource = resource_node.get_resource("health")
	if health_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "HoleRecovery: 健康资源（health）未配置，洞穴伤害逻辑失效", LogManager.LogLevel.ERROR)
		return
	
	# 连接洞穴触发信号（角色踏入洞穴时触发伤害处理）
	hole_trigger.hole_touched.connect(_on_hole_touched)
	
	# 节点退出场景树时断开信号连接（避免内存泄漏）
	tree_exiting.connect(
		hole_trigger.hole_touched.disconnect.bind(_on_hole_touched), 
		CONNECT_ONE_SHOT  # 确保仅断开一次
	)
	# 配合对象池使用（标记节点准备完成）
	request_ready()


# -------------------- 洞穴触发回调（处理伤害与安全位置恢复） --------------------
## @brief 角色踏入洞穴时触发的回调函数
func _on_hole_touched()->void:
	if health_resource.is_dead:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "HoleRecovery: 角色已死亡，跳过处理", LogManager.LogLevel.INFO)
		return  # 角色已死亡，跳过处理
	
	# 应用洞穴伤害（负数表示扣除血量）
	health_resource.add_hp(-hole_damage)
	
	# 将角色移动到安全瓷砖位置（由SafeTileTracker提供）
	safe_tile_tracker.move_to_safe_position()
