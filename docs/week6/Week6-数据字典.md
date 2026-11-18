# 第六周数据字典修订

完整 v0.1 字段、键和基数以[第五周已核对的数据字典](../week5/er-model.md)为准；本页只列迁移后的差异。

本文件记录第六周从 v0.1 到 v1.0 的字典差异。其他 14 张表在这次迁移中沿用[第2周字典](../week2/README.md)的字段与键。第三阶段新增的优惠快照、库存审计和分类父级分别见[第10周](../week10/README.md)、[第11周](../week11/README.md)、[第12周](../week12/README.md)。

## InventoryMovement 库存变动

| 字段 | 类型 | 空值 | 键/约束 | 说明 |
| --- | --- | --- | --- | --- |
| `MovementID` | `VARCHAR(12)` | 否 | PK | 一次现存量变化的标识 |
| `BatchID` | `VARCHAR(12)` | 否 | FK → `InventoryBatch.BatchID` | 受影响库存批次；采购来源经该批次追溯 |
| `MovementType` | `NVARCHAR(10)` | 否 | CHECK：采购入库、销售出库、盘点调整、报损 | 库存变化业务类型 |
| `QuantityDelta` | `INT` | 否 | CHECK：采购入库正数、销售出库/报损负数、盘点调整非零 | 现存数量的有符号变化 |
| `SalesItemID` | `VARCHAR(12)` | 是 | FK → `SalesOrderItem.SalesItemID` | 销售出库时非空；其他类型为空 |
| `Reason` | `NVARCHAR(200)` | 否 | 非空文本 CHECK | 变动原因或操作说明 |
| `OperatorID` | `VARCHAR(12)` | 否 | FK → `Employee.EmployeeID` | 确认库存变动的员工 |
| `OccurredAt` | `DATETIME2(0)` | 否 | — | 实际确认现存变化的时间 |

### 依赖与变更

- 候选码：`MovementID`。
- 主要依赖：`MovementID → BatchID, MovementType, QuantityDelta, SalesItemID, Reason, OperatorID, OccurredAt`。
- v0.1 另有 `PurchaseItemID`。在采购入库子集中，批次编号决定其唯一采购明细；由于 `InventoryBatch.BatchID` 是主键且该批次保存 `PurchaseItemID`，该值能通过连接还原。
- v0.1 的 `FK_Movement_BatchPurchase(BatchID, PurchaseItemID)` 已保证库存流水与批次的采购来源一致。v1.0 删除该复合外键、单列采购明细外键和 `PurchaseItemID` 列；删除 CHECK 后，创建仅引用保留字段的新规则约束。
- v0.1 的 `InventoryBatch.UQ_InventoryBatch_2(BatchID, PurchaseItemID)` 仅为复合外键提供被引用键，`BatchID` 已是主键，因此该非最小超级键在 v1.0 一并删除。
- 目标库增加 `TR_InventoryBatch_PurchaseSourceImmutable`：批次已有库存流水后，不允许将该批的 `PurchaseItemID` 改成另一采购明细；这保护删去重复列后的历史追溯含义。回归要求返回错误 51620。
- 迁移不删库存流水、批次或采购明细记录。入库来源查询方式改为 `InventoryMovement.BatchID → InventoryBatch.PurchaseItemID → PurchaseOrderItem`。

总额、库存现存量及顾客积分余额是此次迁移保留的跨表缓存，由受控事务维护，并通过回归核对。
