"""Set-based trigger and independently calculated window-query checks."""
from decimal import Decimal
import secrets

from sqlserver_checks import Checks, connect, fixture, rows, scalar, snapshot, ROOT

c=Checks(11)
with connect() as db:
    before=snapshot(db)
    db.execute('BEGIN TRANSACTION')
    db.execute("EXEC sys.sp_set_session_context @key=N'OperatorID',@value='P00'")
    audit_start=scalar(db,'SELECT COALESCE(MAX(AuditID),0) FROM dbo.InventoryAudit')
    db.execute("UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+5 WHERE BatchID='B00'")
    audit=rows(db,'SELECT * FROM dbo.InventoryAudit WHERE AuditID>?',(audit_start,))[0]
    c.check('audit_single_update',len(audit)==1 and audit[0]['QuantityDelta']==5 and audit[0]['OperatorID']=='P00' and audit[0]['OperationType']=='UPDATE',
            [{k:r[k] for k in ('BatchID','ProductID','BeforeQty','AfterQty','QuantityDelta','OperatorID','OperationType')} for r in audit],'+5 / P00 / UPDATE')
    db.execute("UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+2 WHERE BatchID IN('B00','B02')")
    c.check('audit_multirow_update',scalar(db,'SELECT COUNT(*) FROM dbo.InventoryAudit WHERE AuditID>?',(audit_start,))==3)
    db.execute("UPDATE dbo.InventoryBatch SET BatchStatus=N'隔离' WHERE BatchID='B00'")
    c.check('audit_quality_change_zero_delta',scalar(db,"SELECT COUNT(*) FROM dbo.InventoryAudit WHERE AuditID>? AND QuantityDelta=0 AND AfterStatus=N'隔离'",(audit_start,))==1)
    count=scalar(db,'SELECT COUNT(*) FROM dbo.InventoryAudit')
    db.execute("UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty WHERE BatchID='B02'")
    db.execute("UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+1 WHERE BatchID='missing'")
    c.check('audit_noop_and_zero_rows',scalar(db,'SELECT COUNT(*) FROM dbo.InventoryAudit')==count)
    ids=['BT'+secrets.token_hex(4).upper() for _ in range(3)]
    insert="""INSERT dbo.InventoryBatch(BatchID,PurchaseItemID,SupplierBatchNo,ProductionDate,ExpiryDate,ReceivedAt,OnHandQty,BatchStatus)
        VALUES(?,'PDI00',?,CONVERT(date,GETDATE()),DATEADD(day,365,CONVERT(date,GETDATE())),SYSDATETIME(),?,N'合格')"""
    db.execute(insert,ids[0],ids[0],7)
    c.check('audit_single_insert',scalar(db,"SELECT QuantityDelta FROM dbo.InventoryAudit WHERE BatchID=? AND OperationType='INSERT'",(ids[0],))==7)
    db.execute("""INSERT dbo.InventoryBatch(BatchID,PurchaseItemID,SupplierBatchNo,ProductionDate,ExpiryDate,ReceivedAt,OnHandQty,BatchStatus)
        SELECT v.id,'PDI00',v.id,CONVERT(date,GETDATE()),DATEADD(day,365,CONVERT(date,GETDATE())),SYSDATETIME(),v.qty,N'合格'
        FROM (VALUES(?,8),(?,9)) v(id,qty)""",ids[1],ids[2])
    c.check('audit_multirow_insert',scalar(db,"SELECT COUNT(*) FROM dbo.InventoryAudit WHERE BatchID IN(?,?) AND OperationType='INSERT'",tuple(ids[1:]))==2)
    db.execute('DELETE dbo.InventoryBatch WHERE BatchID=?',ids[0])
    c.check('audit_single_delete',scalar(db,"SELECT QuantityDelta FROM dbo.InventoryAudit WHERE BatchID=? AND OperationType='DELETE'",(ids[0],))==-7)
    db.execute('DELETE dbo.InventoryBatch WHERE BatchID IN(?,?)',ids[1],ids[2])
    c.check('audit_multirow_delete_history_retained',scalar(db,"SELECT COUNT(*) FROM dbo.InventoryAudit WHERE BatchID IN(?,?) AND OperationType='DELETE'",tuple(ids[1:]))==2)
    c.check('audit_timestamp_and_before_after',scalar(db,'SELECT COUNT(*) FROM dbo.InventoryAudit WHERE AuditID>? AND (OccurredAt IS NULL OR QuantityDelta<>CONVERT(bigint,COALESCE(AfterQty,0))-COALESCE(BeforeQty,0))',(audit_start,))==0)
    db.execute('ROLLBACK')
    c.check('audit_rolls_back_with_inventory',before==snapshot(db))
    # SESSION_CONTEXT is connection state, not transactional row data.
    db.execute("EXEC sys.sp_set_session_context @key=N'OperatorID',@value=NULL")
    db.execute('BEGIN TRANSACTION')
    db.execute("UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+1 WHERE BatchID='B00'")
    c.check('audit_sql_actor_without_private_login',scalar(db,"SELECT COUNT(*) FROM dbo.InventoryAudit WHERE AuditID>? AND ActorType='SQL' AND OperatorID IS NULL",(audit_start,))==1)
    db.execute('ROLLBACK')

c.error('inventory_multirow_invalid_rolls_back_all',"UPDATE dbo.InventoryBatch SET OnHandQty=CASE WHEN BatchID='B01' THEN 0 ELSE OnHandQty+1 END WHERE BatchID IN('B00','B01')",expected=51811)
c.error('inventory_negative_constraint',"UPDATE dbo.InventoryBatch SET OnHandQty=-1 WHERE BatchID='B00'",expected=547)
c.error('inventory_source_immutable',"UPDATE dbo.InventoryBatch SET PurchaseItemID='PDI01' WHERE BatchID='B00'",expected=51811)
c.error('completed_order_repeat_trigger',"UPDATE dbo.SalesOrder SET OrderStatus=N'已完成' WHERE SalesOrderID='ST00'",expected=51812)
c.error('completed_order_reverse_trigger',"UPDATE dbo.SalesOrder SET OrderStatus=N'待出库',CompletedAt=NULL WHERE SalesOrderID='ST00'",expected=51812)
c.error('completed_amount_immutable',"UPDATE dbo.SalesOrder SET TotalAmount=49 WHERE SalesOrderID='ST00'",expected=51812)
c.error('direct_completion_without_shipment',"UPDATE dbo.SalesOrder SET OrderStatus=N'已完成',CompletedAt=SYSDATETIME() WHERE SalesOrderID='ST02'",expected=51812)
c.error('completed_insert_refused',"""INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,OrderStatus,CompletedAt,RecipientName,RecipientPhone,ShippingAddress,TotalAmount)
    VALUES('W11INVALID','C00',SYSDATETIME(),N'已完成',SYSDATETIME(),N'模拟','10000000000',N'模拟',1)""",expected=51812)


def ship_without_status(db,order):
    """Prepare physical shipment; final status is deliberately one separate batch."""
    db.execute("""UPDATE r SET ReservationStatus=N'已转出库',EndedAt=SYSDATETIME()
        FROM dbo.InventoryReservation r JOIN dbo.SalesOrderItem i ON i.SalesItemID=r.SalesItemID
        WHERE i.SalesOrderID=? AND r.ReservationStatus=N'有效'""",order)
    db.execute("""UPDATE b SET OnHandQty=OnHandQty-s.Qty FROM dbo.InventoryBatch b JOIN
        (SELECT r.BatchID,SUM(r.ReservedQty) Qty FROM dbo.InventoryReservation r
         JOIN dbo.SalesOrderItem i ON i.SalesItemID=r.SalesItemID WHERE i.SalesOrderID=?
         AND r.ReservationStatus=N'已转出库' GROUP BY r.BatchID) s ON s.BatchID=b.BatchID""",order)
    db.execute("""INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,SalesItemID,Reason,OperatorID,OccurredAt)
        SELECT 'IM'+LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),10),r.BatchID,N'销售出库',-r.ReservedQty,i.SalesItemID,N'模拟批量出库','P00',SYSDATETIME()
        FROM dbo.InventoryReservation r JOIN dbo.SalesOrderItem i ON i.SalesItemID=r.SalesItemID WHERE i.SalesOrderID=? AND r.ReservationStatus=N'已转出库'""",order)


state={}
def two_orders(db):
    state['one']=fixture(db)[0]
    state['two']=fixture(db,customer='C02')[0]
    ship_without_status(db,state['one'])
    ship_without_status(db,state['two'])

with connect() as db:
    before=snapshot(db)
    db.execute('BEGIN TRANSACTION')
    two_orders(db)
    db.execute("UPDATE dbo.SalesOrder SET OrderStatus=N'已完成',CompletedAt=SYSDATETIME() WHERE SalesOrderID IN(?,?)",state['one'],state['two'])
    c.check('valid_multirow_completion',scalar(db,"SELECT COUNT(*) FROM dbo.SalesOrder WHERE SalesOrderID IN(?,?) AND OrderStatus=N'已完成'",(state['one'],state['two']))==2)
    db.execute('ROLLBACK')
    c.check('valid_bulk_demo_rolled_back',snapshot(db)==before)


def bad_amount(db):
    two_orders(db)
    db.execute('UPDATE dbo.SalesOrder SET TotalAmount=TotalAmount+1 WHERE SalesOrderID=?',state['two'])

bulk="""UPDATE dbo.SalesOrder SET OrderStatus=N'已完成',CompletedAt=SYSDATETIME()
 WHERE SalesOrderID LIKE 'SO%' AND OrderStatus=N'待出库'"""
c.error('bulk_one_bad_amount_refuses_all',bulk,expected=51812,setup=bad_amount)


def bad_payment(db):
    two_orders(db)
    db.execute('UPDATE dbo.PaymentRecord SET Amount=Amount+1 WHERE SalesOrderID=?',state['two'])
c.error('bulk_bad_payment_refuses_all',bulk,expected=51812,setup=bad_payment)


def no_items(db):
    order,item,res=fixture(db)
    db.execute('DELETE dbo.InventoryReservation WHERE ReservationID=?',res)
    db.execute('DELETE dbo.SalesOrderItem WHERE SalesItemID=?',item)
c.error('empty_order_completion',bulk,expected=51812,setup=no_items)


def wrong_product(db):
    order,item,_=fixture(db)
    ship_without_status(db,order)
    db.execute("UPDATE dbo.SalesOrderItem SET ProductID='S00' WHERE SalesItemID=?",item)
c.error('shipment_product_mismatch',bulk,expected=51812,setup=wrong_product)


def wrong_qty(db):
    order,item,_=fixture(db)
    ship_without_status(db,order)
    db.execute('UPDATE dbo.SalesOrderItem SET Quantity=3 WHERE SalesItemID=?',item)
    db.execute('UPDATE dbo.SalesOrder SET TotalAmount=12.54,DiscountAmount=.66 WHERE SalesOrderID=?',order)
    db.execute('UPDATE dbo.PaymentRecord SET Amount=12.54 WHERE SalesOrderID=?',order)
c.error('shipment_quantity_mismatch',bulk,expected=51812,setup=wrong_qty)


def no_stock(db):
    order,_,_=fixture(db)
    ship_without_status(db,order)
    db.execute("UPDATE dbo.InventoryBatch SET BatchStatus=N'隔离' WHERE BatchID='B00'")
c.error('shipment_batch_unavailable',bulk,expected=51812,setup=no_stock)


def ledger_mismatch(db):
    order,_,_=fixture(db)
    ship_without_status(db,order)
    db.execute("UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+1 WHERE BatchID='B00'")
c.error('shipment_stock_ledger_mismatch',bulk,expected=51812,setup=ledger_mismatch)


# Quantity <=0 is rejected even earlier by the existing table CHECK constraint.
# Execute the invalid update in the checked command so its rollback is verified.
c.error('invalid_order_quantity_constraint',"UPDATE dbo.SalesOrderItem SET Quantity=0 WHERE SalesItemID='SI03'",expected=547)

# Four additional simulated completions provide full three-order windows and
# equal completion timestamps. Keep triggers enabled throughout the fixture.
with connect() as db:
    before=snapshot(db)
    db.execute('BEGIN TRANSACTION')
    testorders=[]
    for qty in (1,2,3,4):
        order,item,_=fixture(db,customer='C02',quantity=qty)
        if qty==1:
            db.execute('UPDATE dbo.SalesOrderItem SET DealUnitPrice=44,ListUnitPrice=44 WHERE SalesItemID=?',item)
            db.execute('UPDATE dbo.SalesOrder SET TotalAmount=44 WHERE SalesOrderID=?',order)
            db.execute('UPDATE dbo.PaymentRecord SET Amount=44 WHERE SalesOrderID=?',order)
        # Set dates while editable; test source completion happens legitimately.
        db.execute("UPDATE dbo.SalesOrder SET CreatedAt='2026-09-19T10:00:00' WHERE SalesOrderID=?",order)
        ship_without_status(db,order)
        db.execute("UPDATE dbo.InventoryReservation SET ReservedAt='2026-09-19T10:00:00',EndedAt='2026-09-20T10:00:00' WHERE SalesItemID=?",item)
        db.execute("UPDATE dbo.InventoryMovement SET OccurredAt='2026-09-20T10:00:00' WHERE SalesItemID=?",item)
        db.execute("UPDATE dbo.PaymentRecord SET ResultAt='2026-09-19T11:00:00' WHERE SalesOrderID=?",order)
        db.execute("UPDATE dbo.SalesOrder SET OrderStatus=N'已完成',CompletedAt='2026-09-20T10:00:00' WHERE SalesOrderID=?",order)
        testorders.append(order)
    query=(ROOT/'sql/week11/window_query.sql').read_text(encoding='utf-8')
    result=rows(db,query)
    base=rows(db,"SELECT SalesOrderID,CompletedAt,TotalAmount FROM dbo.SalesOrder WHERE OrderStatus=N'已完成' AND CompletedAt>='2026-09-01' AND CompletedAt<'2026-10-01' ORDER BY CompletedAt,SalesOrderID")[0]
    c.check('window_preserves_order_rows',len(result[1])==len(base)==6 and len(result[2])==6)
    amounts=[r['TotalAmount'] for r in base]
    cumulative=[];running=Decimal(0)
    for amount in amounts:
        running+=amount;cumulative.append(running)
    c.check('cumulative_independent_calculation',[r['CumulativeAmount'] for r in result[1]]==cumulative,[str(r['CumulativeAmount']) for r in result[1]],[str(x) for x in cumulative])
    expected=[sum(amounts[max(0,i-2):i+1])/len(amounts[max(0,i-2):i+1]) for i in range(len(amounts))]
    c.check('moving_average_three_orders',all(abs(r['MovingAverage3Orders']-v)<Decimal('.000002') for r,v in zip(result[2],expected)),
            [str(r['MovingAverage3Orders']) for r in result[2]],[str(v) for v in expected])
    c.check('moving_window_counts',[r['WindowOrders'] for r in result[2]]==[1,2,3,3,3,3])
    actual_amounts={r['ProductID']:r['SalesAmount'] for r in result[0]}
    ranks={amount:i+1 for i,amount in enumerate(sorted(set(actual_amounts.values()),reverse=True))}
    c.check('rank_independent_calculation',all(r['RevenueRank']==ranks[r['SalesAmount']] for r in result[0]),result[0], 'descending revenue dense ranks')
    # The main rank calculation is above; tie semantics are also checked with
    # synthetic amounts without mutating historical completed financial data.
    tie=rows(db,"SELECT x,DENSE_RANK() OVER(ORDER BY amount DESC) r FROM (VALUES('A',10),('B',10),('C',5)) v(x,amount) ORDER BY x")[0]
    c.check('dense_rank_ties_no_gap',[r['r'] for r in tie]==[1,1,2],tie,'1,1,2')
    (ROOT/'output/week11').mkdir(parents=True,exist_ok=True)
    import json
    (ROOT/'output/week11/window-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,default=str),encoding='utf-8')
    db.execute('ROLLBACK')
    c.check('window_fixture_rolled_back',before==snapshot(db))

# Re-run all changed application paths under installed triggers.
from week10_web import run_web_checks
run_web_checks(c)
c.finish()
