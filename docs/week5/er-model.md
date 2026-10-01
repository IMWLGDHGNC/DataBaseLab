# v0.1 实体与数据字典

以 `667259d` 的第三周 DDL、第四周新增 CHECK 及第一、二周业务约定为依据。15 张表映射为 15 个实体或关联／事件实体，共 107 个属性；没有新增业务表。类型、空值和标识以实际 DDL 为准；默认值与完整 CHECK 表达式继续见 [Week2 字典](../Week2.md) 和 [01-schema.sql](../../sql/week3/01-schema.sql)。

2026-10-01 同步 `main`（`73e9334`）后，15 张业务表及其字段不变。新增的 `customer_security.CustomerPrincipal` 属于权限辅助结构：`PrincipalName` 为主键，`CustomerID` 唯一并引用顾客；由管理员维护数据库用户到顾客的绑定，供本人订单/积分过程使用。当前四张 ER 图限定为业务模型，辅助表在此单独说明，验证脚本对业务和辅助目录分别计数。

## 标识与图形约定

所有实体以独立编号为主码。PK 本身属于候选码，下面另列其他最小候选码。`UK` 只标单属性候选码；组合候选码整体列在实体说明中，不表示其中每个属性都独立唯一。`InventoryBatch(BatchID, PurchaseItemID)` 和 `SalesOrder(SalesOrderID, CustomerID)` 含已有主码，属于供复合外码引用的超码，不能列为新的最小候选码。

使用 Mermaid 乌鸦脚，端点 `||` 为 1..1、`o|`／`|o` 为 0..1、`o{` 为 0..N、`|{` 为 1..N。虚线 `..` 表示当前关系模式中父键不参与子实体的独立主码；是否必须参与由端点表示。所有图采用同一业务基数，数据库尚未保证的最小参与数见[规则清单](business-rules.md)。`DECIMAL(10_2)` 在图里等价于 SQL 的 `DECIMAL(10,2)`；注释注明 NULL 与 NOT_NULL。记法依据 [Mermaid 官方文档](https://mermaid.js.org/syntax/entityRelationshipDiagram.html)。

销售明细与历史锁定为 1:N 且明细必须参与：锁定成功才建立订单；释放、换锁、出库只改变事件状态，保留历史。有效锁定子集的数量与参与条件另按订单状态判断。2026-10-01 review 修正了完整图和库存分区图中的这一最小基数。

## 图与源文件

完整图包含所有属性和 23 个不同语义的联系；两条复合外码是已有联系的配对限制，见规则 R24、R25。完整 SVG 可缩放查看，分区图用于演示。分区重复出现的同名实体是同一个实体，不是新增表。

| 图 | 可编辑源文件 | 可缩放图 | PNG 图 |
| --- | --- | --- | --- |
| er-v0.1 | [er-v0.1.mmd](er-v0.1.mmd) | [SVG](../../result/week5/er-v0.1.svg) | [PNG](../../result/week5/er-v0.1.png) |
| er-purchase | [er-purchase.mmd](er-purchase.mmd) | [SVG](../../result/week5/er-purchase.svg) | [PNG](../../result/week5/er-purchase.png) |
| er-sales | [er-sales.mmd](er-sales.mmd) | [SVG](../../result/week5/er-sales.svg) | [PNG](../../result/week5/er-sales.png) |
| er-stock | [er-stock.mmd](er-stock.mmd) | [SVG](../../result/week5/er-stock.svg) | [PNG](../../result/week5/er-stock.png) |

## 实体清单与属性

### 商品类别 ProductCategory

一类经营分类；类别可先于商品登记，独立维护分类名称。

主码：`CategoryID`。其他候选码：`CategoryName`。
外码：无。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| CategoryID | VARCHAR(12) | 否 | PK | 类别标识 |
| CategoryName | NVARCHAR(40) | 否 | 候选码组成 | 展示与统计用类别名称 |
| Description | NVARCHAR(200) | 是 | — | 类别边界说明 |

### 商品 SKU Product

一种品牌、名称、规格、销售单位组合；独立维护当前售价与在售状态。

主码：`ProductID`。其他候选码：`Brand, ProductName, Specification, SaleUnit`。
外码：`CategoryID` → `ProductCategory`.`CategoryID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| ProductID | VARCHAR(12) | 否 | PK | 独立销售 SKU 标识 |
| CategoryID | VARCHAR(12) | 否 | FK → ProductCategory | 商品类别 |
| ProductName | NVARCHAR(100) | 否 | 候选码组成 | 商品销售名称 |
| Brand | NVARCHAR(60) | 否 | 候选码组成 | 商品品牌 |
| Specification | NVARCHAR(60) | 否 | 候选码组成 | 最小销售单位对应的净含量或包装规格 |
| SaleUnit | NVARCHAR(10) | 否 | 候选码组成 | 库存和订单数量的计量单位 |
| CurrentPrice | DECIMAL(10,2) | 否 | — | 当前售价；历史成交价另存于销售明细 |
| SaleStatus | NVARCHAR(10) | 否 | — | 能否接受新订单 |
| ReorderLevel | INT | 否 | — | 人工补货预警阈值，按最小销售单位计 |

### 供应商 Supplier

一个供货主体；独立维护联系方式及合作状态，名称不保证唯一。

主码：`SupplierID`。其他候选码：无额外已实现候选码。
外码：无。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| SupplierID | VARCHAR(12) | 否 | PK | 供应商稳定标识 |
| SupplierName | NVARCHAR(100) | 否 | — | 供货方名称 |
| ContactName | NVARCHAR(40) | 是 | — | 采购沟通联系人 |
| ContactPhone | VARCHAR(20) | 是 | — | 联系方式，不参与数值计算 |
| CooperationStatus | NVARCHAR(10) | 否 | — | 能否新建采购订单 |

### 员工 Employee

一位经办员工；独立保存岗位、在职状态与历史责任引用。

主码：`EmployeeID`。其他候选码：无额外已实现候选码。
外码：无。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| EmployeeID | VARCHAR(12) | 否 | PK | 员工稳定标识 |
| EmployeeName | NVARCHAR(40) | 否 | — | 员工显示名 |
| Position | NVARCHAR(20) | 否 | — | 当前主要岗位 |
| HireDate | DATE | 否 | — | 入职日期 |
| MonthlySalary | DECIMAL(10,2) | 否 | — | 样例中的约定月薪 |
| ContactPhone | VARCHAR(20) | 是 | — | 员工联系方式 |
| ActiveStatus | NVARCHAR(10) | 否 | — | 历史业务保留员工引用，离职不删行 |

### 顾客 Customer

一个可识别顾客账号；会员是其可选身份，普通顾客也需顾客记录。

主码：`CustomerID`。其他候选码：`AccountName`。
外码：无。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| CustomerID | VARCHAR(12) | 否 | PK | 顾客稳定标识 |
| AccountName | NVARCHAR(40) | 否 | 候选码组成 | 登录账号，不是姓名 |
| CustomerName | NVARCHAR(40) | 否 | — | 顾客称呼 |
| ContactPhone | VARCHAR(20) | 是 | — | 顾客当前联系方式；不代替订单收货快照 |
| IsMember | BIT | 否 | — | 当前会员身份 |
| JoinedAt | DATETIME2(0) | 是 | — | 成为会员的时间 |
| PointsBalance | INT | 否 | — | 当前积分余额，须与积分变动合计一致 |
| ActiveStatus | NVARCHAR(10) | 否 | — | 停用账号但保留历史订单 |

### 采购订单 PurchaseOrder

一次向单一供应商提交的整单采购；审批、验收分别关联员工。

主码：`PurchaseOrderID`。其他候选码：无额外已实现候选码。
外码：`SupplierID` → `Supplier`.`SupplierID`；`CreatedBy` → `Employee`.`EmployeeID`；`ApprovedBy` → `Employee`.`EmployeeID`；`ReceivedBy` → `Employee`.`EmployeeID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| PurchaseOrderID | VARCHAR(12) | 否 | PK | 一张采购单的标识 |
| SupplierID | VARCHAR(12) | 否 | FK → Supplier | 唯一供货方 |
| CreatedBy | VARCHAR(12) | 否 | FK → Employee | 创建采购单的员工 |
| CreatedAt | DATETIME2(0) | 否 | — | 提交采购需求的时间 |
| ApprovedBy | VARCHAR(12) | 是 | FK → Employee | 审批员工；未审批时为空 |
| ApprovedAt | DATETIME2(0) | 是 | — | 审批时间 |
| ReceivedBy | VARCHAR(12) | 是 | FK → Employee | 验收并确认入库的员工 |
| ReceivedAt | DATETIME2(0) | 是 | — | 整单验收合格并入库的时间 |
| OrderStatus | NVARCHAR(10) | 否 | — | 采购单当前状态 |
| RejectionReason | NVARCHAR(200) | 是 | — | 审批或验收被拒绝的原因 |

### 采购明细 PurchaseOrderItem

一单中的一种商品及计划数量、历史采购价；关联实体，需单独标识供批次追溯。

主码：`PurchaseItemID`。其他候选码：`PurchaseOrderID, ProductID`。
外码：`PurchaseOrderID` → `PurchaseOrder`.`PurchaseOrderID`；`ProductID` → `Product`.`ProductID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| PurchaseItemID | VARCHAR(12) | 否 | PK | 采购明细标识 |
| PurchaseOrderID | VARCHAR(12) | 否 | FK → PurchaseOrder；候选码组成 | 所属采购订单 |
| ProductID | VARCHAR(12) | 否 | FK → Product；候选码组成 | 采购的商品 |
| OrderedQty | INT | 否 | — | 本单计划并整单验收的数量 |
| UnitCost | DECIMAL(10,2) | 否 | — | 本次采购成交单价，供历史成本核对 |

### 库存批次 InventoryBatch

一条采购明细形成的一个供应商批号；独立保存日期、质量状态和现存量。

主码：`BatchID`。其他候选码：`PurchaseItemID, SupplierBatchNo`。
复合引用超码：`BatchID, PurchaseItemID`。
外码：`PurchaseItemID` → `PurchaseOrderItem`.`PurchaseItemID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| BatchID | VARCHAR(12) | 否 | PK；超码组成 | 仓库批次标识 |
| PurchaseItemID | VARCHAR(12) | 否 | FK → PurchaseOrderItem；候选码组成；超码组成 | 批次的采购来源；商品可由采购明细追溯 |
| SupplierBatchNo | VARCHAR(40) | 否 | 候选码组成 | 包装上或供应商提供的批号 |
| ProductionDate | DATE | 否 | — | 生产日期 |
| ExpiryDate | DATE | 否 | — | 到期日期；当天起不可售 |
| ReceivedAt | DATETIME2(0) | 否 | — | 该批验收入库的时间 |
| OnHandQty | INT | 否 | — | 当前账面现存量，随库存变动同步更新 |
| BatchStatus | NVARCHAR(10) | 否 | — | 人工质量状态；即使为合格，到期后仍不可售 |

### 销售订单 SalesOrder

一个顾客的一次整单购买；保存状态与下单时收货快照。

主码：`SalesOrderID`。其他候选码：无额外已实现候选码。
复合引用超码：`SalesOrderID, CustomerID`。
外码：`CustomerID` → `Customer`.`CustomerID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| SalesOrderID | VARCHAR(12) | 否 | PK；超码组成 | 一张销售单的标识 |
| CustomerID | VARCHAR(12) | 否 | FK → Customer；超码组成 | 下单顾客 |
| CreatedAt | DATETIME2(0) | 否 | — | 整单锁定成功并成单的时间 |
| OrderStatus | NVARCHAR(10) | 否 | — | 当前销售订单状态 |
| CompletedAt | DATETIME2(0) | 是 | — | 确认出库的完成时间 |
| RecipientName | NVARCHAR(40) | 否 | — | 下单时的收货人快照 |
| RecipientPhone | VARCHAR(20) | 否 | — | 下单时的收货联系方式快照 |
| ShippingAddress | NVARCHAR(200) | 否 | — | 人工配送交接所需地址快照 |
| TotalAmount | DECIMAL(10,2) | 否 | — | 订单应付金额；与明细同步维护 |

### 销售明细 SalesOrderItem

一单中的一种商品及数量、历史成交价；关联实体，供锁定和出库引用。

主码：`SalesItemID`。其他候选码：`SalesOrderID, ProductID`。
外码：`SalesOrderID` → `SalesOrder`.`SalesOrderID`；`ProductID` → `Product`.`ProductID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| SalesItemID | VARCHAR(12) | 否 | PK | 一条订单明细的标识 |
| SalesOrderID | VARCHAR(12) | 否 | FK → SalesOrder；候选码组成 | 所属销售订单 |
| ProductID | VARCHAR(12) | 否 | FK → Product；候选码组成 | 购买商品 |
| Quantity | INT | 否 | — | 本明细购买数量 |
| DealUnitPrice | DECIMAL(10,2) | 否 | — | 下单时锁定的历史成交单价 |

### 库存锁定 InventoryReservation

一条明细对一个批次的一次占用事件；同一组合可有释放、重新锁定等多条历史。

主码：`ReservationID`。其他候选码：无额外已实现候选码。
外码：`SalesItemID` → `SalesOrderItem`.`SalesItemID`；`BatchID` → `InventoryBatch`.`BatchID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| ReservationID | VARCHAR(12) | 否 | PK | 一次批次锁定的标识 |
| SalesItemID | VARCHAR(12) | 否 | FK → SalesOrderItem | 被锁定库存对应的订单明细 |
| BatchID | VARCHAR(12) | 否 | FK → InventoryBatch | 实际占用的库存批次 |
| ReservedQty | INT | 否 | — | 该批为本明细预留的数量 |
| ReservationStatus | NVARCHAR(10) | 否 | — | 锁定当前处理结果 |
| ReservedAt | DATETIME2(0) | 否 | — | 锁定建立时间 |
| EndedAt | DATETIME2(0) | 是 | — | 锁定结束时间 |

### 库存流水 InventoryMovement

一个批次的一次实物数量变化；区分入库、出库、盘点、报损，独立追溯经办人。

主码：`MovementID`。其他候选码：无额外已实现候选码。
外码：`BatchID` → `InventoryBatch`.`BatchID`；`PurchaseItemID` → `PurchaseOrderItem`.`PurchaseItemID`；`SalesItemID` → `SalesOrderItem`.`SalesItemID`；`OperatorID` → `Employee`.`EmployeeID`；`(BatchID, PurchaseItemID)` → `InventoryBatch(BatchID, PurchaseItemID)`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| MovementID | VARCHAR(12) | 否 | PK | 一次现存量变化的标识 |
| BatchID | VARCHAR(12) | 否 | FK → InventoryBatch | 受影响库存批次 |
| MovementType | NVARCHAR(10) | 否 | — | 库存变化业务类型 |
| QuantityDelta | INT | 否 | — | 现存数量的有符号变化 |
| PurchaseItemID | VARCHAR(12) | 是 | FK → PurchaseOrderItem | 入库的采购来源 |
| SalesItemID | VARCHAR(12) | 是 | FK → SalesOrderItem | 出库的销售来源 |
| Reason | NVARCHAR(200) | 否 | — | 变动原因或操作说明 |
| OperatorID | VARCHAR(12) | 否 | FK → Employee | 确认库存变动的员工 |
| OccurredAt | DATETIME2(0) | 否 | — | 实际确认现存变化的时间 |

### 模拟支付记录 PaymentRecord

一次模拟支付尝试；失败也可留记录，不以订单号作为支付主码。

主码：`PaymentID`。其他候选码：`MockTransactionNo`。
外码：`SalesOrderID` → `SalesOrder`.`SalesOrderID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| PaymentID | VARCHAR(12) | 否 | PK | 一次模拟支付尝试的标识 |
| SalesOrderID | VARCHAR(12) | 否 | FK → SalesOrder | 对应销售订单 |
| MockTransactionNo | VARCHAR(40) | 否 | 候选码组成 | 模拟交易流水号，用于识别重复回报 |
| Amount | DECIMAL(10,2) | 否 | — | 本次支付尝试金额 |
| PaymentStatus | NVARCHAR(10) | 否 | — | 模拟支付结果 |
| ResultAt | DATETIME2(0) | 否 | — | 支付结果确认时间 |

### 积分流水 PointsMovement

一个完成订单的一次赠分；独立保存计算依据，一单至多一条。

主码：`PointsMovementID`。其他候选码：`SalesOrderID`。
外码：`CustomerID` → `Customer`.`CustomerID`；`SalesOrderID` → `SalesOrder`.`SalesOrderID`；`(SalesOrderID, CustomerID)` → `SalesOrder(SalesOrderID, CustomerID)`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| PointsMovementID | VARCHAR(12) | 否 | PK | 一次积分赠送的标识 |
| CustomerID | VARCHAR(12) | 否 | FK → Customer | 获得积分的顾客 |
| SalesOrderID | VARCHAR(12) | 否 | FK → SalesOrder；候选码组成 | 积分来源订单 |
| PointsDelta | INT | 否 | — | 本次增加的积分 |
| BasedAmount | DECIMAL(10,2) | 否 | — | 计算本次积分所依据的实付金额 |
| Reason | NVARCHAR(20) | 否 | — | 变动原因 |
| OccurredAt | DATETIME2(0) | 否 | — | 完成订单并赠分的时间 |

### 订单异常 OrderException

一次异常发现及当前处理记录；同单可有多个原因，不能把异常等同于订单状态。

主码：`ExceptionID`。其他候选码：无额外已实现候选码。
外码：`SalesOrderID` → `SalesOrder`.`SalesOrderID`；`BatchID` → `InventoryBatch`.`BatchID`；`HandledBy` → `Employee`.`EmployeeID`。

| 属性 | SQL 类型 | 允许空 | 标识／引用 | 含义 |
| --- | --- | --- | --- | --- |
| ExceptionID | VARCHAR(12) | 否 | PK | 一次异常发现或处理记录的标识 |
| SalesOrderID | VARCHAR(12) | 否 | FK → SalesOrder | 受影响订单 |
| BatchID | VARCHAR(12) | 是 | FK → InventoryBatch | 异常关联批次 |
| ReasonCode | NVARCHAR(20) | 否 | — | 标准化异常原因 |
| Description | NVARCHAR(200) | 否 | — | 发现了什么问题 |
| HandlingStatus | NVARCHAR(10) | 否 | — | 本条异常的处理状态；不等于订单状态 |
| HandlingNote | NVARCHAR(200) | 是 | — | 已采取的核实或临时处置 |
| HandledBy | VARCHAR(12) | 否 | FK → Employee | 登记或处理的员工 |
| RecordedAt | DATETIME2(0) | 否 | — | 异常记录时间 |
