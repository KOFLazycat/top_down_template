# 声明自定义节点类型，继承自 Node2D（可参与 2D 场景树）
class_name BootPreloader
extends Node2D

# ----------------------
# 信号与导出变量
# ----------------------
# 预加载完成信号（用于通知外部预加载结束）
signal preload_finished

# 导出预加载资源（需在编辑器绑定一个 PreloadResource 类型的节点）
# PreloadResource 可能是一个自定义资源加载器，支持多线程加载
@export var preload_resource:PreloadResource

# 导出材质持有节点（用于存放需要编译的材质节点，避免材质重复编译）
# 例如：模型材质需要提前编译，此节点作为临时容器
@export var material_holder_node:Node


# ----------------------
# 状态变量（标记两类资源是否加载完成）
# ----------------------
var saveable_resources_done:bool  # 可保存资源加载完成标记
var preload_resource_done:bool    # PreloadResource 资源加载完成标记


# ----------------------
# Setter 方法：设置可保存资源完成状态
# ----------------------
func _set_saveable_resources_done(value:bool)->void:
	saveable_resources_done = value
	# 打印日志（注意：日志内容与实际含义不匹配，后续分析）
	print("BootPreloader [INFO]: SaveableResources - DONE")
	# 检查所有资源是否加载完成
	_check_done()


# ----------------------
# Setter 方法：设置 PreloadResource 完成状态（存在拼写错误）
# ----------------------
func _set_preload_resource_done(value:bool)->void:
	preload_resource_done = value
	print("BootPreloader [INFO]: PreloadResource - DONE")  # 准确日志
	_check_done()


# ----------------------
# 核心检查方法：判断所有资源是否加载完成
# ----------------------
func _check_done()->void:
	# 任意一类资源未完成则返回
	if !preload_resource_done:
		return
	if !saveable_resources_done:
		return
	# 两类资源均完成，触发预加载完成信号
	preload_finished.emit()


# ----------------------
# 启动预加载的核心方法
# ----------------------
func start()->void:
	# 添加安全校验
	if !preload_resource:
		push_error("PreloadResource not assigned!")
		return
	
	# 连接 PreloadResource 的预加载完成信号到 _set_preload_resource_done
	# CONNECT_ONE_SHOT 表示信号仅触发一次（避免重复调用）
	preload_resource.preload_finished.connect(
		_set_preload_resource_done.bind(true), 
		CONNECT_ONE_SHOT 
	)
	# 启动 PreloadResource 的预加载（传入材质持有节点）
	preload_resource.start(material_holder_node)
	
	# 将预加载资源存入全局持久化数据（PersistentData）
	# 目的：保留资源在内存中，供后续场景使用（如关卡切换）
	PersistentData.data["preload_resource"] = preload_resource
	
	# 预加载可保存资源（遍历全局可保存资源列表）
	for saveable:SaveableResource in PersistentData.saveable_list:
		saveable.load_resource()  # 加载单个可保存资源（假设是同步操作）
	# 标记可保存资源加载完成（注意：可能提前标记，存在逻辑问题）
	_set_saveable_resources_done(true)
