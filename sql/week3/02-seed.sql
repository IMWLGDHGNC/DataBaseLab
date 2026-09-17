-- Exact, related fictional sample tuples from docs/Week2.md.
-- A second load fails on primary keys and rolls back; it never overwrites data.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
INSERT INTO dbo.[ProductCategory] ([CategoryID], [CategoryName], [Description]) VALUES
    (N'CAT00', N'辣味零食', N'辣条等独立包装零食'),
    (N'CAT01', N'饮品', N'独立瓶装或罐装饮料'),
    (N'CAT02', N'膨化与米饼', N'雪饼等袋装零食');

INSERT INTO dbo.[Product] ([ProductID], [CategoryID], [ProductName], [Brand], [Specification], [SaleUnit], [CurrentPrice], [SaleStatus], [ReorderLevel]) VALUES
    (N'S00', N'CAT00', N'卫龙大面筋', N'卫龙', N'30g', N'包', 2.00, N'在售', 100),
    (N'S01', N'CAT01', N'百事可乐罐装', N'百事', N'330ml', N'瓶', 4.40, N'在售', 80),
    (N'S02', N'CAT02', N'旺旺雪饼', N'旺旺', N'84g', N'袋', 5.50, N'在售', 20);

INSERT INTO dbo.[Supplier] ([SupplierID], [SupplierName], [ContactName], [ContactPhone], [CooperationStatus]) VALUES
    (N'SUP00', N'粤邻食品批发部（模拟）', N'测试联系人甲', NULL, N'合作中'),
    (N'SUP01', N'南城零食供货部（模拟）', N'测试联系人乙', NULL, N'合作中');

INSERT INTO dbo.[Employee] ([EmployeeID], [EmployeeName], [Position], [HireDate], [MonthlySalary], [ContactPhone], [ActiveStatus]) VALUES
    (N'P00', N'王明', N'库存管理员', N'2025-06-01', 4800.00, NULL, N'在职'),
    (N'P01', N'李晓', N'店长', N'2025-08-15', 6500.00, NULL, N'在职'),
    (N'P02', N'陈禾', N'采购员', N'2026-03-01', 5000.00, NULL, N'在职');

INSERT INTO dbo.[Customer] ([CustomerID], [AccountName], [CustomerName], [ContactPhone], [IsMember], [JoinedAt], [PointsBalance], [ActiveStatus]) VALUES
    (N'C00', N'snack_c00', N'示例顾客甲', NULL, 1, N'2026-09-01 10:00:00', 48, N'正常'),
    (N'C01', N'snack_c01', N'示例顾客乙', NULL, 1, N'2026-09-02 10:00:00', 16, N'正常'),
    (N'C02', N'snack_c02', N'示例顾客丙', NULL, 0, NULL, 0, N'正常');

INSERT INTO dbo.[PurchaseOrder] ([PurchaseOrderID], [SupplierID], [CreatedBy], [CreatedAt], [ApprovedBy], [ApprovedAt], [ReceivedBy], [ReceivedAt], [OrderStatus], [RejectionReason]) VALUES
    (N'PO00', N'SUP00', N'P02', N'2026-09-14 09:30:00', N'P01', N'2026-09-14 10:00:00', N'P00', N'2026-09-15 10:00:00', N'已收货', NULL),
    (N'PO01', N'SUP01', N'P02', N'2026-09-14 11:00:00', N'P01', N'2026-09-14 11:15:00', N'P00', N'2026-09-16 09:00:00', N'已收货', NULL);

INSERT INTO dbo.[PurchaseOrderItem] ([PurchaseItemID], [PurchaseOrderID], [ProductID], [OrderedQty], [UnitCost]) VALUES
    (N'PDI00', N'PO00', N'S01', 300, 2.20),
    (N'PDI01', N'PO00', N'S02', 40, 3.20),
    (N'PDI02', N'PO01', N'S00', 500, 1.30);

INSERT INTO dbo.[InventoryBatch] ([BatchID], [PurchaseItemID], [SupplierBatchNo], [ProductionDate], [ExpiryDate], [ReceivedAt], [OnHandQty], [BatchStatus]) VALUES
    (N'B00', N'PDI00', N'PS-260815', N'2026-08-15', N'2027-08-15', N'2026-09-15 10:00:00', 290, N'合格'),
    (N'B01', N'PDI01', N'WW-260601', N'2026-06-01', N'2026-09-18', N'2026-09-15 10:00:00', 37, N'合格'),
    (N'B02', N'PDI02', N'WL-260801', N'2026-08-01', N'2027-02-01', N'2026-09-16 09:00:00', 498, N'合格');

INSERT INTO dbo.[SalesOrder] ([SalesOrderID], [CustomerID], [CreatedAt], [OrderStatus], [CompletedAt], [RecipientName], [RecipientPhone], [ShippingAddress], [TotalAmount]) VALUES
    (N'ST00', N'C00', N'2026-09-16 10:00:00', N'已完成', N'2026-09-16 10:30:00', N'示例收件人甲', N'13800000000', N'广州市示例路 1 号', 48.00),
    (N'ST01', N'C01', N'2026-09-16 11:00:00', N'已完成', N'2026-09-16 11:25:00', N'示例收件人乙', N'13900000000', N'广州市示例路 2 号', 16.50),
    (N'ST02', N'C02', N'2026-09-17 17:00:00', N'待出库', NULL, N'示例收件人丙', N'13700000000', N'广州市示例路 3 号', 11.00);

INSERT INTO dbo.[SalesOrderItem] ([SalesItemID], [SalesOrderID], [ProductID], [Quantity], [DealUnitPrice]) VALUES
    (N'SI00', N'ST00', N'S01', 10, 4.40),
    (N'SI01', N'ST00', N'S00', 2, 2.00),
    (N'SI02', N'ST01', N'S02', 3, 5.50),
    (N'SI03', N'ST02', N'S02', 2, 5.50);

INSERT INTO dbo.[InventoryReservation] ([ReservationID], [SalesItemID], [BatchID], [ReservedQty], [ReservationStatus], [ReservedAt], [EndedAt]) VALUES
    (N'R00', N'SI00', N'B00', 10, N'已转出库', N'2026-09-16 10:00:00', N'2026-09-16 10:30:00'),
    (N'R01', N'SI01', N'B02', 2, N'已转出库', N'2026-09-16 10:00:00', N'2026-09-16 10:30:00'),
    (N'R02', N'SI02', N'B01', 3, N'已转出库', N'2026-09-16 11:00:00', N'2026-09-16 11:25:00'),
    (N'R03', N'SI03', N'B01', 2, N'有效', N'2026-09-17 17:00:00', NULL);

INSERT INTO dbo.[InventoryMovement] ([MovementID], [BatchID], [MovementType], [QuantityDelta], [PurchaseItemID], [SalesItemID], [Reason], [OperatorID], [OccurredAt]) VALUES
    (N'IM00', N'B00', N'采购入库', 300, N'PDI00', NULL, N'PO00 整单验收', N'P00', N'2026-09-15 10:00:00'),
    (N'IM01', N'B01', N'采购入库', 40, N'PDI01', NULL, N'PO00 整单验收', N'P00', N'2026-09-15 10:00:00'),
    (N'IM02', N'B02', N'采购入库', 500, N'PDI02', NULL, N'PO01 整单验收', N'P00', N'2026-09-16 09:00:00'),
    (N'IM03', N'B00', N'销售出库', -10, NULL, N'SI00', N'ST00 确认出库', N'P00', N'2026-09-16 10:30:00'),
    (N'IM04', N'B02', N'销售出库', -2, NULL, N'SI01', N'ST00 确认出库', N'P00', N'2026-09-16 10:30:00'),
    (N'IM05', N'B01', N'销售出库', -3, NULL, N'SI02', N'ST01 确认出库', N'P00', N'2026-09-16 11:25:00');

INSERT INTO dbo.[PaymentRecord] ([PaymentID], [SalesOrderID], [MockTransactionNo], [Amount], [PaymentStatus], [ResultAt]) VALUES
    (N'PAY00', N'ST00', N'SIM-20260916-0001', 48.00, N'成功', N'2026-09-16 10:05:00'),
    (N'PAY01', N'ST01', N'SIM-20260916-0002', 16.50, N'成功', N'2026-09-16 11:05:00'),
    (N'PAY02', N'ST02', N'SIM-20260917-0003', 11.00, N'成功', N'2026-09-17 17:05:00');

INSERT INTO dbo.[PointsMovement] ([PointsMovementID], [CustomerID], [SalesOrderID], [PointsDelta], [BasedAmount], [Reason], [OccurredAt]) VALUES
    (N'PM00', N'C00', N'ST00', 48, 48.00, N'订单完成赠分', N'2026-09-16 10:30:00'),
    (N'PM01', N'C01', N'ST01', 16, 16.50, N'订单完成赠分', N'2026-09-16 11:25:00');

INSERT INTO dbo.[OrderException] ([ExceptionID], [SalesOrderID], [BatchID], [ReasonCode], [Description], [HandlingStatus], [HandlingNote], [HandledBy], [RecordedAt]) VALUES
    (N'EX00', N'ST02', N'B01', N'批次到期', N'复核时发现 B01 于当日到期，不得出库', N'已核实', N'暂停出库，保留异常记录', N'P00', N'2026-09-18 09:00:00'),
    (N'EX01', N'ST02', N'B01', N'无可替代批次', N'当前没有同商品其他合格批次', N'待处理', N'订单保持待出库，等待后续方案', N'P01', N'2026-09-18 09:20:00');

COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
