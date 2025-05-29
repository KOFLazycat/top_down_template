# 资源节点数据条目：为 ResourceNode 提供可配置的资源管理条目（简化编辑器配置）
class_name ResourceNodeItem  # 定义类名，可在资源库中创建实例并关联到 ResourceNode
extends Resource  # 继承自基础资源类（可被保存为 .tres 文件，支持编辑器可视化配置）


# -------------------- 导出变量（编辑器可视化配置） --------------------
## 指向可保存资源的引用（如自定义的 HealthResource、ItemResource 等）
@export var resource:SaveableResource  # 需在编辑器绑定具体的 SaveableResource 实例

## 标记是否在创建新 ResourceNode 时复制资源（确保实例唯一性）
## - true：每次创建 ResourceNode 时复制 resource，避免多节点共享同一实例（数据隔离）
## - false：多节点共享 resource 实例（数据同步）
@export var make_unique:bool

## 资源条目的描述信息（用于编辑器备注，支持多行输入）
@export_multiline var description:String  # 可填写资源用途、注意事项等说明


# -------------------- 运行时状态变量（非导出，内部使用） --------------------
## 实际使用的资源实例（可能是 resource 的副本，具体由 make_unique 决定）
## - 若 make_unique 为 true，value 是 resource 的复制实例
## - 若 make_unique 为 false，value 直接指向 resource
var value:SaveableResource
