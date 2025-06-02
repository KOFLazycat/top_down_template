# 场景切换触发器节点：通过Area2D检测碰撞，触发场景切换逻辑
class_name TriggerSceneChanger  # 定义类名，可在场景中作为场景切换控制器
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 触发区域：用于检测碰撞的Area2D节点（需在场景中配置碰撞形状）
@export var area:Area2D  
## 目标碰撞层：触发切换的目标对象所在的2D物理层（通过位掩码设置）
@export_flags_2d_physics var target_layer:int  
## 目标场景路径：切换目标场景的资源路径（如"res://scenes/NextLevel.tscn"）
@export var scene_path:String  


# -------------------- 生命周期方法（初始化碰撞层与信号连接） --------------------
func _ready() -> void:
	# 将目标层添加到区域的碰撞掩码中（确保仅检测特定层对象）
	area.collision_mask = Bitwise.append_flags(area.collision_mask, target_layer)
	# 连接区域进入信号（当目标层对象进入区域时触发场景切换）
	area.area_entered.connect(on_entering)

# -------------------- 区域进入回调（延迟场景切换处理） --------------------
## @brief 当目标层对象进入触发区域时调用
## @param _area 进入区域的Area2D对象（未使用，仅作为信号参数存在）
func on_entering(_area:Area2D)->void:
	# 使用call_deferred在当前帧结束后执行场景切换（避免物理帧中操作场景树）
	change_scene.call_deferred()


# -------------------- 场景切换核心逻辑 --------------------
## @brief 加载并切换到目标场景（需确保场景路径正确）
func change_scene()->void:
	# 加载目标场景（同步加载，可能阻塞主线程，大场景需注意性能）
	var next_scene:PackedScene = load(scene_path)
	assert(next_scene != null, "目标场景加载失败，路径：" + scene_path)  # 断言校验场景有效性
	
	# 获取当前场景树并执行场景切换
	var scene_tree:SceneTree = get_tree()
	var err:int = scene_tree.change_scene_to_packed(next_scene)
	assert(err == 0, "场景切换失败，错误码：" + str(err))  # 断言校验切换结果
