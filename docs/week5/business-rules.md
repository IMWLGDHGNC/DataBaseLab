# 业务规则与实现映射

本清单区分业务要求与 v0.1 目前允许的数据。`A→B` 表示每个 A 对应多少 B，`B→A` 表示每个 B 对应多少 A；括号标明必须／可选参与。N 为不限数量。图按业务语义标注，不将已有样例恰好一条误判为 1:1。

## 联系基数与外码

| 编号 | 联系 | A→B 最小..最大 | B→A 最小..最大 | 数据库映射及边界 |
| --- | --- | --- | --- | --- |
| R01 | ProductCategory → Product（分类） | 0..N（可选） | 1..1（必须） | `Product.CategoryID` 外码非空。 |
| R02 | Supplier → PurchaseOrder（供货） | 0..N（可选） | 1..1（必须） | `PurchaseOrder.SupplierID` 外码非空。 |
| R03 | Employee → PurchaseOrder（创建） | 0..N（可选） | 1..1（必须） | `PurchaseOrder.CreatedBy` 外码非空。 |
| R04 | Employee → PurchaseOrder（审批） | 0..N（可选） | 0..1（可选） | `PurchaseOrder.ApprovedBy` 外码可空。未审批／未收货时可空；状态完成后 CHECK 要求相应员工和时间成对存在。 |
| R05 | Employee → PurchaseOrder（验收） | 0..N（可选） | 0..1（可选） | `PurchaseOrder.ReceivedBy` 外码可空。未审批／未收货时可空；状态完成后 CHECK 要求相应员工和时间成对存在。 |
| R06 | PurchaseOrder → PurchaseOrderItem（包含） | 1..N（必须） | 1..1（必须） | `PurchaseOrderItem.PurchaseOrderID` 外码非空。数据库仍允许父实体没有子行；业务最小 1 由事务／复核保证，见 Q01/Q03。 |
| R07 | Product → PurchaseOrderItem（被采购） | 0..N（可选） | 1..1（必须） | `PurchaseOrderItem.ProductID` 外码非空。 |
| R08 | PurchaseOrderItem → InventoryBatch（形成批次） | 0..N（可选） | 1..1（必须） | `InventoryBatch.PurchaseItemID` 外码非空。未收货采购明细可无批次；已收货时应至少一个，DDL 不保证存在性。 |
| R09 | Customer → SalesOrder（下单） | 0..N（可选） | 1..1（必须） | `SalesOrder.CustomerID` 外码非空。 |
| R10 | SalesOrder → SalesOrderItem（包含） | 1..N（必须） | 1..1（必须） | `SalesOrderItem.SalesOrderID` 外码非空。数据库仍允许父实体没有子行；业务最小 1 由事务／复核保证，见 Q01/Q03。 |
| R11 | Product → SalesOrderItem（被购买） | 0..N（可选） | 1..1（必须） | `SalesOrderItem.ProductID` 外码非空。 |
| R12 | SalesOrderItem → InventoryReservation（分配批次） | 1..N（必须） | 1..1（必须） | `InventoryReservation.SalesItemID` 外码非空。锁定成功才成单，每条已成立明细至少有一条历史锁定；取消、换锁、出库保留已释放／已转出库记录。有效锁定子集可以为零，待支付／待出库必须足量。DDL 不保证历史最小参与数，仍需业务事务及复核。 |
| R13 | InventoryBatch → InventoryReservation（被锁定） | 0..N（可选） | 1..1（必须） | `InventoryReservation.BatchID` 外码非空。 |
| R14 | InventoryBatch → InventoryMovement（发生变动） | 1..N（必须） | 1..1（必须） | `InventoryMovement.BatchID` 外码非空。数据库仍允许父实体没有子行；业务最小 1 由事务／复核保证，见 Q01/Q03。 |
| R15 | PurchaseOrderItem → InventoryMovement（采购入库来源） | 0..N（可选） | 0..1（可选） | `InventoryMovement.PurchaseItemID` 外码可空。来源是否必填由 MovementType 的 CHECK 条件决定。 |
| R16 | SalesOrderItem → InventoryMovement（销售出库来源） | 0..N（可选） | 0..1（可选） | `InventoryMovement.SalesItemID` 外码可空。来源是否必填由 MovementType 的 CHECK 条件决定。 |
| R17 | Employee → InventoryMovement（确认变动） | 0..N（可选） | 1..1（必须） | `InventoryMovement.OperatorID` 外码非空。 |
| R18 | SalesOrder → PaymentRecord（支付尝试） | 0..N（可选） | 1..1（必须） | `PaymentRecord.SalesOrderID` 外码非空。 |
| R19 | Customer → PointsMovement（获得积分） | 0..N（可选） | 1..1（必须） | `PointsMovement.CustomerID` 外码非空。 |
| R20 | SalesOrder → PointsMovement（赠分） | 0..1（可选） | 1..1（必须） | `PointsMovement.SalesOrderID` 外码非空。`UQ_PointsMovement_1` 限定至多一条；仅满足赠分条件时业务必须为 1。 |
| R21 | SalesOrder → OrderException（发生异常） | 0..N（可选） | 1..1（必须） | `OrderException.SalesOrderID` 外码非空。 |
| R22 | InventoryBatch → OrderException（关联异常） | 0..N（可选） | 0..1（可选） | `OrderException.BatchID` 外码可空。 |
| R23 | Employee → OrderException（登记或处理） | 0..N（可选） | 1..1（必须） | `OrderException.HandledBy` 外码非空。 |

R24：`FK_Movement_BatchPurchase` 把库存流水的 `(BatchID, PurchaseItemID)` 与同一批次的采购来源配对；采购入库必须有来源，出库／调整／报损来源为 NULL，不把复合外码误画成第二个批次实体。

R25：`FK_Points_OrderCustomer` 将赠分订单与该订单顾客配对，防止订单属于 C00 而赠分给 C01；它不保证该顾客当时已经是会员，也不保证该订单已完成。

## 多对多与实体取舍

- 采购订单与商品的 M:N 通过 `PurchaseOrderItem` 表示，联系属性为数量和历史采购价。现有组合 UNIQUE 限定一单一商品一行。
- 销售订单与商品的 M:N 通过 `SalesOrderItem` 表示，联系属性为数量和历史成交价。独立明细主码不意味着允许同商品重复行：现有 `(SalesOrderID, ProductID)` UNIQUE 仍禁止这种情况，见 Q02。
- 销售明细与库存批次的 M:N 通过 `InventoryReservation` 表示，数量、状态、起止时间是占用事件属性。组合不唯一，因为可能释放后重新锁定；`InventoryMovement` 保存后续实物变化，不能替代锁定实体。
- 商品与库存批次为间接 1:N：`Product → PurchaseOrderItem → InventoryBatch`。每个批次通过一条明细追溯唯一 SKU，不额外复制 ProductID。供应商与商品通过采购历史形成 M:N，但这不是预先定义的供货资格清单。
- 会员用 `Customer.IsMember / JoinedAt` 表示，当前无会员独有主档属性或独立生命周期，因此不强行拆出 1:1 会员表。普通购买仍有 CustomerID；不支持匿名无账号结账。员工岗位是业务属性，数据库角色是授权对象，当前二者无自动绑定。

## 数量、时间、状态与权限规则

| 编号 | 业务要求 | 当前数据库保证 | 仍依赖程序／复核的部分 |
| --- | --- | --- | --- |
| R26 | 正价格、正购买／采购数量；库存、积分余额非负 | 价格／数量／余额 CHECK；商品、类别、账号及成交单编号等非空约束 | SKU 组合是否适合真实商品编码仍需业务确认 |
| R27 | 整张采购／销售单至少一条明细；订单金额等于明细合计 | FK 只保证明细所属单存在；TotalAmount > 0 | 04-verify 检查销售合计和明细存在；采购最小参与未被既有复核覆盖，见本周探针 |
| R28 | 采购整单审批后验收，日期与状态一致 | PurchaseOrder_Rule1/2/3 检查员工时间成对、时间顺序与状态；批次日期 CHECK | 员工在职且岗位匹配、供应商合作、收到数量等于订货量；04-verify 检查收货数量和时间 |
| R29 | 现存量等于流水合计；有效锁定不超过现存量且商品相同 | OnHandQty >= 0；锁定数量 > 0；入库来源复合 FK；流水类型和正负号 CHECK | 04-verify 检查余额、锁定上限及 SKU 一致；任意写入与并发占用尚无受控事务入口 |
| R30 | 到期（含当天）／隔离／停售库存不可售，锁定不扣现存 | 库存视图按日期、质量状态与商品状态计算可售量 | 出库时再次检查日期和实物；锁定生命周期数量由 04-verify 检查；查询视图不会自动拒绝非法占用 |
| R31 | 每单至多一次成功支付；15 分钟内成功金额等于订单金额 | MockTransactionNo UNIQUE；UX_Payment_OneSuccess 过滤唯一索引；Amount > 0 | 04-verify 核对金额、时间和订单状态；回调／取消竞争及状态迁移需应用事务 |
| R32 | 完成订单才全量出库并结束有效锁定，普通取消仅限待支付 | SalesOrder 完成时间 CHECK；Reservation 状态／结束时间 CHECK | 04-verify 检查出库数量、完成时间和锁定生命周期；不检查旧状态到新状态的合法迁移 |
| R33 | 完成时为会员且满 1 元，按 FLOOR(实付金额) 赠分一次 | PointsMovement 单订单 UNIQUE、订单顾客复合 FK、正积分及向下取整 CHECK | 04-verify 核对会员资格、订单状态、金额、余额及应赠未赠；会员变更历史未独立保存 |
| R34 | 异常关联订单商品，解决时要有说明 | 订单／可选批次／经办人 FK；第四周 CK_OrderException_ResolutionNote | 04-verify 核对批次属于订单商品及登记时间；一条记录覆盖更新会损失处理历史 |
| R35 | 按岗位操作，顾客只访问自己的订单 | 第四周六个数据库角色按表／列／视图及受控过程授权；34 个正反例。CustomerPrincipal 绑定数据库用户与顾客，本人订单和会员积分按 USER_NAME() 过滤 | Employee.Position 不自动等于数据库角色；已有本人只读入口，应用认证、实际登录账号及顾客下单/支付写入入口仍待后续实现 |
| R36 | 历史成交价、收货信息保持当时事实 | DealUnitPrice、UnitCost 和订单收货字段分别保存历史快照 | 低权限角色受限，但管理员仍能改历史；后续应用封闭历史更新入口 |

数据库 CHECK 能检查本行表达式，FK 能检查引用与配对；跨行聚合、父实体必须有子行和状态迁移不会仅凭这些约束自动成立。SQL Server 约束语义参考 [Microsoft 文档](https://learn.microsoft.com/en-us/sql/relational-databases/tables/unique-constraints-and-check-constraints?view=sql-server-ver17)。实际验证见 [Week5](../Week5.md)。
