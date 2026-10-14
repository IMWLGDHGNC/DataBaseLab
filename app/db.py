"""The only application layer that sends SQL to SQL Server."""

from contextlib import contextmanager

import pymssql


class Database:
    def __init__(self, config):
        self.config = config

    @contextmanager
    def session(self, role, write=False):
        credentials = self.config["db_users"][role]
        conn = pymssql.connect(
            server=self.config["db_host"],
            port=int(self.config["db_port"]),
            user=credentials["user"],
            password=credentials["password"],
            database=self.config["db_name"],
            charset="UTF-8",
            login_timeout=5,
            timeout=15,
            autocommit=False,
        )
        try:
            if write:
                cur = conn.cursor()
                cur.execute("SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
                cur.close()
            yield Repository(conn)
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()


class Repository:
    def __init__(self, conn):
        self.conn = conn

    def all(self, sql, params=()):
        with self.conn.cursor(as_dict=True) as cur:
            cur.execute(sql, params)
            return list(cur.fetchall())

    def one(self, sql, params=()):
        with self.conn.cursor(as_dict=True) as cur:
            cur.execute(sql, params)
            return cur.fetchone()

    def run(self, sql, params=()):
        with self.conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.rowcount

    def products(self, search=""):
        return self.all(
            """SELECT p.ProductID,p.CategoryID,c.CategoryName,p.ProductName,p.Brand,
                      p.Specification,p.SaleUnit,p.CurrentPrice,p.SaleStatus,p.ReorderLevel,
                      COALESCE(stock.AvailableQty,0) AS AvailableQty
               FROM dbo.Product p JOIN dbo.ProductCategory c ON c.CategoryID=p.CategoryID
               OUTER APPLY (
                 SELECT SUM(CASE WHEN b.BatchStatus=N'合格'
                                  AND b.ExpiryDate>CONVERT(date,GETDATE())
                                 THEN b.OnHandQty-COALESCE(r.ReservedQty,0) ELSE 0 END)
                        AS AvailableQty
                 FROM dbo.InventoryBatch b
                 JOIN dbo.PurchaseOrderItem pi ON pi.PurchaseItemID=b.PurchaseItemID
                 OUTER APPLY (
                   SELECT SUM(ir.ReservedQty) AS ReservedQty
                   FROM dbo.InventoryReservation ir
                   WHERE ir.BatchID=b.BatchID AND ir.ReservationStatus=N'有效'
                 ) r
                 WHERE pi.ProductID=p.ProductID
               ) stock
               WHERE (%s='' OR p.ProductID LIKE %s OR p.ProductName LIKE %s)
               ORDER BY p.ProductID""",
            (search, f"%{search}%", f"%{search}%"),
        )

    def product(self, product_id, lock=False):
        hint = " WITH (UPDLOCK,HOLDLOCK)" if lock else ""
        return self.one(
            "SELECT ProductID,CategoryID,ProductName,Brand,Specification,SaleUnit,"
            "CurrentPrice,SaleStatus,ReorderLevel FROM dbo.Product" + hint +
            " WHERE ProductID=%s", (product_id,)
        )

    def categories(self):
        return self.all("SELECT CategoryID,CategoryName FROM dbo.ProductCategory ORDER BY CategoryID")

    def insert_product(self, data):
        self.run(
            """INSERT dbo.Product(ProductID,CategoryID,ProductName,Brand,Specification,
                       SaleUnit,CurrentPrice,SaleStatus,ReorderLevel)
               VALUES (%s,%s,%s,%s,%s,%s,%s,N'在售',%s)""",
            (data["product_id"], data["category_id"], data["name"], data["brand"],
             data["specification"], data["unit"], data["price"], data["reorder_level"]),
        )

    def update_product(self, product_id, data):
        return self.run(
            """UPDATE dbo.Product SET CurrentPrice=%s,SaleStatus=%s,ReorderLevel=%s
               WHERE ProductID=%s""",
            (data["price"], data["status"], data["reorder_level"], product_id),
        )

    def delete_product(self, product_id):
        return self.run("DELETE FROM dbo.Product WHERE ProductID=%s", (product_id,))

    def inventory(self):
        return self.all(
            """SELECT b.BatchID,pi.ProductID,p.ProductName,b.SupplierBatchNo,
                      b.ExpiryDate,b.BatchStatus,b.OnHandQty,
                      COALESCE(r.ReservedQty,0) AS ReservedQty,
                      b.OnHandQty-COALESCE(r.ReservedQty,0) AS UnreservedQty
               FROM dbo.InventoryBatch b
               JOIN dbo.PurchaseOrderItem pi ON pi.PurchaseItemID=b.PurchaseItemID
               JOIN dbo.Product p ON p.ProductID=pi.ProductID
               OUTER APPLY (
                 SELECT SUM(ReservedQty) AS ReservedQty FROM dbo.InventoryReservation
                 WHERE BatchID=b.BatchID AND ReservationStatus=N'有效'
               ) r ORDER BY b.BatchID"""
        )

    def batches_for_product(self, product_id):
        return self.all(
            """SELECT b.BatchID,b.OnHandQty,b.ExpiryDate,b.BatchStatus,
                      COALESCE((SELECT SUM(r.ReservedQty)
                                FROM dbo.InventoryReservation r WITH (UPDLOCK,HOLDLOCK)
                                WHERE r.BatchID=b.BatchID
                                  AND r.ReservationStatus=N'有效'),0) AS ReservedQty
               FROM dbo.InventoryBatch b WITH (UPDLOCK,HOLDLOCK)
               JOIN dbo.PurchaseOrderItem pi ON pi.PurchaseItemID=b.PurchaseItemID
               WHERE pi.ProductID=%s AND b.BatchStatus=N'合格'
                 AND b.ExpiryDate>CONVERT(date,GETDATE())
               ORDER BY b.ExpiryDate,b.BatchID""", (product_id,)
        )

    def batch(self, batch_id, lock=False):
        hint = " WITH (UPDLOCK,HOLDLOCK)" if lock else ""
        return self.one(
            "SELECT BatchID,OnHandQty,BatchStatus,ExpiryDate FROM dbo.InventoryBatch" + hint +
            " WHERE BatchID=%s", (batch_id,)
        )

    def reserved_in_batch(self, batch_id):
        row = self.one(
            """SELECT COALESCE(SUM(ReservedQty),0) AS Qty
               FROM dbo.InventoryReservation WITH (UPDLOCK,HOLDLOCK)
               WHERE BatchID=%s AND ReservationStatus=N'有效'""", (batch_id,)
        )
        return int(row["Qty"])

    def change_stock(self, batch_id, delta, movement_id, operator_id, reason):
        self.run("UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+%s WHERE BatchID=%s",
                 (delta, batch_id))
        self.run(
            """INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,
                       SalesItemID,Reason,OperatorID,OccurredAt)
               VALUES (%s,%s,N'盘点调整',%s,NULL,%s,%s,SYSDATETIME())""",
            (movement_id, batch_id, delta, reason, operator_id),
        )

    def orders(self, customer_id=None):
        if customer_id is None:
            return self.all(
                """SELECT SalesOrderID,CustomerID,CreatedAt,OrderStatus,TotalAmount,
                          RecipientName,CompletedAt FROM dbo.SalesOrder
                   ORDER BY CreatedAt DESC,SalesOrderID DESC"""
            )
        return self.all(
            """SELECT SalesOrderID,CustomerID,CreatedAt,OrderStatus,TotalAmount,
                      RecipientName,CompletedAt FROM dbo.SalesOrder
               WHERE CustomerID=%s ORDER BY CreatedAt DESC,SalesOrderID DESC""",
            (customer_id,),
        )

    def order(self, order_id, lock=False):
        hint = " WITH (UPDLOCK,HOLDLOCK)" if lock else ""
        return self.one("SELECT * FROM dbo.SalesOrder" + hint + " WHERE SalesOrderID=%s",
                        (order_id,))

    def order_items(self, order_id):
        return self.all(
            """SELECT i.SalesItemID,i.ProductID,p.ProductName,i.Quantity,i.DealUnitPrice
               FROM dbo.SalesOrderItem i JOIN dbo.Product p ON p.ProductID=i.ProductID
               WHERE i.SalesOrderID=%s ORDER BY i.SalesItemID""", (order_id,)
        )

    def order_total(self, order_id):
        row = self.one(
            """SELECT SUM(CONVERT(decimal(18,2),Quantity)*DealUnitPrice) AS Total
               FROM dbo.SalesOrderItem WHERE SalesOrderID=%s""", (order_id,)
        )
        return row["Total"]

    def insert_order(self, order_id, customer_id, data, total):
        self.run(
            """INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,OrderStatus,
                       RecipientName,RecipientPhone,ShippingAddress,TotalAmount)
               VALUES (%s,%s,SYSDATETIME(),N'待支付',%s,%s,%s,%s)""",
            (order_id, customer_id, data["recipient_name"], data["recipient_phone"],
             data["shipping_address"], total),
        )

    def update_order_recipient(self, order_id, data):
        self.run(
            """UPDATE dbo.SalesOrder SET RecipientName=%s,RecipientPhone=%s,
                       ShippingAddress=%s WHERE SalesOrderID=%s""",
            (data["recipient_name"], data["recipient_phone"],
             data["shipping_address"], order_id),
        )

    def update_order_total(self, order_id, total):
        self.run("UPDATE dbo.SalesOrder SET TotalAmount=%s WHERE SalesOrderID=%s",
                 (total, order_id))

    def insert_item(self, item_id, order_id, product_id, quantity, price):
        self.run(
            """INSERT dbo.SalesOrderItem(SalesItemID,SalesOrderID,ProductID,Quantity,DealUnitPrice)
               VALUES (%s,%s,%s,%s,%s)""",
            (item_id, order_id, product_id, quantity, price),
        )

    def update_item_quantity(self, item_id, quantity):
        self.run("UPDATE dbo.SalesOrderItem SET Quantity=%s WHERE SalesItemID=%s",
                 (quantity, item_id))

    def delete_item(self, item_id):
        self.run("DELETE dbo.InventoryReservation WHERE SalesItemID=%s", (item_id,))
        self.run("DELETE dbo.SalesOrderItem WHERE SalesItemID=%s", (item_id,))

    def insert_reservation(self, reservation_id, item_id, batch_id, quantity):
        self.run(
            """INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,
                       ReservedQty,ReservationStatus,ReservedAt)
               VALUES (%s,%s,%s,%s,N'有效',SYSDATETIME())""",
            (reservation_id, item_id, batch_id, quantity),
        )

    def release_item_reservations(self, item_id):
        self.run(
            """UPDATE dbo.InventoryReservation SET ReservationStatus=N'已释放',
                       EndedAt=SYSDATETIME()
               WHERE SalesItemID=%s AND ReservationStatus=N'有效'""", (item_id,)
        )

    def release_order_reservations(self, order_id):
        self.run(
            """UPDATE r SET ReservationStatus=N'已释放',EndedAt=SYSDATETIME()
               FROM dbo.InventoryReservation r
               JOIN dbo.SalesOrderItem i ON i.SalesItemID=r.SalesItemID
               WHERE i.SalesOrderID=%s AND r.ReservationStatus=N'有效'""", (order_id,)
        )

    def set_order_status(self, order_id, status, completed=False):
        if completed:
            self.run(
                """UPDATE dbo.SalesOrder SET OrderStatus=%s,CompletedAt=SYSDATETIME()
                   WHERE SalesOrderID=%s""", (status, order_id),
            )
        else:
            self.run("UPDATE dbo.SalesOrder SET OrderStatus=%s WHERE SalesOrderID=%s",
                     (status, order_id))

    def successful_payment(self, order_id):
        return self.one(
            """SELECT PaymentID FROM dbo.PaymentRecord WITH (UPDLOCK,HOLDLOCK)
               WHERE SalesOrderID=%s AND PaymentStatus=N'成功'""", (order_id,)
        )

    def insert_payment(self, payment_id, order_id, transaction_no, amount):
        self.run(
            """INSERT dbo.PaymentRecord(PaymentID,SalesOrderID,MockTransactionNo,
                       Amount,PaymentStatus,ResultAt)
               VALUES (%s,%s,%s,%s,N'成功',SYSDATETIME())""",
            (payment_id, order_id, transaction_no, amount),
        )

    def active_reservations_for_order(self, order_id):
        return self.all(
            """SELECT r.ReservationID,r.BatchID,r.ReservedQty,i.SalesItemID,
                      i.ProductID,i.Quantity,b.OnHandQty,b.BatchStatus,b.ExpiryDate,
                      CASE WHEN b.ExpiryDate>CONVERT(date,GETDATE()) THEN 1 ELSE 0 END AS IsUnexpired,
                      pi.ProductID AS BatchProductID
               FROM dbo.SalesOrderItem i
               LEFT JOIN dbo.InventoryReservation r WITH (UPDLOCK,HOLDLOCK)
                 ON r.SalesItemID=i.SalesItemID AND r.ReservationStatus=N'有效'
               LEFT JOIN dbo.InventoryBatch b WITH (UPDLOCK,HOLDLOCK) ON b.BatchID=r.BatchID
               LEFT JOIN dbo.PurchaseOrderItem pi ON pi.PurchaseItemID=b.PurchaseItemID
               WHERE i.SalesOrderID=%s ORDER BY i.SalesItemID,r.ReservationID""",
            (order_id,),
        )

    def ship_reservation(self, reservation, movement_id, operator_id, reason):
        self.run(
            "UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty-%s WHERE BatchID=%s",
            (reservation["ReservedQty"], reservation["BatchID"]),
        )
        self.run(
            """INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,
                       SalesItemID,Reason,OperatorID,OccurredAt)
               VALUES (%s,%s,N'销售出库',%s,%s,%s,%s,SYSDATETIME())""",
            (movement_id, reservation["BatchID"], -reservation["ReservedQty"],
             reservation["SalesItemID"], reason, operator_id),
        )
        self.run(
            """UPDATE dbo.InventoryReservation SET ReservationStatus=N'已转出库',
                       EndedAt=SYSDATETIME() WHERE ReservationID=%s""",
            (reservation["ReservationID"],),
        )

    def customer(self, customer_id, lock=False):
        hint = " WITH (UPDLOCK,HOLDLOCK)" if lock else ""
        return self.one("SELECT CustomerID,IsMember,PointsBalance,ActiveStatus FROM dbo.Customer" +
                        hint + " WHERE CustomerID=%s", (customer_id,))

    def points_for_order(self, order_id):
        return self.one("SELECT PointsMovementID FROM dbo.PointsMovement WHERE SalesOrderID=%s",
                        (order_id,))

    def award_points(self, movement_id, customer_id, order_id, points, amount):
        self.run(
            """INSERT dbo.PointsMovement(PointsMovementID,CustomerID,SalesOrderID,
                       PointsDelta,BasedAmount,Reason,OccurredAt)
               VALUES (%s,%s,%s,%s,%s,N'订单完成赠分',SYSDATETIME())""",
            (movement_id, customer_id, order_id, points, amount),
        )
        self.run("UPDATE dbo.Customer SET PointsBalance=PointsBalance+%s WHERE CustomerID=%s",
                 (points, customer_id))
