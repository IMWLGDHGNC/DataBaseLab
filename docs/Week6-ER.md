# 第六周 v1.0 ER 模型

可编辑的[完整目标图源](week6/er-v1.0.mmd)直接从第五周已核对的[完整 v0.1 图源](week5/er-v0.1.mmd)修订。[SVG](../result/week6/er-v1.0.svg) 可缩放查看，[PNG](../result/week6/er-v1.0.png)用于展示。它保留 15 个业务实体和第五周确认的基数、参与约束及属性类型；目标模式有 106 个属性、22 个不同语义的联系。权限辅助表 `customer_security.CustomerPrincipal` 仍单独计数。

本次只删除 `InventoryMovement.PurchaseItemID` 和“采购明细 → 库存流水”的直接联系。采购入库来源仍可沿 `InventoryMovement.BatchID → InventoryBatch.PurchaseItemID → PurchaseOrderItem` 唯一追溯。第五周图中其余联系与条件规则保持原意；采购单、销售单至少一条明细等最小参与要求仍须由受控事务和复核保证，不能仅凭现有外键推断已经实现。

| 核对项 | v0.1 | v1.0 目标 |
| --- | ---: | ---: |
| 业务实体 | 15 | 15 |
| 业务属性 | 107 | 106 |
| 不同语义联系 | 23 | 22 |
| `dbo` 外键 | 25 | 23 |
| `dbo` UNIQUE 约束 | 10 | 9 |

减少的两个外键是流水到采购明细的单列外键及流水到批次与采购明细的复合外键；批次到采购明细和流水到批次的外键保留。`InventoryBatch(BatchID, PurchaseItemID)` 只供原复合外键引用，含已有主键，是非最小超码；删除其 UNIQUE 约束不改变 `BatchID` 主键或 `(PurchaseItemID, SupplierBatchNo)` 候选码。销售/采购订单明细的组合候选码、支付成功的过滤唯一索引以及积分的订单顾客复合外键也保持不变。

目标库还用 `TR_InventoryBatch_PurchaseSourceImmutable` 保护历史：已有库存流水的批次不能改写采购明细来源。它是跨表更新规则，不增加 ER 实体或属性；对应负例见[第六周回归](../result/week6/README.md)。

完整属性语义以[第五周数据字典](week5/er-model.md)及[第六周字典差异](Week6-数据字典.md)共同核对。图由 [Render-Week6Er.cjs](../scripts/Render-Week6Er.cjs) 从上述源文件实际导出；数据库核对见[迁移结果](../result/week6/README.md)。
