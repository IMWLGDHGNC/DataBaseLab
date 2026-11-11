"""SQL Server procedure/function, atomicity, permission, and Web integration tests."""
from decimal import Decimal
import sys

from sqlserver_checks import Checks, connect, fixture, rows, scalar, snapshot, ROOT

sys.path.insert(0, str(ROOT))
c = Checks(10)
with connect() as db:
    summary = rows(db, "EXEC dbo.sp_SalesStatistics '2026-09-16','2026-09-16'")
    c.check("inclusive_sales_date", summary[0][0] == {"OrderCount": 2, "SalesAmount": Decimal("64.50"), "SalesQty": 15}, summary[0], "2 orders / 15 items / 64.50")
    c.check("tvf_matches_statistics", summary[1] == rows(db, "SELECT * FROM dbo.fn_SalesSummary('2026-09-16','2026-09-16') ORDER BY ProductID")[0], summary[1], "S00:2/4.00; S01:10/44.00; S02:3/16.50")
    empty = rows(db, "EXEC dbo.sp_SalesStatistics '1900-01-01','1900-01-01'")
    c.check("no_sales_returns_zero_and_empty", empty[0][0] == {"OrderCount": 0, "SalesAmount": Decimal(0), "SalesQty": 0} and empty[1] == [], empty, "zero totals and empty detail")
    for product, target, expected in [("S01",300,10),("S01",10,0),("S02",None,20),("missing",20,None),(None,20,None),("S01",-1,None)]:
        actual = scalar(db, "SELECT dbo.fn_ReplenishmentQty(?,?)", (product,target))
        c.check(f"replenishment_{product}_{target}", actual == expected, actual, expected)
    c.check("scalar_invalid_discount", scalar(db, "SELECT dbo.fn_DiscountAmount(100,1.0)") is None, None, None)
    for amount, rate, expected in [(100,Decimal('.05'),Decimal('5.00')),(0,0,0),(-1,0,None),(None,0,None),(100,None,None),(100,Decimal('-.01'),None)]:
        actual = scalar(db, "SELECT dbo.fn_DiscountAmount(?,?)", (amount,rate))
        c.check(f"discount_{amount}_{rate}", actual == expected, actual, expected)
    c.check("member_nonmember_unknown_rates", rows(db,"SELECT dbo.fn_DiscountRate('C00') member,dbo.fn_DiscountRate('C02') nonmember,dbo.fn_DiscountRate('missing') unknown")[0][0] == {"member":Decimal('.05'),"nonmember":Decimal(0),"unknown":None})
    c.check("tvf_invalid_range_empty", rows(db,"SELECT * FROM dbo.fn_SalesSummary('2026-10-01','2026-09-01')")[0] == [])
    db.execute("BEGIN TRANSACTION")
    before = scalar(db,"SELECT OnHandQty FROM dbo.InventoryBatch WHERE BatchID='B00'")
    a = rows(db,"EXEC dbo.sp_AdjustInventory 'S01',5,N'模拟盘点增加','P00'")[0][0]
    b = rows(db,"EXEC dbo.sp_AdjustInventory 'S01',-5,N'模拟盘点减少','P00'")[0][0]
    c.check("adjust_repeat_calls", a["AfterQty"] == before+5 and b["AfterQty"] == before, [a,b], "+5 then -5")
    c.check("adjust_movement_pair", scalar(db,"SELECT COUNT(*) FROM dbo.InventoryMovement WHERE Reason IN(N'模拟盘点增加',N'模拟盘点减少')") == 2)
    c.check("procedure_does_not_commit_outer", scalar(db,"SELECT @@TRANCOUNT") == 1)
    db.execute("ROLLBACK")
    for customer, expected in [("C00",Decimal('8.36')),("C02",Decimal('8.80'))]:
        db.execute("BEGIN TRANSACTION")
        order,item,_=fixture(db,customer,False)
        actual=rows(db,"EXEC dbo.sp_PriceOrder ?,0",(order,))[0][0]
        c.check("pricing_repeat_"+customer, actual["TotalAmount"] == expected, actual, str(expected))
        db.execute("UPDATE dbo.Product SET CurrentPrice=8 WHERE ProductID='S01'")
        c.check("price_snapshot_"+customer, scalar(db,"SELECT DealUnitPrice FROM dbo.SalesOrderItem WHERE SalesItemID=?",(item,)) == expected/2)
        db.execute("ROLLBACK")
    db.execute("BEGIN TRANSACTION")
    order,item,_=fixture(db)
    before_stock=scalar(db,"SELECT OnHandQty FROM dbo.InventoryBatch WHERE BatchID='B00'")
    before_points=scalar(db,"SELECT PointsBalance FROM dbo.Customer WHERE CustomerID='C00'")
    rows(db,"EXEC dbo.sp_CompleteOrder ?,'P00'",(order,))
    c.check("complete_stock_and_points", scalar(db,"SELECT OnHandQty FROM dbo.InventoryBatch WHERE BatchID='B00'") == before_stock-2 and scalar(db,"SELECT PointsBalance FROM dbo.Customer WHERE CustomerID='C00'") == before_points+8)
    c.check("complete_status_and_movements", scalar(db,"SELECT OrderStatus FROM dbo.SalesOrder WHERE SalesOrderID=?",(order,)) == "已完成" and scalar(db,"SELECT SUM(QuantityDelta) FROM dbo.InventoryMovement WHERE SalesItemID=?",(item,)) == -2)
    db.execute("ROLLBACK")

for start,end in [(None,'2026-09-16'),('2026-10-01','2026-09-01')]:
    c.error("statistics_invalid_"+str(start),"EXEC dbo.sp_SalesStatistics ?,?",(start,end))
for name,product,delta,reason,operator,batch,error in [
    ('zero','S01',0,'模拟','P00',None,51801),('null_qty','S01',None,'模拟','P00',None,51801),
    ('null_reason','S01',1,None,'P00',None,51801),('empty_reason','S01',1,'  ','P00',None,51801),
    ('unknown','missing',1,'模拟','P00',None,51802),('unknown_employee','S01',1,'模拟','missing',None,51803),
    ('stock_shortage','S01',-999,'模拟','P00',None,51804),('reserved_stock','S02',-36,'模拟','P00',None,51804),
    ('wrong_batch','S01',1,'模拟','P00','B02',51802)]:
    c.error('adjust_'+name,"EXEC dbo.sp_AdjustInventory ?,?,?,?,?",(product,delta,reason,operator,batch),error)
c.error("replenishment_unknown","EXEC dbo.sp_SelectReplenishment 'missing',20")
c.error("replenishment_negative","EXEC dbo.sp_SelectReplenishment 'S01',-1")
c.error("complete_unknown","EXEC dbo.sp_CompleteOrder 'missing','P00'",expected=51802)
c.error("complete_null","EXEC dbo.sp_CompleteOrder NULL,'P00'",expected=51802)
c.error("complete_invalid_employee","EXEC dbo.sp_CompleteOrder 'ST02',NULL",expected=51803)
c.error("complete_expired_batch","EXEC dbo.sp_CompleteOrder 'ST02','P00'",expected=51804)
c.error("complete_repeated","EXEC dbo.sp_CompleteOrder 'ST00','P00'",expected=51804)
c.error("price_unknown","EXEC dbo.sp_PriceOrder 'missing'",expected=51804)

# Inject a failure after stock, movement, reservation and status writes. The
# entire caller transaction, including fixture rows, must disappear.
with connect() as db:
    db.execute("""CREATE OR ALTER TRIGGER dbo.tr_TestPointsFailure ON dbo.PointsMovement AFTER INSERT AS
        THROW 59000,'Deliberate test failure after shipment writes.',1;""")
try:
    state={}
    def setup(db):
        state['order']=fixture(db)[0]
    # Execute using a SQL variable to locate this fixture without exposing IDs.
    c.error("complete_injected_failure", """DECLARE @id varchar(12)=(SELECT TOP(1) SalesOrderID
        FROM dbo.SalesOrder WHERE SalesOrderID LIKE 'SO%' ORDER BY CreatedAt DESC,SalesOrderID);
        EXEC dbo.sp_CompleteOrder @id,'P00';""", expected=59000, setup=setup)
finally:
    with connect() as db:
        db.execute("DROP TRIGGER dbo.tr_TestPointsFailure")

from week10_web import run_web_checks
run_web_checks(c)
c.finish()
