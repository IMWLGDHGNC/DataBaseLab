"""Run in a fresh, dedicated LocalDB database after installing Weeks 10–12."""
from contextlib import closing
from decimal import Decimal

from sqlserver_checks import Checks, connect, install_file, rows, scalar, snapshot


checks = Checks(12)
COMPLETE = "EXEC dbo.sp_CompleteOrder ?,'P00';"
COMPLETE_FIXTURE = "EXEC dbo.sp_CompleteOrder 'W12SALE','P00';"
RECEIVE = """DECLARE @today date=CONVERT(date,GETDATE()), @expiry date=DATEADD(day,365,GETDATE());
EXEC dbo.sp_ReceivePurchase ?,'W12BR','W12-RESTOCK',@today,@expiry,'W12MR','P00',N'模拟验收',?;"""


def one(db, sql):
    return rows(db, sql)[0][0]


def order_state(db):
    return {
        "order": one(db, """SELECT OrderStatus,TotalAmount,CompletedAt FROM dbo.SalesOrder WHERE SalesOrderID='W12SALE'"""),
        "items": rows(db, """SELECT ProductID,Quantity,DealUnitPrice FROM dbo.SalesOrderItem
                               WHERE SalesOrderID='W12SALE' ORDER BY ProductID""")[0],
        "payment": one(db, """SELECT PaymentStatus,Amount FROM dbo.PaymentRecord WHERE SalesOrderID='W12SALE'"""),
        "reservations": rows(db, """SELECT BatchID,ReservedQty,ReservationStatus,EndedAt FROM dbo.InventoryReservation
                                      WHERE ReservationID IN('W12RP','W12RQ') ORDER BY BatchID""")[0],
        "stock": rows(db, """SELECT BatchID,OnHandQty FROM dbo.InventoryBatch WHERE BatchID IN('W12BP','W12BQ')
                              ORDER BY BatchID""")[0],
        "movements": rows(db, """SELECT BatchID,QuantityDelta,OperatorID FROM dbo.InventoryMovement
                                  WHERE SalesItemID IN('W12SP','W12SQ') ORDER BY BatchID""")[0],
        "audit": rows(db, """SELECT BatchID,BeforeQty,AfterQty,QuantityDelta,OperatorID FROM dbo.InventoryAudit
                              WHERE BatchID IN('W12BP','W12BQ') AND OperationType='UPDATE' ORDER BY BatchID""")[0],
        "points": rows(db, """SELECT PointsDelta,BasedAmount FROM dbo.PointsMovement WHERE SalesOrderID='W12SALE'""")[0],
        "balance": scalar(db, "SELECT PointsBalance FROM dbo.Customer WHERE CustomerID='C00'"),
    }


def receipt_state(db):
    return {
        "purchase": one(db, """SELECT OrderStatus,ReceivedAt,ReceivedBy FROM dbo.PurchaseOrder
                                  WHERE PurchaseOrderID='W12PUR'"""),
        "item": one(db, """SELECT PurchaseOrderID,PurchaseItemID,ProductID,OrderedQty
                             FROM dbo.PurchaseOrderItem WHERE PurchaseItemID='W12RI'"""),
        "stock": rows(db, """SELECT BatchID,b.PurchaseItemID,OnHandQty,ReceivedAt
                              FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem i ON i.PurchaseItemID=b.PurchaseItemID
                              WHERE i.ProductID='W12Q' ORDER BY BatchID""")[0],
        "movements": rows(db, """SELECT m.BatchID,QuantityDelta,MovementType,OperatorID,OccurredAt
                                  FROM dbo.InventoryMovement m JOIN dbo.InventoryBatch b ON b.BatchID=m.BatchID
                                  WHERE b.PurchaseItemID='W12RI'""")[0],
        "audit": rows(db, """SELECT BatchID,ProductID,BeforeQty,AfterQty,QuantityDelta,OperatorID
                              FROM dbo.InventoryAudit WHERE BatchID='W12BR'""")[0],
    }


def reject(case, operation, params, number, message, state, setup=None):
    with closing(connect()) as db:
        before, digest = state(db), snapshot(db)
        if setup:
            db.execute("BEGIN TRANSACTION; " + setup)
        inputs = state(db)
        cleanup = "ROLLBACK;" if setup else ""
        execution = rows(db, f"""BEGIN TRY
            {operation}
            SELECT 0 AS ErrorNumber;
        END TRY BEGIN CATCH
            DECLARE @beforeCleanup int=XACT_STATE();
            {cleanup}
            SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage,
                @@TRANCOUNT AS TranCount, XACT_STATE() AS XactState, @beforeCleanup AS BeforeCleanup;
        END CATCH;""", params)[-1][0]
        after = state(db)
        unchanged = digest == snapshot(db)
        expected = {"error": number, "message_fragment": message, "open_transactions": 0,
                    "xact_state": 0, "state_before_caller_cleanup": -1 if setup else 0,
                    "all_dbo_tables_restored": True}
        actual = {"error": execution["ErrorNumber"], "message": execution.get("ErrorMessage", ""),
                  "open_transactions": execution.get("TranCount"), "xact_state": execution.get("XactState"),
                  "state_before_caller_cleanup": execution.get("BeforeCleanup"),
                  "all_dbo_tables_restored": unchanged, "after": after}
        checks.check(case, execution["ErrorNumber"] == number and message in actual["message"]
                     and execution["TranCount"] == execution["XactState"] == 0
                     and execution["BeforeCleanup"] == expected["state_before_caller_cleanup"]
                     and unchanged and after == before,
                     actual, expected)
        checks.results[-1]["initial"] = inputs
        checks.results[-1]["operation"] = {"sql": operation, "parameters": params}
        if setup:
            checks.results[-1]["setup"] = setup


with closing(connect()) as db:
    if scalar(db, "SELECT COUNT(*) FROM dbo.ProductCategory WHERE CategoryID='W12ROOT'"):
        raise SystemExit("Use a fresh sample database for Test-Week12.py")
    install_file(db, "sql/week12/test_data.sql")
    hierarchy = {
        "W12ROOT": [("W12A", "W12ROOT", 1, "/W12ROOT/W12A"),
                    ("W12B", "W12ROOT", 1, "/W12ROOT/W12B"),
                    ("W12LEAF", "W12A", 2, "/W12ROOT/W12A/W12LEAF")],
        "W12A": [("W12LEAF", "W12A", 1, "/W12A/W12LEAF")],
        "W12LEAF": [],
        "W12NONE": [],
    }
    for start, expected in hierarchy.items():
        result = rows(db, "EXEC dbo.sp_CategoryDescendants ?", (start,))[0]
        checks.check("category_" + start, [tuple(row.values()) for row in result] == expected, result, expected)

    # The FK permits indirect cycles. The visited-ID guard must prune the return to the anchor.
    before = snapshot(db)
    db.execute("BEGIN TRANSACTION; UPDATE dbo.ProductCategory SET ParentCategoryID='W12LEAF' WHERE CategoryID='W12ROOT';")
    result = rows(db, "EXEC dbo.sp_CategoryDescendants 'W12ROOT'")[0]
    db.execute("ROLLBACK;")
    checks.check("category_cycle_stops", [tuple(row.values()) for row in result] == hierarchy["W12ROOT"]
                 and snapshot(db) == before, result, hierarchy["W12ROOT"])

    opening = order_state(db)
    checks.check("starting_order", [r["OnHandQty"] for r in opening["stock"]] == [20, 15]
                 and [r["ReservedQty"] for r in opening["reservations"]] == [3, 4]
                 and opening["order"]["OrderStatus"] == "待出库" and opening["payment"]["Amount"] == 27,
                 opening, "P=20 Q=15, reserved P=3 Q=4, paid 27.00, pending shipment")

reject("order_not_found", COMPLETE, ("W12NONE",), 51802, "Order not found", order_state)
reject("order_no_items", COMPLETE_FIXTURE, (), 51804, "no items", order_state, """
    DELETE dbo.InventoryReservation WHERE ReservationID IN('W12RP','W12RQ');
    DELETE dbo.SalesOrderItem WHERE SalesOrderID='W12SALE';""")
reject("order_insufficient_stock", COMPLETE_FIXTURE, (), 51804, "overcommitted", order_state, """
    UPDATE dbo.SalesOrderItem SET Quantity=21 WHERE SalesItemID='W12SP';
    UPDATE dbo.InventoryReservation SET ReservedQty=21 WHERE ReservationID='W12RP';
    UPDATE dbo.SalesOrder SET TotalAmount=117 WHERE SalesOrderID='W12SALE';
    UPDATE dbo.PaymentRecord SET Amount=117 WHERE SalesOrderID='W12SALE';""")

# The error is only thrown if the trigger can see all prior writes.
with closing(connect()) as db:
    db.execute("""CREATE TRIGGER dbo.tr_Week12OrderFault ON dbo.PointsMovement AFTER INSERT AS
        BEGIN
            SET NOCOUNT ON;
            IF NOT EXISTS(SELECT 1 FROM inserted WHERE SalesOrderID='W12SALE') RETURN;
            IF (SELECT COUNT(*) FROM dbo.InventoryBatch WHERE (BatchID='W12BP' AND OnHandQty=17)
                 OR (BatchID='W12BQ' AND OnHandQty=11))=2
              AND (SELECT COUNT(*) FROM dbo.InventoryAudit WHERE OperationType='UPDATE'
                 AND ((BatchID='W12BP' AND QuantityDelta=-3) OR (BatchID='W12BQ' AND QuantityDelta=-4)))=2
              AND (SELECT COUNT(*) FROM dbo.InventoryMovement WHERE SalesItemID IN('W12SP','W12SQ'))=2
              AND EXISTS(SELECT 1 FROM dbo.SalesOrder WHERE SalesOrderID='W12SALE' AND OrderStatus=N'已完成')
                THROW 51920,'Injected after stock, audit, movement and order status writes.',1;
            THROW 51929,'Test did not reach the expected shipment fault point.',1;
        END;""")
try:
    reject("order_midway_rollback", COMPLETE, ("W12SALE",), 51920, "after stock", order_state)
finally:
    with closing(connect()) as db:
        db.execute("DROP TRIGGER dbo.tr_Week12OrderFault;")

with closing(connect()) as db:
    before = order_state(db)
    install_file(db, "sql/week12/order_transaction.sql")
    checks.check("order_caller_transaction_closed", scalar(db, "SELECT @@TRANCOUNT") == 0)
with closing(connect()) as db:
    after = order_state(db)
    expected_audit = [
        {"BatchID": "W12BP", "BeforeQty": 20, "AfterQty": 17, "QuantityDelta": -3, "OperatorID": "P00"},
        {"BatchID": "W12BQ", "BeforeQty": 15, "AfterQty": 11, "QuantityDelta": -4, "OperatorID": "P00"},
    ]
    checks.check("order_committed_visible_to_new_connection",
                 after["order"]["OrderStatus"] == "已完成" and after["order"]["CompletedAt"] is not None
                 and after["order"]["TotalAmount"] == before["order"]["TotalAmount"] == 27
                 and after["payment"] == before["payment"] and after["items"] == before["items"]
                 and [r["OnHandQty"] for r in after["stock"]] == [17, 11]
                 and all(r["ReservationStatus"] == "已转出库" and r["EndedAt"] is not None for r in after["reservations"])
                 and [m["QuantityDelta"] for m in after["movements"]] == [-3, -4]
                 and after["audit"] == expected_audit and after["points"] == [{"PointsDelta": 27, "BasedAmount": Decimal(27)}]
                 and after["balance"] == before["balance"] + 27, after,
                 "P=17 Q=11, completed 27.00, reserves consumed, two movements and audit rows, +27 points")
    checks.results[-1]["initial"] = before
    checks.results[-1]["operation"] = "order_transaction.sql"
reject("order_repeat", COMPLETE, ("W12SALE",), 51804, "already been completed", order_state)

for name, item, quantity, error, message in [
    ("unknown_item", "W12NONE", 7, 51802, "not found"),
    ("pending_approval", "W12PI", 7, 51804, "approved"),
    ("zero_quantity", "W12RI", 0, 51801, "quantity"),
    ("negative_quantity", "W12RI", -1, 51801, "quantity"),
    ("quantity_mismatch", "W12RI", 8, 51801, "equal the approved quantity"),
]:
    reject("restock_" + name, RECEIVE, (item, quantity), error, message, receipt_state)

with closing(connect()) as db:
    db.execute("""CREATE TRIGGER dbo.tr_Week12ReceiptFault ON dbo.InventoryMovement AFTER INSERT AS
        BEGIN
            SET NOCOUNT ON;
            IF NOT EXISTS(SELECT 1 FROM inserted WHERE MovementID='W12MR') RETURN;
            IF EXISTS(SELECT 1 FROM dbo.InventoryBatch WHERE BatchID='W12BR' AND OnHandQty=7)
              AND EXISTS(SELECT 1 FROM dbo.InventoryAudit WHERE BatchID='W12BR' AND QuantityDelta=7)
              AND EXISTS(SELECT 1 FROM dbo.PurchaseOrder WHERE PurchaseOrderID='W12PUR'
                         AND OrderStatus=N'已批准' AND ReceivedAt IS NULL)
                THROW 51921,'Injected after stock and audit writes and before receipt status update.',1;
            THROW 51929,'Test did not reach the expected receipt fault point.',1;
        END;""")
try:
    reject("restock_midway_rollback", RECEIVE, ("W12RI", 7), 51921, "before receipt status", receipt_state)
finally:
    with closing(connect()) as db:
        db.execute("DROP TRIGGER dbo.tr_Week12ReceiptFault;")

with closing(connect()) as db:
    before, digest = receipt_state(db), snapshot(db)
    db.execute("BEGIN TRANSACTION;")
    rows(db, RECEIVE, ("W12RI", 7))
    nested = {"open_transactions": scalar(db, "SELECT @@TRANCOUNT"), "receipt": receipt_state(db)}
    db.execute("ROLLBACK;")
    checks.check("restock_outer_transaction_controls_commit", nested["open_transactions"] == 1
                 and nested["receipt"]["purchase"]["OrderStatus"] == "已收货" and digest == snapshot(db),
                 nested, "caller still owns one transaction and can roll back all rows")
    db.execute("EXEC sys.sp_set_session_context @key=N'OperatorID', @value='P01';")
    result = rows(db, RECEIVE, ("W12RI", 7))[-1][0]
    checks.check("restock_caller_transaction_closed_and_actor_restored",
                 one(db, "SELECT @@TRANCOUNT AS Tx, CONVERT(varchar(12),SESSION_CONTEXT(N'OperatorID')) AS Actor")
                 == {"Tx": 0, "Actor": "P01"})
with closing(connect()) as db:
    after = receipt_state(db)
    timestamp = after["purchase"]["ReceivedAt"]
    checks.check("restock_committed_visible_to_new_connection",
                 result == {"PurchaseOrderID": "W12PUR", "BatchID": "W12BR", "ProductID": "W12Q",
                            "ReceivedQty": 7, "OrderStatus": "已收货"}
                 and after["purchase"] == {"OrderStatus": "已收货", "ReceivedAt": timestamp, "ReceivedBy": "P00"}
                 and after["item"] == before["item"]
                 and sum(r["OnHandQty"] for r in after["stock"]) == sum(r["OnHandQty"] for r in before["stock"]) + 7
                 and after["stock"][-1] == {"BatchID": "W12BR", "PurchaseItemID": "W12RI", "OnHandQty": 7, "ReceivedAt": timestamp}
                 and timestamp is not None and after["movements"] == [{"BatchID": "W12BR", "QuantityDelta": 7,
                     "MovementType": "采购入库", "OperatorID": "P00", "OccurredAt": timestamp}]
                 and after["audit"] == [{"BatchID": "W12BR", "ProductID": "W12Q", "BeforeQty": None,
                     "AfterQty": 7, "QuantityDelta": 7, "OperatorID": "P00"}], after,
                 "Q increases 11→18, received with one batch, movement and audit row")
    checks.results[-1]["initial"] = before
    checks.results[-1]["operation"] = {"sql": RECEIVE, "parameters": ["W12RI", 7]}
reject("restock_repeat", RECEIVE, ("W12RI", 7), 51804, "already been received", receipt_state)

checks.finish()
