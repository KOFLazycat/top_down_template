# 基于形状投射的2D数据传输节点：通过ShapeCast2D检测碰撞区域，实现数据传输功能
# 继承自ShapeCast2D（2D形状投射节点，用于检测路径上的碰撞体）
class_name ShapeCastTransmitter2D
extends ShapeCast2D


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 碰撞排除列表：不参与检测的碰撞对象（如传输者自身或友方单位）
@export var exclude_list:Array[CollisionObject2D]

## 发送回调列表：存储子节点DataChannelTransmitter的send方法（用于数据发送）
var send_list:Array[Callable]

# -------------------- 生命周期方法（节点初始化与配置） --------------------
func _ready()->void:
	# BUG: 已知Godot引擎问题（https://github.com/godotengine/godot/issues/17238）
	# 临时解决方案：强制设置处理模式为始终处理（避免ShapeCast失效）
	process_mode = PROCESS_MODE_ALWAYS
	
	# 初始禁用形状投射（需手动启用或通过其他逻辑触发）
	enabled = false
	
	# 配置碰撞检测类型：仅检测Area2D（不检测物理体）
	collide_with_areas = true
	collide_with_bodies = false
	
	# 将排除列表中的对象加入碰撞例外（避免检测自身或指定对象）
	for _body:CollisionObject2D in exclude_list:
		if _body != null && _body.is_inside_tree():
			add_exception(_body)  # 调用父类方法添加排除对象
		else:
			Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "ShapeCastTransmitter2D: 排除列表中存在无效对象，已跳过", LogManager.LogLevel.WARNING)
	
	# 遍历子节点，收集数据传输器的send方法并绑定信号
	for child:Node in get_children():
		if !(child is DataChannelTransmitter):  # 仅处理DataChannelTransmitter类型子节点
			continue
		var data_transmitter:DataChannelTransmitter = child as DataChannelTransmitter
		send_list.append(data_transmitter.send)  # 收集子节点的send方法到列表
		
		# 绑定子节点的check_receiver信号（用于检查接收者是否仍在碰撞区域）
		data_transmitter.check_receiver.connect(_on_check_receiver.bind(data_transmitter))


# -------------------- 接收者检查回调（处理单个传输器的接收者验证） --------------------
## @brief 当子节点DataChannelTransmitter请求检查接收者时触发
## @param receiver 目标接收者（AreaReceiver2D类型）
## @param data_transmitter 触发检查的DataChannelTransmitter实例
func _on_check_receiver(receiver:AreaReceiver2D, data_transmitter:DataChannelTransmitter)->void:
	force_shapecast_update()  # 强制立即更新形状投射结果（避免帧延迟）
	
	# 遍历所有碰撞结果，验证接收者是否在碰撞区域内
	for i:int in get_collision_count():
		if get_collider(i) == receiver:  # 碰撞体为目标接收者
			data_transmitter.send(receiver)  # 调用子节点的send方法发送数据
			return  # 找到目标后退出循环


# -------------------- 传输检查方法（广播数据到所有有效接收者） --------------------
## @brief 检查当前碰撞区域内的所有接收者，并触发所有数据传输器的发送逻辑
func check_transmission()->void:
	force_shapecast_update()  # 强制立即更新形状投射结果
	
	# 遍历所有碰撞体，筛选有效接收者并触发发送
	for i:int in get_collision_count():
		var _collider:Object = get_collider(i)
		if !(_collider is AreaReceiver2D):  # 仅处理AreaReceiver2D类型碰撞体
			continue
		
		# 调用所有数据传输器的send方法（广播数据）
		for _callback:Callable in send_list:
			_callback.call(_collider as AreaReceiver2D)  # 传递接收者实例到send方法
