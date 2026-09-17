-- Week3: reviewed Week2 dictionary. Run only in an empty database.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS (SELECT 1 FROM sys.tables WHERE is_ms_shipped=0) THROW 51000, 'Schema requires an empty database; choose a new database name.', 1;
BEGIN TRY
BEGIN TRANSACTION;
CREATE TABLE dbo.[ProductCategory] (
    [CategoryID] VARCHAR(12) NOT NULL, -- 类别标识
    [CategoryName] NVARCHAR(40) NOT NULL, -- 展示与统计用类别名称
    [Description] NVARCHAR(200) NULL, -- 类别边界说明
    CONSTRAINT [PK_ProductCategory] PRIMARY KEY ([CategoryID]),
    CONSTRAINT [CK_ProductCategory_CategoryID_Text] CHECK (LEN(LTRIM(RTRIM([CategoryID])))>0),
    CONSTRAINT [CK_ProductCategory_CategoryName_Text] CHECK (LEN(LTRIM(RTRIM([CategoryName])))>0),
    CONSTRAINT [UQ_ProductCategory_1] UNIQUE ([CategoryName])
);

CREATE TABLE dbo.[Product] (
    [ProductID] VARCHAR(12) NOT NULL, -- 独立销售 SKU 标识
    [CategoryID] VARCHAR(12) NOT NULL, -- 商品类别
    [ProductName] NVARCHAR(100) NOT NULL, -- 商品销售名称
    [Brand] NVARCHAR(60) NOT NULL, -- 商品品牌
    [Specification] NVARCHAR(60) NOT NULL, -- 最小销售单位对应的净含量或包装规格
    [SaleUnit] NVARCHAR(10) NOT NULL, -- 库存和订单数量的计量单位
    [CurrentPrice] DECIMAL(10,2) NOT NULL, -- 当前售价；历史成交价另存于销售明细
    [SaleStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_Product_SaleStatus] DEFAULT (N'在售'), -- 能否接受新订单
    [ReorderLevel] INT NOT NULL CONSTRAINT [DF_Product_ReorderLevel] DEFAULT (0), -- 人工补货预警阈值，按最小销售单位计
    CONSTRAINT [PK_Product] PRIMARY KEY ([ProductID]),
    CONSTRAINT [CK_Product_ProductID_Text] CHECK (LEN(LTRIM(RTRIM([ProductID])))>0),
    CONSTRAINT [CK_Product_CategoryID_Text] CHECK (LEN(LTRIM(RTRIM([CategoryID])))>0),
    CONSTRAINT [FK_Product_CategoryID] FOREIGN KEY ([CategoryID]) REFERENCES dbo.[ProductCategory] ([CategoryID]),
    CONSTRAINT [CK_Product_ProductName_Text] CHECK (LEN(LTRIM(RTRIM([ProductName])))>0),
    CONSTRAINT [CK_Product_Brand_Text] CHECK (LEN(LTRIM(RTRIM([Brand])))>0),
    CONSTRAINT [CK_Product_Specification_Text] CHECK (LEN(LTRIM(RTRIM([Specification])))>0),
    CONSTRAINT [CK_Product_SaleUnit_Text] CHECK (LEN(LTRIM(RTRIM([SaleUnit])))>0),
    CONSTRAINT [CK_Product_SaleStatus_Text] CHECK (LEN(LTRIM(RTRIM([SaleStatus])))>0),
    CONSTRAINT [CK_Product_SaleStatus_Enum] CHECK ([SaleStatus] IN (N'在售', N'停售')),
    CONSTRAINT [UQ_Product_1] UNIQUE ([Brand], [ProductName], [Specification], [SaleUnit]),
    CONSTRAINT [CK_Product_Rule1] CHECK (CurrentPrice > 0),
    CONSTRAINT [CK_Product_Rule2] CHECK (ReorderLevel >= 0)
);

CREATE TABLE dbo.[Supplier] (
    [SupplierID] VARCHAR(12) NOT NULL, -- 供应商稳定标识
    [SupplierName] NVARCHAR(100) NOT NULL, -- 供货方名称
    [ContactName] NVARCHAR(40) NULL, -- 采购沟通联系人
    [ContactPhone] VARCHAR(20) NULL, -- 联系方式，不参与数值计算
    [CooperationStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_Supplier_CooperationStatus] DEFAULT (N'合作中'), -- 能否新建采购订单
    CONSTRAINT [PK_Supplier] PRIMARY KEY ([SupplierID]),
    CONSTRAINT [CK_Supplier_SupplierID_Text] CHECK (LEN(LTRIM(RTRIM([SupplierID])))>0),
    CONSTRAINT [CK_Supplier_SupplierName_Text] CHECK (LEN(LTRIM(RTRIM([SupplierName])))>0),
    CONSTRAINT [CK_Supplier_CooperationStatus_Text] CHECK (LEN(LTRIM(RTRIM([CooperationStatus])))>0),
    CONSTRAINT [CK_Supplier_CooperationStatus_Enum] CHECK ([CooperationStatus] IN (N'合作中', N'已停用'))
);

CREATE TABLE dbo.[Employee] (
    [EmployeeID] VARCHAR(12) NOT NULL, -- 员工稳定标识
    [EmployeeName] NVARCHAR(40) NOT NULL, -- 员工显示名
    [Position] NVARCHAR(20) NOT NULL, -- 当前主要岗位
    [HireDate] DATE NOT NULL, -- 入职日期
    [MonthlySalary] DECIMAL(10,2) NOT NULL, -- 样例中的约定月薪
    [ContactPhone] VARCHAR(20) NULL, -- 员工联系方式
    [ActiveStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_Employee_ActiveStatus] DEFAULT (N'在职'), -- 历史业务保留员工引用，离职不删行
    CONSTRAINT [PK_Employee] PRIMARY KEY ([EmployeeID]),
    CONSTRAINT [CK_Employee_EmployeeID_Text] CHECK (LEN(LTRIM(RTRIM([EmployeeID])))>0),
    CONSTRAINT [CK_Employee_EmployeeName_Text] CHECK (LEN(LTRIM(RTRIM([EmployeeName])))>0),
    CONSTRAINT [CK_Employee_Position_Text] CHECK (LEN(LTRIM(RTRIM([Position])))>0),
    CONSTRAINT [CK_Employee_Position_Enum] CHECK ([Position] IN (N'店长', N'采购员', N'库存管理员', N'订单管理员')),
    CONSTRAINT [CK_Employee_ActiveStatus_Text] CHECK (LEN(LTRIM(RTRIM([ActiveStatus])))>0),
    CONSTRAINT [CK_Employee_ActiveStatus_Enum] CHECK ([ActiveStatus] IN (N'在职', N'离职')),
    CONSTRAINT [CK_Employee_Rule1] CHECK (MonthlySalary >= 0),
    CONSTRAINT [CK_Employee_Rule2] CHECK (HireDate <= CONVERT(date, GETDATE()))
);

CREATE TABLE dbo.[Customer] (
    [CustomerID] VARCHAR(12) NOT NULL, -- 顾客稳定标识
    [AccountName] NVARCHAR(40) NOT NULL, -- 登录账号，不是姓名
    [CustomerName] NVARCHAR(40) NOT NULL, -- 顾客称呼
    [ContactPhone] VARCHAR(20) NULL, -- 顾客当前联系方式；不代替订单收货快照
    [IsMember] BIT NOT NULL CONSTRAINT [DF_Customer_IsMember] DEFAULT (0), -- 当前会员身份
    [JoinedAt] DATETIME2(0) NULL, -- 成为会员的时间
    [PointsBalance] INT NOT NULL CONSTRAINT [DF_Customer_PointsBalance] DEFAULT (0), -- 当前积分余额，须与积分变动合计一致
    [ActiveStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_Customer_ActiveStatus] DEFAULT (N'正常'), -- 停用账号但保留历史订单
    CONSTRAINT [PK_Customer] PRIMARY KEY ([CustomerID]),
    CONSTRAINT [CK_Customer_CustomerID_Text] CHECK (LEN(LTRIM(RTRIM([CustomerID])))>0),
    CONSTRAINT [CK_Customer_AccountName_Text] CHECK (LEN(LTRIM(RTRIM([AccountName])))>0),
    CONSTRAINT [CK_Customer_CustomerName_Text] CHECK (LEN(LTRIM(RTRIM([CustomerName])))>0),
    CONSTRAINT [CK_Customer_ActiveStatus_Text] CHECK (LEN(LTRIM(RTRIM([ActiveStatus])))>0),
    CONSTRAINT [CK_Customer_ActiveStatus_Enum] CHECK ([ActiveStatus] IN (N'正常', N'停用')),
    CONSTRAINT [UQ_Customer_1] UNIQUE ([AccountName]),
    CONSTRAINT [CK_Customer_Rule1] CHECK (PointsBalance >= 0),
    CONSTRAINT [CK_Customer_Rule2] CHECK ((IsMember=0 AND JoinedAt IS NULL AND PointsBalance=0) OR (IsMember=1 AND JoinedAt IS NOT NULL))
);

CREATE TABLE dbo.[PurchaseOrder] (
    [PurchaseOrderID] VARCHAR(12) NOT NULL, -- 一张采购单的标识
    [SupplierID] VARCHAR(12) NOT NULL, -- 唯一供货方
    [CreatedBy] VARCHAR(12) NOT NULL, -- 创建采购单的员工
    [CreatedAt] DATETIME2(0) NOT NULL, -- 提交采购需求的时间
    [ApprovedBy] VARCHAR(12) NULL, -- 审批员工；未审批时为空
    [ApprovedAt] DATETIME2(0) NULL, -- 审批时间
    [ReceivedBy] VARCHAR(12) NULL, -- 验收并确认入库的员工
    [ReceivedAt] DATETIME2(0) NULL, -- 整单验收合格并入库的时间
    [OrderStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_PurchaseOrder_OrderStatus] DEFAULT (N'待审批'), -- 采购单当前状态
    [RejectionReason] NVARCHAR(200) NULL, -- 审批或验收被拒绝的原因
    CONSTRAINT [PK_PurchaseOrder] PRIMARY KEY ([PurchaseOrderID]),
    CONSTRAINT [CK_PurchaseOrder_PurchaseOrderID_Text] CHECK (LEN(LTRIM(RTRIM([PurchaseOrderID])))>0),
    CONSTRAINT [CK_PurchaseOrder_SupplierID_Text] CHECK (LEN(LTRIM(RTRIM([SupplierID])))>0),
    CONSTRAINT [FK_PurchaseOrder_SupplierID] FOREIGN KEY ([SupplierID]) REFERENCES dbo.[Supplier] ([SupplierID]),
    CONSTRAINT [CK_PurchaseOrder_CreatedBy_Text] CHECK (LEN(LTRIM(RTRIM([CreatedBy])))>0),
    CONSTRAINT [FK_PurchaseOrder_CreatedBy] FOREIGN KEY ([CreatedBy]) REFERENCES dbo.[Employee] ([EmployeeID]),
    CONSTRAINT [FK_PurchaseOrder_ApprovedBy] FOREIGN KEY ([ApprovedBy]) REFERENCES dbo.[Employee] ([EmployeeID]),
    CONSTRAINT [FK_PurchaseOrder_ReceivedBy] FOREIGN KEY ([ReceivedBy]) REFERENCES dbo.[Employee] ([EmployeeID]),
    CONSTRAINT [CK_PurchaseOrder_OrderStatus_Text] CHECK (LEN(LTRIM(RTRIM([OrderStatus])))>0),
    CONSTRAINT [CK_PurchaseOrder_OrderStatus_Enum] CHECK ([OrderStatus] IN (N'待审批', N'已批准', N'已收货', N'已拒绝')),
    CONSTRAINT [CK_PurchaseOrder_Rule1] CHECK ((ApprovedBy IS NULL AND ApprovedAt IS NULL) OR (ApprovedBy IS NOT NULL AND ApprovedAt IS NOT NULL AND ApprovedAt >= CreatedAt)),
    CONSTRAINT [CK_PurchaseOrder_Rule2] CHECK ((ReceivedBy IS NULL AND ReceivedAt IS NULL) OR (ReceivedBy IS NOT NULL AND ReceivedAt IS NOT NULL AND ApprovedAt IS NOT NULL AND ReceivedAt >= ApprovedAt)),
    CONSTRAINT [CK_PurchaseOrder_Rule3] CHECK ((OrderStatus=N'待审批' AND ApprovedAt IS NULL AND ReceivedAt IS NULL AND RejectionReason IS NULL) OR (OrderStatus=N'已批准' AND ApprovedAt IS NOT NULL AND ReceivedAt IS NULL AND RejectionReason IS NULL) OR (OrderStatus=N'已收货' AND ApprovedAt IS NOT NULL AND ReceivedAt IS NOT NULL AND RejectionReason IS NULL) OR (OrderStatus=N'已拒绝' AND ReceivedAt IS NULL AND RejectionReason IS NOT NULL AND LEN(LTRIM(RTRIM(RejectionReason)))>0))
);

CREATE TABLE dbo.[PurchaseOrderItem] (
    [PurchaseItemID] VARCHAR(12) NOT NULL, -- 采购明细标识
    [PurchaseOrderID] VARCHAR(12) NOT NULL, -- 所属采购订单
    [ProductID] VARCHAR(12) NOT NULL, -- 采购的商品
    [OrderedQty] INT NOT NULL, -- 本单计划并整单验收的数量
    [UnitCost] DECIMAL(10,2) NOT NULL, -- 本次采购成交单价，供历史成本核对
    CONSTRAINT [PK_PurchaseOrderItem] PRIMARY KEY ([PurchaseItemID]),
    CONSTRAINT [CK_PurchaseOrderItem_PurchaseItemID_Text] CHECK (LEN(LTRIM(RTRIM([PurchaseItemID])))>0),
    CONSTRAINT [CK_PurchaseOrderItem_PurchaseOrderID_Text] CHECK (LEN(LTRIM(RTRIM([PurchaseOrderID])))>0),
    CONSTRAINT [FK_PurchaseOrderItem_PurchaseOrderID] FOREIGN KEY ([PurchaseOrderID]) REFERENCES dbo.[PurchaseOrder] ([PurchaseOrderID]),
    CONSTRAINT [CK_PurchaseOrderItem_ProductID_Text] CHECK (LEN(LTRIM(RTRIM([ProductID])))>0),
    CONSTRAINT [FK_PurchaseOrderItem_ProductID] FOREIGN KEY ([ProductID]) REFERENCES dbo.[Product] ([ProductID]),
    CONSTRAINT [UQ_PurchaseOrderItem_1] UNIQUE ([PurchaseOrderID], [ProductID]),
    CONSTRAINT [CK_PurchaseOrderItem_Rule1] CHECK (OrderedQty > 0),
    CONSTRAINT [CK_PurchaseOrderItem_Rule2] CHECK (UnitCost > 0)
);

CREATE TABLE dbo.[InventoryBatch] (
    [BatchID] VARCHAR(12) NOT NULL, -- 仓库批次标识
    [PurchaseItemID] VARCHAR(12) NOT NULL, -- 批次的采购来源；商品可由采购明细追溯
    [SupplierBatchNo] VARCHAR(40) NOT NULL, -- 包装上或供应商提供的批号
    [ProductionDate] DATE NOT NULL, -- 生产日期
    [ExpiryDate] DATE NOT NULL, -- 到期日期；当天起不可售
    [ReceivedAt] DATETIME2(0) NOT NULL, -- 该批验收入库的时间
    [OnHandQty] INT NOT NULL CONSTRAINT [DF_InventoryBatch_OnHandQty] DEFAULT (0), -- 当前账面现存量，随库存变动同步更新
    [BatchStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_InventoryBatch_BatchStatus] DEFAULT (N'合格'), -- 人工质量状态；即使为合格，到期后仍不可售
    CONSTRAINT [PK_InventoryBatch] PRIMARY KEY ([BatchID]),
    CONSTRAINT [CK_InventoryBatch_BatchID_Text] CHECK (LEN(LTRIM(RTRIM([BatchID])))>0),
    CONSTRAINT [CK_InventoryBatch_PurchaseItemID_Text] CHECK (LEN(LTRIM(RTRIM([PurchaseItemID])))>0),
    CONSTRAINT [FK_InventoryBatch_PurchaseItemID] FOREIGN KEY ([PurchaseItemID]) REFERENCES dbo.[PurchaseOrderItem] ([PurchaseItemID]),
    CONSTRAINT [CK_InventoryBatch_SupplierBatchNo_Text] CHECK (LEN(LTRIM(RTRIM([SupplierBatchNo])))>0),
    CONSTRAINT [CK_InventoryBatch_BatchStatus_Text] CHECK (LEN(LTRIM(RTRIM([BatchStatus])))>0),
    CONSTRAINT [CK_InventoryBatch_BatchStatus_Enum] CHECK ([BatchStatus] IN (N'合格', N'隔离')),
    CONSTRAINT [UQ_InventoryBatch_1] UNIQUE ([PurchaseItemID], [SupplierBatchNo]),
    CONSTRAINT [UQ_InventoryBatch_2] UNIQUE ([BatchID], [PurchaseItemID]),
    CONSTRAINT [CK_InventoryBatch_Rule1] CHECK (OnHandQty >= 0),
    CONSTRAINT [CK_InventoryBatch_Rule2] CHECK (ProductionDate <= CONVERT(date,ReceivedAt) AND ExpiryDate > CONVERT(date,ReceivedAt) AND ExpiryDate > ProductionDate)
);

CREATE TABLE dbo.[SalesOrder] (
    [SalesOrderID] VARCHAR(12) NOT NULL, -- 一张销售单的标识
    [CustomerID] VARCHAR(12) NOT NULL, -- 下单顾客
    [CreatedAt] DATETIME2(0) NOT NULL, -- 整单锁定成功并成单的时间
    [OrderStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_SalesOrder_OrderStatus] DEFAULT (N'待支付'), -- 当前销售订单状态
    [CompletedAt] DATETIME2(0) NULL, -- 确认出库的完成时间
    [RecipientName] NVARCHAR(40) NOT NULL, -- 下单时的收货人快照
    [RecipientPhone] VARCHAR(20) NOT NULL, -- 下单时的收货联系方式快照
    [ShippingAddress] NVARCHAR(200) NOT NULL, -- 人工配送交接所需地址快照
    [TotalAmount] DECIMAL(10,2) NOT NULL, -- 订单应付金额；与明细同步维护
    CONSTRAINT [PK_SalesOrder] PRIMARY KEY ([SalesOrderID]),
    CONSTRAINT [CK_SalesOrder_SalesOrderID_Text] CHECK (LEN(LTRIM(RTRIM([SalesOrderID])))>0),
    CONSTRAINT [CK_SalesOrder_CustomerID_Text] CHECK (LEN(LTRIM(RTRIM([CustomerID])))>0),
    CONSTRAINT [FK_SalesOrder_CustomerID] FOREIGN KEY ([CustomerID]) REFERENCES dbo.[Customer] ([CustomerID]),
    CONSTRAINT [CK_SalesOrder_OrderStatus_Text] CHECK (LEN(LTRIM(RTRIM([OrderStatus])))>0),
    CONSTRAINT [CK_SalesOrder_OrderStatus_Enum] CHECK ([OrderStatus] IN (N'待支付', N'待出库', N'已完成', N'已取消')),
    CONSTRAINT [CK_SalesOrder_RecipientName_Text] CHECK (LEN(LTRIM(RTRIM([RecipientName])))>0),
    CONSTRAINT [CK_SalesOrder_RecipientPhone_Text] CHECK (LEN(LTRIM(RTRIM([RecipientPhone])))>0),
    CONSTRAINT [CK_SalesOrder_ShippingAddress_Text] CHECK (LEN(LTRIM(RTRIM([ShippingAddress])))>0),
    CONSTRAINT [UQ_SalesOrder_1] UNIQUE ([SalesOrderID], [CustomerID]),
    CONSTRAINT [CK_SalesOrder_Rule1] CHECK (TotalAmount > 0),
    CONSTRAINT [CK_SalesOrder_Rule2] CHECK ((OrderStatus=N'已完成' AND CompletedAt IS NOT NULL AND CompletedAt >= CreatedAt) OR (OrderStatus<>N'已完成' AND CompletedAt IS NULL))
);

CREATE TABLE dbo.[SalesOrderItem] (
    [SalesItemID] VARCHAR(12) NOT NULL, -- 一条订单明细的标识
    [SalesOrderID] VARCHAR(12) NOT NULL, -- 所属销售订单
    [ProductID] VARCHAR(12) NOT NULL, -- 购买商品
    [Quantity] INT NOT NULL, -- 本明细购买数量
    [DealUnitPrice] DECIMAL(10,2) NOT NULL, -- 下单时锁定的历史成交单价
    CONSTRAINT [PK_SalesOrderItem] PRIMARY KEY ([SalesItemID]),
    CONSTRAINT [CK_SalesOrderItem_SalesItemID_Text] CHECK (LEN(LTRIM(RTRIM([SalesItemID])))>0),
    CONSTRAINT [CK_SalesOrderItem_SalesOrderID_Text] CHECK (LEN(LTRIM(RTRIM([SalesOrderID])))>0),
    CONSTRAINT [FK_SalesOrderItem_SalesOrderID] FOREIGN KEY ([SalesOrderID]) REFERENCES dbo.[SalesOrder] ([SalesOrderID]),
    CONSTRAINT [CK_SalesOrderItem_ProductID_Text] CHECK (LEN(LTRIM(RTRIM([ProductID])))>0),
    CONSTRAINT [FK_SalesOrderItem_ProductID] FOREIGN KEY ([ProductID]) REFERENCES dbo.[Product] ([ProductID]),
    CONSTRAINT [UQ_SalesOrderItem_1] UNIQUE ([SalesOrderID], [ProductID]),
    CONSTRAINT [CK_SalesOrderItem_Rule1] CHECK (Quantity > 0),
    CONSTRAINT [CK_SalesOrderItem_Rule2] CHECK (DealUnitPrice > 0)
);

CREATE TABLE dbo.[InventoryReservation] (
    [ReservationID] VARCHAR(12) NOT NULL, -- 一次批次锁定的标识
    [SalesItemID] VARCHAR(12) NOT NULL, -- 被锁定库存对应的订单明细
    [BatchID] VARCHAR(12) NOT NULL, -- 实际占用的库存批次
    [ReservedQty] INT NOT NULL, -- 该批为本明细预留的数量
    [ReservationStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_InventoryReservation_ReservationStatus] DEFAULT (N'有效'), -- 锁定当前处理结果
    [ReservedAt] DATETIME2(0) NOT NULL, -- 锁定建立时间
    [EndedAt] DATETIME2(0) NULL, -- 锁定结束时间
    CONSTRAINT [PK_InventoryReservation] PRIMARY KEY ([ReservationID]),
    CONSTRAINT [CK_InventoryReservation_ReservationID_Text] CHECK (LEN(LTRIM(RTRIM([ReservationID])))>0),
    CONSTRAINT [CK_InventoryReservation_SalesItemID_Text] CHECK (LEN(LTRIM(RTRIM([SalesItemID])))>0),
    CONSTRAINT [FK_InventoryReservation_SalesItemID] FOREIGN KEY ([SalesItemID]) REFERENCES dbo.[SalesOrderItem] ([SalesItemID]),
    CONSTRAINT [CK_InventoryReservation_BatchID_Text] CHECK (LEN(LTRIM(RTRIM([BatchID])))>0),
    CONSTRAINT [FK_InventoryReservation_BatchID] FOREIGN KEY ([BatchID]) REFERENCES dbo.[InventoryBatch] ([BatchID]),
    CONSTRAINT [CK_InventoryReservation_ReservationStatus_Text] CHECK (LEN(LTRIM(RTRIM([ReservationStatus])))>0),
    CONSTRAINT [CK_InventoryReservation_ReservationStatus_Enum] CHECK ([ReservationStatus] IN (N'有效', N'已释放', N'已转出库')),
    CONSTRAINT [CK_InventoryReservation_Rule1] CHECK (ReservedQty > 0),
    CONSTRAINT [CK_InventoryReservation_Rule2] CHECK ((ReservationStatus=N'有效' AND EndedAt IS NULL) OR (ReservationStatus<>N'有效' AND EndedAt IS NOT NULL AND EndedAt>=ReservedAt))
);

CREATE TABLE dbo.[InventoryMovement] (
    [MovementID] VARCHAR(12) NOT NULL, -- 一次现存量变化的标识
    [BatchID] VARCHAR(12) NOT NULL, -- 受影响库存批次
    [MovementType] NVARCHAR(10) NOT NULL, -- 库存变化业务类型
    [QuantityDelta] INT NOT NULL, -- 现存数量的有符号变化
    [PurchaseItemID] VARCHAR(12) NULL, -- 入库的采购来源
    [SalesItemID] VARCHAR(12) NULL, -- 出库的销售来源
    [Reason] NVARCHAR(200) NOT NULL, -- 变动原因或操作说明
    [OperatorID] VARCHAR(12) NOT NULL, -- 确认库存变动的员工
    [OccurredAt] DATETIME2(0) NOT NULL, -- 实际确认现存变化的时间
    CONSTRAINT [PK_InventoryMovement] PRIMARY KEY ([MovementID]),
    CONSTRAINT [CK_InventoryMovement_MovementID_Text] CHECK (LEN(LTRIM(RTRIM([MovementID])))>0),
    CONSTRAINT [CK_InventoryMovement_BatchID_Text] CHECK (LEN(LTRIM(RTRIM([BatchID])))>0),
    CONSTRAINT [FK_InventoryMovement_BatchID] FOREIGN KEY ([BatchID]) REFERENCES dbo.[InventoryBatch] ([BatchID]),
    CONSTRAINT [CK_InventoryMovement_MovementType_Text] CHECK (LEN(LTRIM(RTRIM([MovementType])))>0),
    CONSTRAINT [CK_InventoryMovement_MovementType_Enum] CHECK ([MovementType] IN (N'采购入库', N'销售出库', N'盘点调整', N'报损')),
    CONSTRAINT [FK_InventoryMovement_PurchaseItemID] FOREIGN KEY ([PurchaseItemID]) REFERENCES dbo.[PurchaseOrderItem] ([PurchaseItemID]),
    CONSTRAINT [FK_InventoryMovement_SalesItemID] FOREIGN KEY ([SalesItemID]) REFERENCES dbo.[SalesOrderItem] ([SalesItemID]),
    CONSTRAINT [CK_InventoryMovement_Reason_Text] CHECK (LEN(LTRIM(RTRIM([Reason])))>0),
    CONSTRAINT [CK_InventoryMovement_OperatorID_Text] CHECK (LEN(LTRIM(RTRIM([OperatorID])))>0),
    CONSTRAINT [FK_InventoryMovement_OperatorID] FOREIGN KEY ([OperatorID]) REFERENCES dbo.[Employee] ([EmployeeID]),
    CONSTRAINT [CK_InventoryMovement_Rule1] CHECK ((MovementType=N'采购入库' AND QuantityDelta>0 AND PurchaseItemID IS NOT NULL AND SalesItemID IS NULL) OR (MovementType=N'销售出库' AND QuantityDelta<0 AND PurchaseItemID IS NULL AND SalesItemID IS NOT NULL) OR (MovementType=N'盘点调整' AND QuantityDelta<>0 AND PurchaseItemID IS NULL AND SalesItemID IS NULL) OR (MovementType=N'报损' AND QuantityDelta<0 AND PurchaseItemID IS NULL AND SalesItemID IS NULL))
);

CREATE TABLE dbo.[PaymentRecord] (
    [PaymentID] VARCHAR(12) NOT NULL, -- 一次模拟支付尝试的标识
    [SalesOrderID] VARCHAR(12) NOT NULL, -- 对应销售订单
    [MockTransactionNo] VARCHAR(40) NOT NULL, -- 模拟交易流水号，用于识别重复回报
    [Amount] DECIMAL(10,2) NOT NULL, -- 本次支付尝试金额
    [PaymentStatus] NVARCHAR(10) NOT NULL, -- 模拟支付结果
    [ResultAt] DATETIME2(0) NOT NULL, -- 支付结果确认时间
    CONSTRAINT [PK_PaymentRecord] PRIMARY KEY ([PaymentID]),
    CONSTRAINT [CK_PaymentRecord_PaymentID_Text] CHECK (LEN(LTRIM(RTRIM([PaymentID])))>0),
    CONSTRAINT [CK_PaymentRecord_SalesOrderID_Text] CHECK (LEN(LTRIM(RTRIM([SalesOrderID])))>0),
    CONSTRAINT [FK_PaymentRecord_SalesOrderID] FOREIGN KEY ([SalesOrderID]) REFERENCES dbo.[SalesOrder] ([SalesOrderID]),
    CONSTRAINT [CK_PaymentRecord_MockTransactionNo_Text] CHECK (LEN(LTRIM(RTRIM([MockTransactionNo])))>0),
    CONSTRAINT [CK_PaymentRecord_PaymentStatus_Text] CHECK (LEN(LTRIM(RTRIM([PaymentStatus])))>0),
    CONSTRAINT [CK_PaymentRecord_PaymentStatus_Enum] CHECK ([PaymentStatus] IN (N'成功', N'失败')),
    CONSTRAINT [UQ_PaymentRecord_1] UNIQUE ([MockTransactionNo]),
    CONSTRAINT [CK_PaymentRecord_Rule1] CHECK (Amount > 0)
);

CREATE TABLE dbo.[PointsMovement] (
    [PointsMovementID] VARCHAR(12) NOT NULL, -- 一次积分赠送的标识
    [CustomerID] VARCHAR(12) NOT NULL, -- 获得积分的顾客
    [SalesOrderID] VARCHAR(12) NOT NULL, -- 积分来源订单
    [PointsDelta] INT NOT NULL, -- 本次增加的积分
    [BasedAmount] DECIMAL(10,2) NOT NULL, -- 计算本次积分所依据的实付金额
    [Reason] NVARCHAR(20) NOT NULL CONSTRAINT [DF_PointsMovement_Reason] DEFAULT (N'订单完成赠分'), -- 变动原因
    [OccurredAt] DATETIME2(0) NOT NULL, -- 完成订单并赠分的时间
    CONSTRAINT [PK_PointsMovement] PRIMARY KEY ([PointsMovementID]),
    CONSTRAINT [CK_PointsMovement_PointsMovementID_Text] CHECK (LEN(LTRIM(RTRIM([PointsMovementID])))>0),
    CONSTRAINT [CK_PointsMovement_CustomerID_Text] CHECK (LEN(LTRIM(RTRIM([CustomerID])))>0),
    CONSTRAINT [FK_PointsMovement_CustomerID] FOREIGN KEY ([CustomerID]) REFERENCES dbo.[Customer] ([CustomerID]),
    CONSTRAINT [CK_PointsMovement_SalesOrderID_Text] CHECK (LEN(LTRIM(RTRIM([SalesOrderID])))>0),
    CONSTRAINT [FK_PointsMovement_SalesOrderID] FOREIGN KEY ([SalesOrderID]) REFERENCES dbo.[SalesOrder] ([SalesOrderID]),
    CONSTRAINT [CK_PointsMovement_Reason_Text] CHECK (LEN(LTRIM(RTRIM([Reason])))>0),
    CONSTRAINT [CK_PointsMovement_Reason_Enum] CHECK ([Reason] IN (N'订单完成赠分')),
    CONSTRAINT [UQ_PointsMovement_1] UNIQUE ([SalesOrderID]),
    CONSTRAINT [CK_PointsMovement_Rule1] CHECK (BasedAmount >= 1 AND PointsDelta > 0 AND PointsDelta = FLOOR(BasedAmount))
);

CREATE TABLE dbo.[OrderException] (
    [ExceptionID] VARCHAR(12) NOT NULL, -- 一次异常发现或处理记录的标识
    [SalesOrderID] VARCHAR(12) NOT NULL, -- 受影响订单
    [BatchID] VARCHAR(12) NULL, -- 异常关联批次
    [ReasonCode] NVARCHAR(20) NOT NULL, -- 标准化异常原因
    [Description] NVARCHAR(200) NOT NULL, -- 发现了什么问题
    [HandlingStatus] NVARCHAR(10) NOT NULL CONSTRAINT [DF_OrderException_HandlingStatus] DEFAULT (N'待处理'), -- 本条异常的处理状态；不等于订单状态
    [HandlingNote] NVARCHAR(200) NULL, -- 已采取的核实或临时处置
    [HandledBy] VARCHAR(12) NOT NULL, -- 登记或处理的员工
    [RecordedAt] DATETIME2(0) NOT NULL, -- 异常记录时间
    CONSTRAINT [PK_OrderException] PRIMARY KEY ([ExceptionID]),
    CONSTRAINT [CK_OrderException_ExceptionID_Text] CHECK (LEN(LTRIM(RTRIM([ExceptionID])))>0),
    CONSTRAINT [CK_OrderException_SalesOrderID_Text] CHECK (LEN(LTRIM(RTRIM([SalesOrderID])))>0),
    CONSTRAINT [FK_OrderException_SalesOrderID] FOREIGN KEY ([SalesOrderID]) REFERENCES dbo.[SalesOrder] ([SalesOrderID]),
    CONSTRAINT [FK_OrderException_BatchID] FOREIGN KEY ([BatchID]) REFERENCES dbo.[InventoryBatch] ([BatchID]),
    CONSTRAINT [CK_OrderException_ReasonCode_Text] CHECK (LEN(LTRIM(RTRIM([ReasonCode])))>0),
    CONSTRAINT [CK_OrderException_ReasonCode_Enum] CHECK ([ReasonCode] IN (N'批次到期', N'实物不足', N'无可替代批次', N'其他')),
    CONSTRAINT [CK_OrderException_Description_Text] CHECK (LEN(LTRIM(RTRIM([Description])))>0),
    CONSTRAINT [CK_OrderException_HandlingStatus_Text] CHECK (LEN(LTRIM(RTRIM([HandlingStatus])))>0),
    CONSTRAINT [CK_OrderException_HandlingStatus_Enum] CHECK ([HandlingStatus] IN (N'待处理', N'已核实', N'已解决')),
    CONSTRAINT [CK_OrderException_HandledBy_Text] CHECK (LEN(LTRIM(RTRIM([HandledBy])))>0),
    CONSTRAINT [FK_OrderException_HandledBy] FOREIGN KEY ([HandledBy]) REFERENCES dbo.[Employee] ([EmployeeID])
);

-- Supporting UNIQUE pairs above are superkeys for composite FKs, not new minimal candidate keys.
ALTER TABLE dbo.InventoryMovement ADD CONSTRAINT FK_Movement_BatchPurchase FOREIGN KEY (BatchID,PurchaseItemID) REFERENCES dbo.InventoryBatch(BatchID,PurchaseItemID);
ALTER TABLE dbo.PointsMovement ADD CONSTRAINT FK_Points_OrderCustomer FOREIGN KEY (SalesOrderID,CustomerID) REFERENCES dbo.SalesOrder(SalesOrderID,CustomerID);
CREATE UNIQUE INDEX UX_Payment_OneSuccess ON dbo.PaymentRecord(SalesOrderID) WHERE PaymentStatus=N'成功';
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
