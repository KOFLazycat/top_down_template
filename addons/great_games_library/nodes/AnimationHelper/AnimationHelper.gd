# 动画辅助节点：封装 AnimationPlayer 的常用操作，简化动画播放逻辑
class_name AnimationHelper  # 定义类名，可在场景中作为动画控制节点使用
extends Node  # 继承自基础节点类


# -------------------- 导出变量（编辑器可视化配置） --------------------
@export var animation_player:AnimationPlayer  # 需要控制的目标 AnimationPlayer 节点


# -------------------- 核心方法：播放指定动画 --------------------
## @brief 播放指定名称的动画（支持重置当前动画）
## @param animation 要播放的动画名称（需与 AnimationPlayer 中定义的动画名称一致）
## @param reset 是否重置当前动画（true：先停止再播放；false：直接播放）
func play(animation:StringName, reset:bool = false)->void:
	# 确保已配置有效的 AnimationPlayer（调试模式生效）
	if animation_player == null:
		Log.entry("动画播放器（animation_player）未配置，无法播放动画", LogManager.LogLevel.ERROR)
		return
	if !animation_player.has_animation(animation):
		Log.entry("动画播放器缺少目标动画：%s" % animation, LogManager.LogLevel.ERROR)
		return
	
	if reset:  # 若需要重置，先停止当前播放的动画
		animation_player.stop()
	
	# 播放指定名称的动画（依赖 AnimationPlayer 中已存在该动画）
	animation_player.play(animation)
