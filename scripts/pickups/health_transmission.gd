# 健康值传输资源类：实现健康值（如治疗/伤害）的传输逻辑
class_name HealthTransmission  # 类名
extends TransmissionResource  # 继承自基础传输资源类（包含传输状态管理）


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 要传输的健康值（正数表示治疗，负数表示伤害）
@export var value:float


# -------------------- 数值设置方法（触发更新信号） --------------------
## @brief 设置传输的健康值并触发更新信号
## @param _value 新的健康值（正数/负数）
func set_value(_value:float)->void:
	value = _value  # 更新传输数值
	updated.emit()  # 触发更新信号（通知外部数值变更）


# -------------------- 核心逻辑：处理健康值传输（重写父类方法） --------------------
## @brief 处理健康值传输逻辑（根据目标健康状态修改数值）
## @param resource_node 接收方的资源节点（用于获取目标健康资源）
func process(resource_node:ResourceNode)->void:
	# 校验传输名称是否有效（继承自父类 TransmissionResource）
	if transmission_name.is_empty():
		Log.entry("HealthTransmission: 传输名称（transmission_name）未配置，无法获取健康资源", LogManager.LogLevel.ERROR)
		failed()
		return
	# 校验资源节点是否为空
	if resource_node == null:
		Log.entry("HealthTransmission: 资源节点（resource_node）为空，传输失败", LogManager.LogLevel.ERROR)
		failed()
		return
	# 从资源节点中获取与传输名称匹配的健康资源（transmission_name 继承自父类）
	var _health_resource:HealthResource = resource_node.get_resource(transmission_name)
	if _health_resource == null:
		Log.entry("HealthTransmission: 资源节点缺少健康资源（%s），传输失败" % transmission_name, LogManager.LogLevel.ERROR)
		failed()
		return
	
	# 检查目标健康状态：是否已满（如生命值已满）或已死亡（如生命值为0）
	if _health_resource.is_full() || _health_resource.is_dead:
		Log.entry("HealthTransmission: 目标健康状态是已满或者死亡，不再接受生命处理", LogManager.LogLevel.ERROR)
		failed()  # 健康状态不允许修改，标记传输失败
		return
	
	# 向目标健康资源添加健康值（正数治疗，负数伤害）
	_health_resource.add_hp(value)
	success()  # 健康值修改成功，标记传输成功
