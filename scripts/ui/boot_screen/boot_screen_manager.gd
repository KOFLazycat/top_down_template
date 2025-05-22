# 声明自定义节点类型（可在编辑器中识别并实例化），继承自基础节点类 Node
class_name BootScreenManager
extends Node

# ----------------------
# 导出变量（可在编辑器属性面板中配置）
# ----------------------
@export var next_screen:String  # 目标场景文件路径（如 "res://scenes/Game.tscn"）
@export var animation_player:AnimationPlayer  # 绑定场景中的动画播放器节点（控制启动动画）
@export var boot_preloader:BootPreloader  # 绑定自定义预加载器节点（负责资源预加载逻辑）

# -------------- 替代枚举：用常量字符串管理动画名称 --------------
const ANIM_IDLE: StringName = "idle"          # 初始动画名称（可在编辑器中修改）
const ANIM_TRANSITION_OUT: StringName = "transition_out"  # 过渡动画名称

# ----------------------
# 生命周期方法：节点初始化完成时调用
# ----------------------
func _ready()->void:
	# 空值检查（避免未绑定导出变量）
	if not animation_player or not boot_preloader:
		push_error("未绑定 animation_player 或 boot_preloader，启动流程终止！")
		return

	# 检查动画是否存在（使用常量字符串）
	if not animation_player.has_animation(ANIM_IDLE):
		push_error("动画播放器缺少 %s 动画！" % ANIM_IDLE)
		return
	# 播放初始 idle 动画（通常是启动画面的静态展示，如 logo 淡入）
	animation_player.play(ANIM_IDLE)

	# 连接预加载完成信号：当预加载器（BootPreloader）完成资源加载时，触发 _transition_out 方法
	# 信号（Signal）是 Godot 节点间解耦通信的核心机制
	boot_preloader.preload_finished.connect(_transition_out, CONNECT_ONE_SHOT)

	# 创建 0.1 秒定时器，超时后启动预加载
	# 延迟原因：确保启动画面视觉元素（如 logo）先渲染到屏幕，避免预加载阻塞画面显示
	get_tree().create_timer(0.1).timeout.connect(boot_preloader.start)


# ----------------------
# 自定义方法：预加载完成后触发过渡动画
# ----------------------
func _transition_out()->void:
	# 检查过渡动画是否存在（使用常量字符串）
	if not animation_player.has_animation(ANIM_TRANSITION_OUT):
		push_error("动画播放器缺少 %s 动画！" % ANIM_TRANSITION_OUT)
		return

	# 播放过渡动画（如启动画面淡出、进度条收束），0.5 秒动画混合时间（平滑切换动画状态）
	animation_player.play(ANIM_TRANSITION_OUT, 0.5)

	# -------------- 优化点5：断开旧信号连接（避免重复触发） --------------
	# 先断开之前可能存在的连接（若重复调用 _transition_out）
	if animation_player.animation_finished.is_connected(_switch_scene):
		animation_player.animation_finished.disconnect(_switch_scene)
	
	# 连接动画完成信号：过渡动画播放结束后，触发 _switch_scene 切换场景
	animation_player.animation_finished.connect(_switch_scene, CONNECT_ONE_SHOT)


# ----------------------
# 自定义方法：切换到目标场景
# ----------------------
func _switch_scene(_anim:StringName)->void:
	# 通过场景树切换到目标场景（next_screen 需在编辑器中配置正确路径）
	get_tree().change_scene_to_file(next_screen)
