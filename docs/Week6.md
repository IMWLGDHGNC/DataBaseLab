# Week6 - 函数依赖、规范化与 v0.1 迁移分析

依据[第二阶段第六周安排](第五周任务讲解.md)和第六周讲解原文，以[第五周已核对的 ER 模型](Week5.md)、完整字典与问题清单为直接输入。第五周保留的 v0.1 结构是本周迁移来源。

## 1. 本周目标与项目基线

本周以线上零食网店的 SQL Server v0.1 为审查对象。现有设计从商品类别、采购、批次库存到销售、支付和积分，覆盖 15 张业务表；README 记录的基线是 46 行相互关联的样例数据。任务不是为了“多拆几张表”，而是用业务规则说明当前函数依赖，检查异常和范式，再决定哪些结构应改、哪些应保留。任何迁移都应在 v0.1 副本上进行，并证明订单、销售、库存和权限的业务含义未变。

建议保留现有业务表和多数关系。Week2 已按对象拆分类别、商品、供应商、员工、顾客、订单明细、批次、库存锁定、库存流水、支付、积分和异常记录；订单明细分别保存采购成本与历史成交价，批次也不重复保存商品编号。这些设计有明确的业务理由。当前最值得评审的冗余字段是 `InventoryMovement.PurchaseItemID`：批次已通过 `InventoryBatch.PurchaseItemID` 指向采购明细，流水再存一次来源属于条件性冗余。实际 Week3 DDL 已有 `FK_Movement_BatchPurchase(BatchID, PurchaseItemID)` 复合外键保证两处来源一致，因此不是当前未受约束的数据错误；移除后可缩减维护字段和复合键。

## 2. 分析口径

下列依赖来自 Week1/Week2 写明的业务规则及 Week3 已实现的键约束，不是从有限样例中推测出来的。记法 `X → Y` 表示在这些业务规则下，X 唯一决定 Y。主码和 UNIQUE 候选码都应检查；对条件唯一性（例如每笔订单至多一笔成功支付）要注明条件，不能误写成整列全局唯一。

“范式合格”不等于没有任何冗余。`SalesOrder.TotalAmount`、`InventoryBatch.OnHandQty` 和 `Customer.PointsBalance` 是跨表汇总或余额缓存，属于为查询/业务操作保留的冗余状态；它们不应误称为普通传递依赖，但必须由事务或受控写入口维护，并用查询与流水核对。

## 3. 逐表码、依赖与处理结论

| 表 | 候选码 | 主要函数依赖 | 范式与处理结论 |
| --- | --- | --- | --- |
| `ProductCategory` | `CategoryID`；`CategoryName` | `CategoryID → CategoryName, Description`；按当前“类别名称唯一”规则，`CategoryName → CategoryID, Description` | 单值字段；非主属性依赖整个候选码，无传递依赖。保留类别独立表，避免商品重复存类别名称。 |
| `Product` | `ProductID`；`(Brand, ProductName, Specification, SaleUnit)` | `ProductID → CategoryID, ProductName, Brand, Specification, SaleUnit, CurrentPrice, SaleStatus, ReorderLevel`；组合候选码决定同一组属性 | 当前结构满足 3NF。保留组合唯一约束的前提是该组合确实唯一识别 SKU；若业务允许相同组合区分口味/版本，必须修订规则与候选码。历史价格在 `SalesOrderItem`，不回写当前价。 |
| `Supplier` | `SupplierID` | `SupplierID → SupplierName, ContactName, ContactPhone, CooperationStatus` | 满足 3NF。名称可重名或变更，不把名称当候选码；保留。 |
| `Employee` | `EmployeeID` | `EmployeeID → EmployeeName, Position, HireDate, MonthlySalary, ContactPhone, ActiveStatus` | 满足 3NF。岗位或姓名不能决定员工编号；经营岗位不等于数据库角色。保留。 |
| `Customer` | `CustomerID`；`AccountName` | `CustomerID → AccountName, CustomerName, ContactPhone, IsMember, JoinedAt, PointsBalance, ActiveStatus`；`AccountName → 其余顾客属性` | 单表属性满足 3NF。会员字段受 CHECK 规则约束；`PointsBalance` 是积分流水的缓存余额，不是普通属性依赖导致的范式问题。保留但在事务与回归中核对余额等于积分变动合计。 |
| `PurchaseOrder` | `PurchaseOrderID` | `PurchaseOrderID → SupplierID, CreatedBy, CreatedAt, ApprovedBy, ApprovedAt, ReceivedBy, ReceivedAt, OrderStatus, RejectionReason` | 满足 3NF。审批人与验收人为员工外键；“该员工是否具备相应岗位”是业务授权检查，不由外键证明。保留。 |
| `PurchaseOrderItem` | `PurchaseItemID`；`(PurchaseOrderID, ProductID)` | `PurchaseItemID → PurchaseOrderID, ProductID, OrderedQty, UnitCost`；组合候选码也决定其余属性 | 满足 3NF。采购单头不重复保存商品和成本；明细保留本次成交成本。保留。 |
| `InventoryBatch` | `BatchID`；`(PurchaseItemID, SupplierBatchNo)` | `BatchID → PurchaseItemID, SupplierBatchNo, ProductionDate, ExpiryDate, ReceivedAt, OnHandQty, BatchStatus`；组合候选码也决定其余属性 | 满足 3NF。商品可从采购明细追溯，不另存 `ProductID`。`OnHandQty` 是库存流水的当前余额缓存，须核对。保留批次结构。 |
| `SalesOrder` | `SalesOrderID` | `SalesOrderID → CustomerID, CreatedAt, OrderStatus, CompletedAt, RecipientName, RecipientPhone, ShippingAddress, TotalAmount` | 单表属性满足 3NF。收货信息是下单时快照，不等于顾客当前联系方式。`TotalAmount` 是明细金额汇总缓存，保留需由受控事务维护并与明细重算比对。 |
| `SalesOrderItem` | `SalesItemID`；`(SalesOrderID, ProductID)` | `SalesItemID → SalesOrderID, ProductID, Quantity, DealUnitPrice`；组合候选码也决定其余属性 | 满足 3NF。历史成交价属于该次订单商品，不由商品当前售价决定；保留。 |
| `InventoryReservation` | `ReservationID` | `ReservationID → SalesItemID, BatchID, ReservedQty, ReservationStatus, ReservedAt, EndedAt` | 满足 3NF。同一明细可跨批次、换批并保留历史，因此不对 `SalesItemID` 设唯一；保留。需用业务检查保证明细商品与批次商品一致。 |
| `InventoryMovement` | `MovementID` | v0.1：`MovementID → BatchID, MovementType, QuantityDelta, PurchaseItemID, SalesItemID, Reason, OperatorID, OccurredAt`；采购入库子集中，`BatchID → PurchaseItemID` | 单表普通非主属性无部分/传递依赖；采购入库的 `PurchaseItemID` 可经批次表还原。Week3 已用 `FK_Movement_BatchPurchase` 复合 FK 保证两处一致。建议 v1.0 删除重复列及关联约束，以批次连接追溯采购明细；其他字段保留。 |
| `PaymentRecord` | `PaymentID`；`MockTransactionNo` | `PaymentID → SalesOrderID, MockTransactionNo, Amount, PaymentStatus, ResultAt`；`MockTransactionNo → 其余支付记录属性` | 满足 3NF。订单可保留失败尝试，因此 `SalesOrderID` 不能全局唯一；只要求成功支付每单至多一笔，应由条件唯一约束或受控事务实现。保留。 |
| `PointsMovement` | `PointsMovementID`；`SalesOrderID`（本阶段一单至多赠分一次） | `PointsMovementID → CustomerID, SalesOrderID, PointsDelta, BasedAmount, Reason, OccurredAt`；按本阶段规则，`SalesOrderID → 其余积分变动属性` | 满足 3NF。积分记录保存赠分事实；顾客当前余额是汇总缓存。保留，并核对获赠顾客与订单顾客一致。 |
| `OrderException` | `ExceptionID` | `ExceptionID → SalesOrderID, BatchID, ReasonCode, Description, HandlingStatus, HandlingNote, HandledBy, RecordedAt` | 满足 3NF。一张订单可有多条异常检查记录，订单号不唯一；保留。 |

### 候选码与业务假设

- `Product` 的组合候选码依赖 Week2 已确认的业务假设“品牌、名称、规格、销售单位组合唯一识别 SKU”。规范化审查应再次说明该规则的范围；如果规格字段无法区分口味或包装版本，不能仅靠现有样例中没有重复值来证明唯一性。
- `ProductCategory.CategoryName` 的唯一性来自现有 UNIQUE 约束。若类别允许同名，应撤销该候选码假设，`CategoryID` 仍是主候选码。
- `PaymentRecord` 的订单号仅对成功支付记录条件唯一；`PointsMovement.SalesOrderID` 在当前“每单最多赠分一次”的规则下唯一。这两条应按条件/业务范围表达，不推广到超出项目范围的功能。

## 4. 异常检查与冗余取舍

### 逐表插入、修改和删除异常

以下判断结合第 3 节的全部候选码和业务依赖。外键要求先存在被引用对象属于事实关联；不能仅因不能插入孤儿行就称为规范化插入异常。跨表缓存、整单参与和历史保留的限制另行注明，范式合格不代表这些业务约束已经由 DDL 全部实现。例子中的编号均来自模拟样例。

| 表 | 插入异常及避免方式 | 修改异常及避免方式 | 删除异常及避免方式 |
| --- | --- | --- | --- |
| `ProductCategory` | 类别可先于商品建立，不必虚造商品才能登记类别；空类别合法。 | 类别改名只改一行，例如 CAT01 的名称不在 S01 重复存储。 | 删除最后一个商品不删除类别事实；仍有商品引用时 FK 阻止直接删类别。 |
| `Product` | 新 SKU 只需已有类别，不必同时有采购、库存或销售；订单属性不混入商品行。 | S01 当前价变更不改 SI00 历史成交价；品牌等 SKU 属性集中维护，组合候选码防止重复 SKU。 | 删除订单明细不丢商品资料；已被采购或销售引用的商品不可直接删除，业务停售保留历史。 |
| `Supplier` | 可先登记供应商，再建立采购单；无需虚造采购记录。 | 联系方式集中在供应商一行，无需逐张采购单改联系人；名称不被误当唯一标识。 | 删除最后一张采购单不删除供应商事实；有采购引用时 FK 阻止删供应商，停用用状态表示。 |
| `Employee` | 可先登记员工，不依赖其已经经办单据；岗位不决定统一工资，工资是员工属性。 | 员工岗位、工资等只改员工行，经办关系继续使用稳定编号；岗位权限仍需应用核对。 | 删除某单据不丢员工资料；历史经办引用阻止直接删员工，离职通过 ActiveStatus 保留引用。 |
| `Customer` | 无订单也能登记顾客；普通顾客以零余额、无入会时间建立，避免为开户虚造订单。 | 当前联系方式与订单收货快照语义不同；PointsBalance 是缓存，若只改余额仍会不同步，赠分事务需同步流水。 | 删除订单不丢账户事实；有订单/积分引用不能直接删账户。删除积分流水会使缓存失配，历史应保留。 |
| `PurchaseOrder` | 头与明细拆开避免多商品导致头属性重复；DDL 仍允许空单，持久化完整采购单须由后续整单事务保证。 | PO00 审批状态与时间只存单头，不在每条 PDI 明细重复；审批岗位与时间状态另受业务检查。 | 删除一条明细不丢供应商/员工资料；删最后一条会留下空单，这是参与约束缺口，不能声称 FK 已解决。 |
| `PurchaseOrderItem` | 采购明细需已有采购单和商品，不需要先有库存批次；本次 UnitCost 独立于商品当前售价。 | 修改某采购的约定数量/成本只涉及该明细；一单同 SKU 合并由组合候选码保证，验收后事实须受控保留。 | 删除采购明细不删除商品或采购单资料；已有批次引用时 FK 拒绝。最后一条明细删除仍需防止空单。 |
| `InventoryBatch` | 批次由已有采购明细建立，不重复写商品名称/规格；初始库存与入库流水应在同一业务事务建立。 | 商品由采购明细追溯；OnHandQty 与流水需同步。v1.0 有流水后禁止改采购来源，避免历史被重解释。 | 删除流水不丢采购资料，但会破坏现存量对账；引用批次的锁定/流水阻止删批次，历史批次应保留。 |
| `SalesOrder` | 单头不混入单个商品，支持多条明细；完整订单还须同时建立明细与锁定，当前 FK 不保证非空订单。 | 下单快照保留当时收货事实；TotalAmount 与明细必须事务同步，不能仅用“满足 3NF”排除缓存修改异常。 | 删除一条明细不丢顾客事实；最后一条删除会留下空单/错误总额，受控流程应取消订单而保留历史。 |
| `SalesOrderItem` | 需已有订单和商品，无需商品当前价等于成交价；组合候选码符合当前一单同 SKU 合并约定。 | SI03 的数量和历史单价不能仅因乘积相同就任意替换；应保持事实并同步订单总额及锁定。 | 删除明细不丢商品定义或订单收货快照；已有锁定/流水引用时 FK 阻止，历史成交事实应保留。 |
| `InventoryReservation` | 明细与批次可多次锁定并保留历史，无需将同一组合错误设为唯一；商品配对和可售量由业务入口核对。 | 数量/状态只维护本次锁定，批次属性通过关联读取；超量和状态生命周期属于跨表规则，不能由现有本行 CHECK 完全保证。 | 删除锁定不删除批次和销售明细，但会丢履约历史；释放通过状态/EndedAt 记录，避免直接删除活动锁定。 |
| `InventoryMovement` | v0.1 入库要重复提供批次已确定的采购来源；v1.0 只提供 BatchID，连接还原来源，省去重复输入。 | v0.1 两处采购来源受复合 FK 限制；v1.0 来源只存批次并冻结已有流水批次的来源。数量变动仍需同步库存缓存。 | 删除最后一条流水不会删掉采购/批次事实，但会破坏余额及审计历史；正常业务用调整流水并同步余额，不抹去旧流水。 |
| `PaymentRecord` | 已有订单可记录多次失败尝试，不需虚造另一订单；MockTransactionNo 唯一防重，成功记录仅条件唯一。 | 某尝试结果/金额只在该记录保存；金额与订单、支付时间和状态的对应仍需受控支付流程核对，当前正金额 CHECK 不充分。 | 删除一次失败尝试不会删除订单或其他支付；成功支付事实应保留，直接删除会破坏订单状态与支付事实一致性。 |
| `PointsMovement` | 完成的会员订单可建立赠分记录，SalesOrderID 候选码保证当前每单最多一次；余额需同事务更新。 | 赠分金额/积分属于该次事实，余额属于合计缓存；改一侧会失配，会员资格/订单完成条件仍需业务入口核对。 | 删除赠分记录不丢顾客和订单资料，但会丢赠分事实并使余额失配；历史赠分保留，后续逆向业务须另定义事件。 |
| `OrderException` | 已有订单可记录异常，BatchID 可空，不要求所有异常都有批次；订单资料不重复存入异常行。 | 原因及当前处理状态按 ExceptionID 维护；多次覆盖 HandlingNote 会丢处理历史，这是审计范围取舍，不能误称已实现事件历史。 | 删除最后一条异常不会删除订单或批次资料；会丢异常审计事实，业务应记录解决状态，保留异常记录。 |

### 已通过拆表避免的异常

- **类别名称修改异常：**若类别名称重复保存在多个商品行中，改名可能只改到一部分。当前 `Product` 只存 `CategoryID`，名称集中在 `ProductCategory`，一次更新即可。
- **采购成本和历史售价被覆盖：**若只保存当前商品价格，调价会改写历史成交含义。当前采购成本保存在 `PurchaseOrderItem.UnitCost`，销售成交价保存在 `SalesOrderItem.DealUnitPrice`，商品调价不应改变历史记录。
- **批次商品信息重复：**批次经采购明细追溯商品，避免每批重复存商品名、规格及商品类别名称。
- **订单主从混存：**采购/销售订单头与明细分开，避免一个订单多商品时重复订单信息；复合唯一约束也防止同一订单同一商品拆成重复行。

### 需要明确维护的有意冗余

- `SalesOrder.TotalAmount` 应等于该订单全部 `Quantity × DealUnitPrice` 之和。若明细变化而主表金额未同步，会出现修改异常；订单建立/修改必须在同一事务重算或校验。回归时逐单比对。
- `InventoryBatch.OnHandQty` 应等于该批次入库、出库、盘点和报损流水的净变化。若只写流水或只改余额，会让库存查询失真；必须通过受控库存事务维护，并按批次对账。
- `Customer.PointsBalance` 应等于积分变动合计（并满足普通顾客余额为零）。若赠分记录写入而余额未更新，或反之，将造成账户不一致；完成订单和赠分应原子提交，并按顾客核对。
- `InventoryMovement.PurchaseItemID` 与 `InventoryBatch.PurchaseItemID` 对同一采购入库行重复表示来源。当前 DDL 用 `FK_Movement_BatchPurchase(BatchID, PurchaseItemID)` 复合外键阻止两者错配；删去流水中的重复来源字段后，采购来源仍可从批次稳定连接得到，字段与支撑复合 FK 的冗余超级键可一并移除。

## 5. 重构方案与理论说明

### 建议目标模式

保留现有 15 张业务表、主外键、候选码和历史价格设计；对 `InventoryMovement` 移除 `PurchaseItemID` 冗余列。v0.1 的复合外键已阻止两列不一致；迁移仍先检查每条 `MovementType='采购入库'` 的流水是否满足：其 `BatchID` 对应批次的 `PurchaseItemID` 与流水当前 `PurchaseItemID` 相等；不一致时中止迁移并人工查因，不自动猜测修复。其他类型的流水应保持 `PurchaseItemID IS NULL`。

目标 `InventoryMovement` 属性为：`MovementID`、`BatchID`、`MovementType`、`QuantityDelta`、`SalesItemID`、`Reason`、`OperatorID`、`OccurredAt`。采购来源按 `InventoryMovement.BatchID → InventoryBatch.PurchaseItemID → PurchaseOrderItem` 查询；采购入库仍由流水类型与来源批次共同表达。

### 无损连接与依赖保持

在已验证 `InventoryMovement.BatchID` 外键指向 `InventoryBatch.BatchID` 的前提下，采购来源由每个批次唯一确定。把来源存储在流水和批次两处改为只在批次保存，查询时按 `BatchID` 连接可还原来源，不丢失业务信息；连接依据是批次主键唯一性，而不是有限样例碰巧对应。其他 14 张表关系不拆分，因此无需额外分解。原有键依赖由各表主键/候选键和唯一约束继续保证；被移除的重复值由 `InventoryBatch` 中 `BatchID → PurchaseItemID` 的依赖保持。为防止日后改写批次来源导致历史流水含义变化，目标库增加触发器：已有流水的批次不可更换 `PurchaseItemID`，回归要求错误 51620。

如果人工核验认为库存流水必须独立保存采购来源作为不可变审计快照，则可以选择保留该列，但必须在写入入口检查与批次采购来源相同，并解释快照与当前来源的区别。本项目当前模型没有采购来源变更语义，默认建议删除重复列。

## 6. migration.sql 计划

1. 使用 `scripts/Run-Week6.ps1` 在新的隔离数据库 `DataBaseLab_Week6_<时间戳>` 重建 v0.1 基线并迁移；脚本不会覆盖同名库。服务器端应在单独的新数据库副本执行，不能直接对正式库试跑。原始日志先保存在被忽略的 `output/week6/`，检查脱敏后才将公开副本放入 `result/week6/`。
2. 执行前提写入脚本头部：SQL Server 版本、源结构版本、目标版本、运行账号权限及预期初始状态；推荐只允许在 Week4 v0.1 结构上运行一次。
3. DDL 事务开始前做完整性预检并拍摄库存流水快照：采购入库的批次来源与流水来源不匹配为 0；非采购入库的 `PurchaseItemID` 非空为 0；基线表无意外缺表或关键约束失效。事务内创建独立的 `week6_baseline` 审核 schema，保存本库迁移前三个实际视图、固定日期库存查询及采集日期；这些辅助表不计入 15 张业务表或 ER 实体。
4. 通过预检后，在一个事务内移除 `CK_InventoryMovement_Rule1`、`FK_Movement_BatchPurchase`、`FK_InventoryMovement_PurchaseItemID`、`InventoryBatch.UQ_InventoryBatch_2`，删除 `InventoryMovement.PurchaseItemID`，重建保留类型/数量/销售来源规则的 CHECK，并增加有流水批次的采购来源不可更换触发器。事务提交前双向比较库存流水与来源快照；其余表、业务键和样例数据不动。
5. 事务提交后输出迁移版本、表行数和校验结果。预检失败或任一步骤失败则回滚，并保留原库和诊断信息。脚本不要求可重复执行，但要明确再次运行需从未迁移的 v0.1 副本开始。
6. 若最终复核决定不改结构，也提交仅检查基线和来源一致性的 migration.sql，并记录“结构无需变更”的结论；不能空缺迁移说明。

数据冲突处理原则：来源不一致、重复候选码、关键外键孤儿行均应中止迁移；先记录涉及的键与原因，再由人工决定修复。不要自动选一侧覆盖另一侧。

## 7. regression.sql 与验收记录

回归脚本记录“迁移前基准、预期、迁移后实际、差异解释”。`migration.sql` 将当次库的订单明细、逐商品销量、当前库存视图和 2026-09-18 固定日期库存查询保存到 `week6_baseline`；回归对实际查询做双向 EXCEPT 和行数比较，再按业务键输出 BeforeValue、ExpectedValue、ActualValue。预期是每行等于迁移前，不以总额相等代替明细保持。当前库存视图按当天日期运行，因此完整迁移与回归须在同一日执行；跨日回归会明确中止，需从新的 v0.1 副本重新开始。固定日期库存口径一直为 2026-09-18。

| 检查项 | 已记录基线 / 预期 | 迁移后应验证 |
| --- | --- | --- |
| 业务表及样例 | 15 表、46 行 | 表行数总体不变；字段重构不改变业务实体和样例记录数 |
| 完成销售 | 15 件、64.50 元；只统计已完成订单，ST02 待出库不计入 | 三类统计口径与迁移前逐项一致 |
| 订单明细 | 订单、商品、数量、成交单价及金额 | 键映射正确；逐单 `TotalAmount` 与明细金额核对 |
| 库存 | 批次现存、有效锁定、可售量与状态 | 批次余额与库存流水净额一致；有效锁定不超过现存量；到期/隔离/停售规则不变 |
| 采购入库来源 | 批次可追溯采购明细；迁移前重复来源一致 | 改从批次连接恢复来源，迁移前后逐行对应且入库数量一致；历史批次来源改写被 51620 拒绝 |
| 完整性 | 非法外键、非正数量/金额等被拒绝 | 原有约束继续生效；迁移前后合法数据保持可读 |
| 权限 | Week4 最新结果记录 34 项角色正反例 | 在迁移前后分别按当前 `role.sql` 重新执行，非法访问与越权操作仍失败 |
| 积分 | 余额与积分流水一致；只对完成的会员订单赠分 | 顾客余额、积分变动及对应订单映射一致，无重复赠分 |

回归包含合法商品写入，以及库存流水四种合法类型的回滚案例；十一项流水负例覆盖零数量、数量符号错误和销售来源缺失/多余，均要求错误 547 明确来自 `CK_InventoryMovement_Rule1`。同时检查 CHECK/FK 存在、启用和受信状态，核对非法外键、零锁定量、历史来源改写与角色边界。审核快照不向顾客角色授权，直接读取须返回 229。若因保留字段减少，`InventoryMovement` 行数应不变；变化的是每行存储的重复属性，不应改变任何库存流水的事实含义。

## 8. 本周工作顺序与提交物

1. 从第五周完整字典、Week2 字典和 Week3 DDL 核对“表—字段—主码/其他候选码—外码”清单，并对照本周更新的目标 ER 图。
2. 按本文件逐表核实业务依赖、异常和范式；把 `InventoryMovement.PurchaseItemID` 作为主要重构审查点，把余额/总额缓存作为明确的冗余维护决策。
3. 经复核后更新数据字典和 ER 图，再确定目标模式；只有此后才编写 `migration.sql` 与 `regression.sql`。
4. 在隔离 v0.1 样例库运行迁移和回归，保存 SQL 输出与迁移前后结果；更新项目 README 的运行顺序、版本和复现步骤。
5. 将设计思路、实验步骤、函数依赖与分解依据、迁移结果和回归结论并入阶段报告；在 `ai_log.md` 记录 AI 建议、实际采纳或修改项、人工核对和运行证据。

### 展示时要讲清楚

- `ProductID` 为什么能决定当前商品属性，而 `ProductID` 不能决定历史订单的 `DealUnitPrice`。
- 为什么拆分类别、订单明细、库存批次和积分流水能避免重复修改；为什么合理表不需要为了演示范式再拆。
- `TotalAmount`、`OnHandQty` 和 `PointsBalance` 是有意缓存，分别由什么明细/流水维护，如何检测失配。
- 库存流水采购来源如何由批次可靠还原；若保留冗余列，如何阻止与批次来源不一致。
- 迁移前后哪些业务结果逐项相同，行数或列数变化如何解释，失败时如何恢复。

## 9. 脚本与结果状态

- 迁移脚本：[`sql/week6/migration.sql`](../sql/week6/migration.sql)。仅接受本周隔离基线库名，检查表数、行数、来源一致性和余额缓存后，在一个事务中做字段与约束调整。
- 回归脚本：[`sql/week6/regression.sql`](../sql/week6/regression.sql)。核对 15 表 46 行、已完成销售 15 件/64.50 元、订单金额、库存和积分对账、合法写入回滚、非法外键/数量/来源改写拒绝及角色边界。
- 自动执行入口：Windows LocalDB 使用[`Run-Week6.ps1`](../scripts/Run-Week6.ps1)，授权的 Linux 服务器使用[`Run-Week6-Server.sh`](../scripts/Run-Week6-Server.sh)。原始日志先放入被忽略的 `output/week6/`，核查后的实际输出见[`result/week6/`](../result/week6/README.md)。
- 2026-10-10 初版已在课程服务器现有 SQL Server 2022 容器中新建独立测试库并实际执行：第五周模型核对、迁移、角色回归和第六周回归均通过；初版未运行 Windows LocalDB。后续 review 修复改用独立 LocalDB 样例库验证，见下文及最新结果索引。

### 课程服务器执行方式

服务器步骤遵循[`服务器 SQL 环境`](服务器SQL环境.md)：通过私密渠道取得连接方式，不能把地址、用户名或密码写进仓库。将本周文件放入已授权目录，并设置现有 SQL Server 容器的私有 `DB_CONTAINER` 环境变量后，运行[`Run-Week6-Server.sh`](../scripts/Run-Week6-Server.sh)。脚本以 `sqlcmd -I` 新建独立 `DataBaseLab_Week6_<时间戳>` 库，从第三、四周重建原样例；迁移前先运行第四周权限脚本、第五周目录及边界探针和原样例复核，再执行迁移、权限回归及第六周回归。不要运行使用 LocalDB 文件路径的 `week3/00-create-database.sql`，也不要指向正式 `DataBaseLab_Week4`。完整原始输出留在被忽略的 `output/week6/`，经内容检查后才复制可公开版本到 `result/week6/`。

## 10. 当前结论与人工复核

基于 Week2 关系模式和 Week3/Week4 项目说明，15 表整体已经按业务对象拆分，未发现明显的 1NF 问题或普遍的主码部分依赖、传递依赖。建议保留主体结构，不做为规范化而规范化的拆表。优先评估库存流水中可由批次还原的采购明细编号；保留的三个汇总/余额字段通过事务维护并回归对账。此结论是对当前文档和 SQL 定义的设计分析，最终迁移决定应在组员复核业务规则、ER 图和当前数据库结构后确定。

当前分析、目标 ER 图和数据字典修订分别见本文件、[`Week6-ER.md`](Week6-ER.md) 与 [`Week6-数据字典.md`](Week6-数据字典.md)。[实际服务器运行记录](../result/week6/README.md)证明独立样例库迁移及回归通过；这些是自动执行结果，不等于组员逐项人工验收，也不能推断正式库已迁移。

## 11. 2026-10-10 独立服务器实测

在课程服务器现有 SQL Server 2022 Docker 容器里新建 `DataBaseLab_Week6_20261010113646`。按第三、四周原脚本重建后先执行 `role.sql` 和第五周 `verify-er.sql`，得到 `VERIFY_PASS 15 46`、`ROLE_PASS 34`、`CATALOG_PASS`（107 属性、25 外键）、`ER_BOUNDARY_PASS 9`。迁移返回 `W6_MIGRATION_PASS`；逐行快照双向比对确认 6 条库存流水及其采购来源可还原。

迁移后目录为 106 属性、23 外键、9 个 UNIQUE 约束；再次 `ROLE_PASS 34`。回归得到已完成销售 15 件、64.50 元，订单/库存/积分对账和合法、非法、越权写入结果均符合预期；改写已有流水批次的采购来源返回 51620，最终 `W6_REGRESSION_PASS` 与 `WEEK6_SERVER_PASS`。完整输出见[结果目录](../result/week6/README.md)。

服务器 `sqlcmd` 建表需要 `-I` 启用 `QUOTED_IDENTIFIER`；首次未带该选项的独立库在建表时停止，随后换全新库完成整轮验证。失败的空库经确认无业务表后已清理；成功测试库保留供复核，正式库没有参与迁移。

## 12. 2026-10-10 review 修复验证

修复三项审核发现：为迁移重建的流水 CHECK 增加直接正反例；保存迁移前业务查询并在回归中逐行比较；补齐 15 表的插入/修改/删除异常说明。新增 [Test-Week6Validation.ps1](../scripts/Test-Week6Validation.ps1) 检查回归能否拒绝九项故意错误，包括缺失/停用/不受信 CHECK、放宽零盘点数量、全零销量视图、总金额不变但数量/单价变化的待出库明细、错误库存/订单视图和缺失业务快照。

Windows 复现命令如下，在仓库根目录选择新的测试库名：

```powershell
$db = 'DataBaseLab_Week6_Test' + (Get-Date -Format 'yyyyMMddHHmmss')
powershell.exe -NoProfile -File .\scripts\Run-Week6.ps1 -Database $db
powershell.exe -NoProfile -File .\scripts\Test-Week6Validation.ps1 -Database $db
```

检查器回归只接受带 Fix/Review/Test 前缀的专用 Week6 样例库，每项错误恢复后重新连接，最终比较业务表、审核快照和权限映射的全部数据摘要，并再次运行完整回归。原始 transcript 和结构化证据先保存于被忽略的 `output/week6/`；公开结果见 [review 修复验证](../result/week6/review-validation-20261010.md)。本次结果属于自动验证；组员人工验收和正式库迁移另行记录。旧服务器证据对应修复前版本，不能当作新快照和检查器已在服务器执行的证明。
