# 武器触发控制器：管理武器的射击逻辑，处理输入响应、投射物生成及状态控制
class_name WeaponTrigger  # 定义类名，作为武器射击逻辑的核心控制器
extends Node  # 继承自基础节点类


# -------------------- 信号定义（事件通知） --------------------
## 射击事件信号：当武器成功触发射击时发射（用于通知其他组件如后坐力、动画）
signal shoot_event  

# -------------------- 导出变量（编辑器可视化配置） --------------------
## 武器启用开关：控制整个武器系统的激活状态（与weapon.enabled联动）
@export var enabled:bool = true  
## 武器引用：绑定当前武器节点（获取资源、状态及输入处理）
@export var weapon:Weapon  
## 投射物生成器：负责实例化投射物的组件（配置生成参数）
@export var projectile_spawner:ProjectileSpawner  
## 射击音效资源：射击时播放的声音（自动管理生命周期）
@export var sound_resource:SoundResource  
## 射击能力开关：控制是否允许当前射击（受冷却时间等条件限制）
@export var can_shoot:bool = true  

# -------------------- 成员变量（运行时状态） --------------------
## 输入资源：从武器资源节点获取的输入数据（包含用户操作信息）
var input_resource:InputResource


# -------------------- 生命周期方法（初始化与信号连接） --------------------
func _ready()->void:
	if weapon == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponTrigger: 武器引用（weapon）未配置", LogManager.LogLevel.ERROR)
		return
	if projectile_spawner == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponTrigger: 投射物生成器（projectile_spawner）未配置", LogManager.LogLevel.ERROR)
		return
	if sound_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponTrigger: 射击音效资源（sound_resource）未配置", LogManager.LogLevel.ERROR)
		return
	if weapon.resource_node == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponTrigger: 武器资源节点（resource_node）未配置", LogManager.LogLevel.ERROR)
		return
	# 从武器的资源节点中获取输入资源（用于监听用户操作）
	input_resource = weapon.resource_node.get_resource("input")
	if input_resource == null:
		Log.entry("[" + get_script().resource_path.get_file().get_basename() + ".gd] " + "[" + str(get_stack()[0]["line"] if get_stack()[0].size() > 0 else -1) + "] " + "WeaponTrigger: 输入资源（input_resource）未配置", LogManager.LogLevel.ERROR)
		return
	
	# 监听武器启用状态变化，同步更新当前组件的启用状态
	if !weapon.enabled_changed.is_connected(set_enabled):
		weapon.enabled_changed.connect(set_enabled)
	set_enabled(weapon.enabled)  # 初始化时同步武器状态
	
	# 同步武器的伤害数据和碰撞层到投射物生成器
	projectile_spawner.damage_data_resource = weapon.damage_data_resource
	projectile_spawner.collision_mask = Bitwise.append_flags(projectile_spawner.collision_mask, weapon.collision_mask)
	
	# 当节点为池化节点时，确保初始化逻辑延迟执行（避免资源竞争）
	request_ready()  


# -------------------- 启用状态同步方法（响应武器状态变化） --------------------
## @brief 根据武器启用状态更新输入监听
## @param value 武器当前启用状态（true: 激活，false: 禁用）
func set_enabled(value:bool)->void:
	enabled = value
	if enabled:
		# 启用时连接输入事件（如鼠标点击或按键按下）
		if !input_resource.action_pressed.is_connected(on_shoot):
			input_resource.action_pressed.connect(on_shoot)
	else:
		# 禁用时断开输入事件
		if input_resource.action_pressed.is_connected(on_shoot):
			input_resource.action_pressed.disconnect(on_shoot)

# -------------------- 射击事件处理核心方法 --------------------
## @brief 响应输入事件，触发投射物生成和射击相关逻辑
func on_shoot()->void:
	# 检查射击条件（当前是否允许射击且武器已启用）
	if !can_shoot || !weapon.enabled:
		return
	
	shoot_event.emit()  # 发射射击事件信号（通知外部组件如后坐力、特效）
	
	# 设置投射物生成器的基础参数
	projectile_spawner.projectile_position = weapon.global_position  # 生成位置为武器当前位置
	projectile_spawner.direction = input_resource.aim_direction       # 生成方向为输入的瞄准方向
	
	# 触发投射物生成（投射物生成器负责具体实例化逻辑）
	projectile_spawner.spawn()
	
	# 播放射击音效（使用managed模式自动管理音效生命周期）
	if sound_resource != null:
		sound_resource.play_managed()


# -------------------- 辅助控制方法 --------------------
## @brief 设置射击能力开关（用于冷却时间等限制）
func set_can_shoot(value:bool)->void:
	can_shoot = value

## @brief 判断是否可以重新触发射击（如连射模式下按住按钮持续发射）
func can_retrigger()->bool:
	return input_resource.action_1  # 返回输入资源中action_1的状态（通常为按键按住状态）

## @brief 获取当前瞄准方向（供后坐力等组件使用）
func get_direction()->Vector2:
	return input_resource.aim_direction  # 返回标准化的瞄准方向向量
