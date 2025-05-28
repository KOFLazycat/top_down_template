# 对象池节点：管理节点的复用与状态重置，支持动画、粒子、子节点的自动重置
class_name PoolNode  # 定义类名，可在场景中作为对象池节点使用
extends Node  # 继承自基础节点类


# -------------------- 信号（触发对象池回收） --------------------
signal pool_requested  # 信号：节点准备好被对象池回收时触发


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var ready_nodes:Array[Node] = []  # 需要每次加入场景树时触发 _ready() 的节点列表
@export var animation_player_list:Array[AnimationPlayer] = []  # 需要重置动画的 AnimationPlayer 列表
@export var particle2d_list:Array[GPUParticles2D] = []  # 需要重置的 2D GPU 粒子节点列表
@export var listen_node:Node  # 监听信号的目标节点（通过其信号触发 pool_return()）
@export var signal_name:StringName  # 监听的信号名称（与 listen_node 配合使用）


# -------------------- 成员变量（运行时状态） --------------------
var pool_was_requested:bool = false  # 标记是否已请求回收（防止重复触发）


# -------------------- 生命周期方法（节点初始化） --------------------
func _ready()->void:
	if !pool_was_requested:
		# 首次加载时处理粒子初始位置异常（GPUParticles2D 初始可能出现在 (0,0)）
		for _particle:GPUParticles2D in particle2d_list:
			if _particle == null:
				continue
			# 等待第一帧渲染后重启粒子（避免初始位置错误）
			get_tree().process_frame.connect(_particle.restart, CONNECT_ONE_SHOT)
	
	pool_was_requested = false  # 重置回收标记
	
	# 连接监听节点的信号（触发回收）
	if listen_node != null:
		if !listen_node.has_signal(signal_name):
			Log.entry("监听节点缺少目标信号：%s" % signal_name, LogManager.LogLevel.ERROR)
			return
		
		if !listen_node.is_connected(signal_name, pool_return):
			# 单次连接（避免重复触发）
			listen_node.connect(signal_name, pool_return, CONNECT_ONE_SHOT)


# -------------------- 核心逻辑：触发节点回收与状态重置 --------------------
func pool_return()->void:
	if pool_was_requested:
		# 防止物理线程或其他原因导致重复调用（如多次触发信号）
		return
	
	pool_was_requested = true  # 标记已请求回收
	request_ready()  # 请求重新触发自身 _ready()（确保子节点状态更新）
	
	# 重置动画播放器（停止当前动画）
	for _animation_player:AnimationPlayer in animation_player_list:
		if _animation_player == null:
				continue
		_animation_player.stop()
	
	# 重置粒子节点（重启粒子并清理历史粒子）
	for _particle:GPUParticles2D in particle2d_list:
		if _particle == null:
				continue
		# 粒子准备好后重启（确保粒子系统状态正确）
		_particle.ready.connect(_particle.restart, CONNECT_ONE_SHOT)
	
	# 触发 ready_nodes 列表中节点的 _ready()（重置子节点状态）
	for _node:Node in ready_nodes:
		if _node == null:
				continue
		_node.request_ready()
	
	# 发射回收信号（通知对象池该节点可回收）
	pool_requested.emit()


func _exit_tree()->void:
	# 断开监听节点的信号连接
	if listen_node != null && listen_node.is_connected(signal_name, pool_return):
		listen_node.disconnect(signal_name, pool_return)
	
	# 断开粒子的 ready 信号连接（避免残留）
	for _particle in particle2d_list:
		if _particle.is_connected("ready", _particle.restart):
			_particle.ready.disconnect(_particle.restart)
