"""Run the real Flask service and DAO SQL against LocalDB with restricted users.

Only the pymssql transport is adapted to Windows ODBC. Production transport
and Linux/Gunicorn are separate validation environments.
"""
from contextlib import contextmanager
from datetime import date, datetime
from decimal import Decimal
import re
import secrets

import pyodbc
import pymssql
from werkzeug.security import generate_password_hash

from sqlserver_checks import connect, install_file, rows, scalar, ROOT, DB


class Cursor:
    def __init__(self, conn, as_dict=False):
        self.raw, self.as_dict = conn.raw.cursor(), as_dict

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def close(self):
        self.raw.close()

    @property
    def rowcount(self):
        return self.raw.rowcount

    def execute(self, sql, params=()):
        try:
            self.raw.execute(sql.replace("%s", "?"), tuple(x.isoformat() if isinstance(x,date) and not isinstance(x,datetime) else x for x in params))
        except pyodbc.Error as exc:
            (ROOT/'output/week10/driver-private.txt').write_text(str(exc), encoding='utf-8')
            numbers = [int(n) for n in re.findall(r"\((\d+)\)", str(exc))]
            known = {2601,2627,547,515,8115,1205,1222,51701,51801,51802,51803,51804,51811,51812,59000}
            number = next((n for n in numbers if n in known), 20009)
            raise pymssql.OperationalError(number, b"LocalDB test transport SQL error") from None
        return self

    def fetchall(self):
        names = [x[0] for x in self.raw.description]
        return [dict(zip(names, row)) for row in self.raw.fetchall()]

    def fetchone(self):
        row = self.raw.fetchone()
        return None if row is None else dict(zip([x[0] for x in self.raw.description], row))


class Connection:
    def __init__(self, role):
        assert role in {"w10_web_customer", "w10_web_staff", "w10_web_manager"}
        self.raw = connect(False)
        self.raw.execute(f"EXECUTE AS USER='{role}'")

    def cursor(self, as_dict=False):
        return Cursor(self, as_dict)

    def commit(self): self.raw.commit()
    def rollback(self): self.raw.rollback()
    def close(self): self.raw.close()


def run_web_checks(c):
    with connect() as db:
        if not scalar(db,"SELECT COUNT(*) FROM sys.database_principals WHERE name='w10_web_customer'"):
            sql=(ROOT/'sql/week7/permissions.sql').read_text(encoding='utf-8')
            for role in ('customer','staff','manager'):
                user='w10_web_'+role
                sql=sql.replace('%'+role.upper()+'_LOGIN%',user)
                sql=sql.replace('FOR LOGIN ['+user+']','WITHOUT LOGIN')
            rows(db,sql)
        install_file(db,'sql/week10/permissions.sql')
    password=secrets.token_urlsafe(24)
    config={'session_secret':secrets.token_urlsafe(32),'db_name':DB,'db_host':'localhost','db_port':1433,
            'db_users':{r:{'user':'w10_web_'+r,'password':''} for r in ('customer','staff','manager')},
            'app_users':{r:{'role':r,'customer_id':'C00' if r=='customer' else None,
                           'employee_id':{'staff':'P00','manager':'P01'}.get(r),
                           'password_hash':generate_password_hash(password)} for r in ('customer','staff','manager')}}
    original=pymssql.connect
    pymssql.connect=lambda **kw:Connection(kw['user'])
    try:
        from app.web import create_app
        app=create_app(config)
        app.logger.disabled=True
        client=app.test_client()
        token=''
        def call(method,path,payload=None):
            response=client.open(path,method=method,json=payload,headers={'X-CSRF-Token':token})
            return response.status_code,response.get_json()
        def login(role):
            nonlocal token
            token=call('GET','/api/session')[1]['data']['csrf']
            status,result=call('POST','/api/login',{'username':role,'password':password})
            c.check('web_login_'+role,status==200)
            token=result['data']['csrf']
        login('customer')
        c.check('web_customer_report_denied',call('GET','/api/sales-summary?start=2026-09-16&end=2026-09-16')[0]==403)
        recipient={'recipient_name':'模拟收件人','recipient_phone':'10000000000','shipping_address':'模拟地址'}
        status,result=call('POST','/api/orders',{**recipient,'items':[{'product_id':'S01','quantity':2}]})
        c.check('web_sql_discount_create',status==201 and Decimal(result.get('data',{}).get('total_amount','0'))==Decimal('8.36'),result.get('data',result.get('error')), '8.36 / discount 0.44')
        order=result['data']['order_id']
        detail=call('GET','/api/orders/'+order)[1]['data']
        item=detail['items'][0]['SalesItemID']
        status,result=call('PATCH',f'/api/orders/{order}/items/{item}',{'quantity':3})
        c.check('web_sql_discount_quantity_change',status==200 and Decimal(result.get('data',{}).get('total_amount','0'))==Decimal('12.54'))
        status,result=call('POST',f'/api/orders/{order}/items',{'product_id':'S00','quantity':1})
        c.check('web_sql_discount_add_item',status==201 and Decimal(result.get('data',{}).get('total_amount','0'))==Decimal('14.44'))
        added=result['data']['item_id']
        status,result=call('DELETE',f'/api/orders/{order}/items/{added}')
        c.check('web_sql_discount_remove_item',status==200 and Decimal(result.get('data',{}).get('total_amount','0'))==Decimal('12.54'))
        c.check('web_pay_discounted_amount',call('POST',f'/api/orders/{order}/pay')[0]==200)
        login('staff')
        c.check('web_replenishment_sql',call('GET','/api/replenishment/S01?target=300')[0]==200)
        c.check('web_replenishment_unknown',call('GET','/api/replenishment/missing')[0]==400)
        c.check('web_sales_tvf',call('GET','/api/sales-summary?start=2026-09-16&end=2026-09-16')[0]==200)
        c.check('web_date_range_error',call('GET','/api/sales-summary?start=2026-10-01&end=2026-09-16')[0]==400)
        c.check('web_adjust_procedure',call('POST','/api/inventory/adjust',{'batch_id':'B00','delta':1,'reason':'模拟 Web 盘点'})[0]==200)
        c.check('web_adjust_restore',call('POST','/api/inventory/adjust',{'batch_id':'B00','delta':-1,'reason':'模拟 Web 盘点恢复'})[0]==200)
        c.check('web_adjust_sql_shortage',call('POST','/api/inventory/adjust',{'batch_id':'B00','delta':-10000,'reason':'模拟拒绝'})[0]==409)
        c.check('web_complete_procedure',call('POST',f'/api/orders/{order}/fulfill')[0]==200)
        c.check('web_repeat_complete_denied',call('POST',f'/api/orders/{order}/fulfill')[0]==409)
        with connect() as db:
            c.check('web_discount_snapshot_persisted',scalar(db,'SELECT DiscountAmount FROM dbo.SalesOrder WHERE SalesOrderID=?',(order,))==Decimal('.66'))
            c.check('web_complete_once_only',scalar(db,'SELECT COUNT(*) FROM dbo.InventoryMovement WHERE SalesItemID=?',(item,))==1 and scalar(db,'SELECT PointsDelta FROM dbo.PointsMovement WHERE SalesOrderID=?',(order,))==12)
        connection=Connection('w10_web_staff')
        try:
            try:
                connection.raw.execute("UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+1 WHERE BatchID='B00'")
            except pyodbc.Error as exc:
                c.check('web_staff_direct_stock_update_denied','229' in str(exc) or '230' in str(exc))
            else:
                raise AssertionError('staff should only adjust stock through procedure')
        finally:
            connection.rollback(); connection.close()
    finally:
        pymssql.connect=original
