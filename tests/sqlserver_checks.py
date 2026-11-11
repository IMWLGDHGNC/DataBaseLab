"""Shared LocalDB test utilities. Only dedicated Week10 sample databases allowed."""
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
from datetime import date, datetime
from decimal import Decimal

import pyodbc

ROOT = Path(__file__).resolve().parents[1]
DB = os.environ.get("LAB_TEST_DATABASE", "")
if not re.fullmatch(r"DataBaseLab_Week6_Week10[0-9]+", DB):
    raise RuntimeError("Set LAB_TEST_DATABASE to the dedicated Run-Week10.ps1 sample database")
DRIVER = next(d for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server") if d in pyodbc.drivers())
info = subprocess.run([str(Path(os.environ['ProgramFiles']) / 'Microsoft SQL Server/160/Tools/Binn/SqlLocalDB.exe'),
                       'info', 'DataBaseLab'], capture_output=True, check=True).stdout
# The legacy Windows SQL Server ODBC driver cannot resolve (localdb) itself.
# Resolve the current instance pipe privately; never write it into public logs.
SERVER = re.search(rb'np:\\\\[^\r\n]+', info).group().decode('ascii').strip()


def connect(autocommit=True):
    return pyodbc.connect(f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={DB};Trusted_Connection=yes", autocommit=autocommit)


def rows(conn, sql, params=()):
    cursor = conn.cursor().execute(sql, params)
    result = []
    while True:
        if cursor.description:
            names = [c[0] for c in cursor.description]
            result.append([dict(zip(names, row)) for row in cursor.fetchall()])
        if not cursor.nextset():
            break
    cursor.close()
    return result


def scalar(conn, sql, params=()):
    return next(iter(rows(conn, sql, params)[0][0].values()))


def snapshot(conn):
    tables = rows(conn, "SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('dbo') ORDER BY name")[0]
    result = {}
    for table in tables:
        name = table["name"]
        data = rows(conn, f"SELECT * FROM dbo.[{name}]")
        encoded = sorted(json.dumps(r, ensure_ascii=False, default=str, sort_keys=True) for r in data[0])
        result[name] = hashlib.sha256("\n".join(encoded).encode()).hexdigest()
    return result


class Checks:
    def __init__(self, week):
        self.week, self.results = week, []

    def check(self, name, condition, actual=None, expected=None):
        if not condition:
            raise AssertionError(f"{name}: actual={actual!r}, expected={expected!r}")
        self.results.append({"case": name, "expected": expected, "actual": actual, "result": "PASS"})
        print("PASS", name)

    def error(self, name, sql, params=(), expected=51801, setup=None):
        with connect() as conn:
            before = snapshot(conn)
            conn.execute("BEGIN TRANSACTION")
            if setup:
                setup(conn)
            try:
                rows(conn, sql, params)
            except pyodbc.Error as exc:
                numbers = [int(n) for n in re.findall(r"\((\d+)\)", str(exc))]
                self.check(name, expected in numbers, expected, expected)
            else:
                raise AssertionError(name + ": SQL unexpectedly accepted invalid data")
            finally:
                conn.execute("IF @@TRANCOUNT>0 ROLLBACK")
            self.check(name + "_no_partial_data", before == snapshot(conn), "all dbo table digests unchanged", "all dbo table digests unchanged")

    def finish(self):
        output = ROOT / "output" / f"week{self.week}"
        output.mkdir(parents=True, exist_ok=True)
        (output / "checks.json").write_text(json.dumps(self.results, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
        print(f"WEEK{self.week}_PASS {len(self.results)}")


def fixture(conn, customer="C00", paid=True, quantity=2):
    """Create a fictional, correctly reserved S01 order in the caller's transaction."""
    suffix = secrets.token_hex(4).upper()
    order, item, reservation = "SO" + suffix, "SI" + suffix, "RS" + suffix
    conn.execute("""INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,OrderStatus,
        RecipientName,RecipientPhone,ShippingAddress,TotalAmount)
        VALUES(?,?,SYSDATETIME(),N'待支付',N'模拟收件人','10000000000',N'模拟地址',?)""", order, customer, Decimal("4.40") * quantity)
    conn.execute("""INSERT dbo.SalesOrderItem(SalesItemID,SalesOrderID,ProductID,Quantity,DealUnitPrice,ListUnitPrice)
        VALUES(?,?,'S01',?,4.40,4.40)""", item, order, quantity)
    conn.execute("""INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservationStatus,ReservedAt)
        VALUES(?,?,'B00',?,N'有效',SYSDATETIME())""", reservation, item, quantity)
    rows(conn, "EXEC dbo.sp_PriceOrder ?,1", (order,))
    if paid:
        amount = scalar(conn, "SELECT TotalAmount FROM dbo.SalesOrder WHERE SalesOrderID=?", (order,))
        conn.execute("""INSERT dbo.PaymentRecord(PaymentID,SalesOrderID,MockTransactionNo,Amount,PaymentStatus,ResultAt)
            VALUES(?,?,?,?,N'成功',SYSDATETIME())""", "PY" + suffix, order, "SIM-W10-" + suffix, amount)
        conn.execute("UPDATE dbo.SalesOrder SET OrderStatus=N'待出库' WHERE SalesOrderID=?", order)
    return order, item, reservation


def install_file(conn, path):
    for batch in re.split(r"(?im)^\s*GO\s*$", (ROOT / path).read_text(encoding="utf-8")):
        if batch.strip():
            rows(conn, batch)
