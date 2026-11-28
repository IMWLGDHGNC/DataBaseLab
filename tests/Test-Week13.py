"""Replay Week13 SQL with two independent LocalDB connections and a DMV observer."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
import json
import re
from time import monotonic, sleep

from sqlserver_checks import Checks, ROOT, connect, rows

SQL = ROOT / "sql" / "week13"
checks = Checks(13)
evidence = []
sessions = {}
SESSION_SQL = (SQL / "session.sql").read_text(encoding="utf-8")
OBSERVE_SQL = (SQL / "observe.sql").read_text(encoding="utf-8")
STEPS = re.compile(r"(?m)^-- ([AB]\d+):[^\n]*\n")


def read_script(name, round_code="C"):
    text = (SQL / f"{name}.sql").read_text(encoding="utf-8")
    return text.replace("DECLARE @Round char(1)='C';", f"DECLARE @Round char(1)='{round_code}';")


def run_file(conn, name, round_code="C"):
    batches = re.split(r"(?im)^GO\s*$", read_script(name, round_code))
    return [result for batch in batches if batch.strip() for result in rows(conn, batch)]


def record(step, data):
    evidence[-1]["steps"].append({"step": step, "result": data})
    return data


def step(name, label, concurrent=False, round_code="C"):
    session = label[0]
    filename = f"{name}_{session}"
    parts = STEPS.split(read_script(filename, round_code))
    scripts = dict(zip(parts[1::2], parts[2::2]))
    record(f"{label} start", {"session": session, "script": f"{filename}.sql"})
    if concurrent:
        return pool.submit(rows, sessions[session], scripts[label])
    return record(f"{label} end", rows(sessions[session], scripts[label]))


def finish(label, pending):
    return record(f"{label} end", pending.result(timeout=35))


def require(name, condition, actual, expected):
    checks.check(name, condition, actual, expected)


def observe(waiting, blocker, product=None, pending=None):
    waiter, holder = spids[waiting], spids[blocker]
    sql = OBSERVE_SQL.replace("@A int=0,@B int=0", f"@A int={spids['A']},@B int={spids['B']}")
    deadline = monotonic() + 7
    while monotonic() < deadline:
        isolation, requests, locks = rows(observer, sql)
        edge = next((r for r in requests if r["SessionID"] == waiter and r["Blocker"] == holder), None)
        if edge:
            # Keep the two sessions' lock resource and mode. Raw host and login metadata are unused.
            key = key_resources.get(product)
            resource_type = "KEY" if product else "APPLICATION"
            relevant = [r for r in locks if r["ResourceType"] == resource_type]
            for denied in relevant:
                if denied["SessionID"] != waiter or denied["Status"] not in {"WAIT", "CONVERT"}:
                    continue
                if product and (denied["TableName"] != "Stock" or denied["Resource"] != key):
                    continue
                if any(r["SessionID"] == holder and r["Status"] == "GRANT"
                       and r["Resource"] == denied["Resource"] and r["TableName"] == denied["TableName"]
                       for r in relevant):
                    data = {"waiter": waiting, "blocker": blocker, "product": product,
                            "sessions": isolation, "request": edge, "locks": relevant}
                    return record("DMV observation", data)
        if pending and pending.done():
            pending.result()
            raise AssertionError(f"{waiting} completed without the expected wait on {blocker}: {requests}, {locks}")
        sleep(0.05)
    raise AssertionError(f"Missing wait {waiting} -> {blocker} on {product}: {requests}, {locks}")


def state():
    stock, docs = run_file(observer, "state")
    return {row["ProductID"]: row["Qty"] for row in stock} | {row["DocumentID"]: row["Status"] for row in docs}


def final_state(expected):
    actual = record("final state", state())
    require(evidence[-1]["case"], actual == expected, actual, expected)


def start(case, reset=True):
    evidence.append({"case": case, "steps": []})
    if reset:
        run_file(observer, "setup")
    for label, conn in sessions.items():
        result = rows(conn, SESSION_SQL)[0][0]
        assert result["TranCount"] == 0, (case, label, result)
        spids[label] = result["SessionID"]
        record(f"{label} session", result)
    assert spids["A"] != spids["B"]
    if reset:
        key_resources.update((r["ProductID"], r["Resource"].strip()) for r in rows(
            observer, "SELECT ProductID, %%lockres%% AS Resource FROM week13_lab.Stock")[0])
        record("initial state", state())
        record("stock key mapping", dict(key_resources))


def clean():
    for label, conn in sessions.items():
        tx = rows(conn, "SELECT @@TRANCOUNT AS TranCount,XACT_STATE() AS XactState")[0][0]
        assert tx == {"TranCount": 0, "XactState": 0}, (label, tx)
        cleaned = run_file(conn, "cleanup")[0][0]
        assert cleaned["TranCount"] == cleaned["XactState"] == 0, (label, cleaned)
        record(f"{label} cleanup", {"SessionID": spids[label], **cleaned})


def qty(result, isolation):
    reading = result[0][0]
    assert reading["IsolationLevel"] == isolation, reading
    return reading["Qty"]


spids, key_resources = {}, {}
with closing(connect()) as observer, closing(connect()) as a, closing(connect()) as b, ThreadPoolExecutor(1) as pool:
    sessions = {"A": a, "B": b}
    if rows(observer, "SELECT ProductID FROM dbo.Product WHERE ProductID IN ('W13P','W13PC','W13PR')")[0]:
        raise SystemExit("Use a sample database without existing Week13 business fixtures.")

    for a_step, expected_qty, order_status in [("A2", 13, "Completed"), ("A3", 15, "Pending")]:
        start("write_wait_" + order_status.lower())
        step("lock_wait", "A1")
        pending = step("lock_wait", "B1", concurrent=True)
        observe("B", "A", "P", pending)
        step("lock_wait", a_step)
        finish("B1", pending)
        step("lock_wait", "B2")
        final_state({"P": expected_qty, "Q": 8, "ORDER": order_status, "RECEIPT": "Received"})
        clean()

    start("dirty_read")
    step("dirty_read", "A1")
    read = qty(step("dirty_read", "B1"), 1)
    step("dirty_read", "A2")
    after = state()
    require("read_uncommitted_then_rollback", read == 15 and after["P"] == 10 and after["RECEIPT"] == "Approved",
            {"read": read, "after_rollback": after}, "15 before rollback, 10 and Approved after rollback")
    clean()

    for read_step in ("B2", "B3"):
        start("read_committed" if read_step == "B2" else "read_committed_lock_hint")
        rcsi = evidence[-1]["steps"][1]["result"]["RCSI"]
        step("dirty_read", "A1")
        if read_step == "B3" or not rcsi:
            pending = step("dirty_read", read_step, concurrent=True)
            observe("B", "A", "P", pending)
            step("dirty_read", "A2")
            read = qty(finish(read_step, pending), 2)
        else:
            read = qty(step("dirty_read", read_step), 2)
            step("dirty_read", "A2")
        require(evidence[-1]["case"], read == 10, read, 10)
        clean()

    for mode, first, second, expected_qty in [
        ("read_committed_nonrepeatable", "A1", "A2", 15),
        ("repeatable_read", "A3", "A4", 10),
    ]:
        start(mode)
        initial = qty(step("repeatable_read", first), 3 if first == "A3" else 2)
        if first == "A3":
            pending = step("repeatable_read", "B1", concurrent=True)
            observe("B", "A", "P", pending)
            later = qty(step("repeatable_read", second), 3)
            finish("B1", pending)
        else:
            step("repeatable_read", "B1")
            later = qty(step("repeatable_read", second), 2)
        require(mode, (initial, later, state()["P"]) == (10, expected_qty, 15),
                [initial, later, state()["P"]], [10, expected_qty, 15])
        clean()

    start("opposite_order_deadlock")
    step("deadlock", "A1")
    step("deadlock", "B1")
    pending = step("deadlock", "A2", concurrent=True)
    info = observe("A", "B", "Q", pending)
    assert any(r["SessionID"] == spids["A"] and r["Mode"] == "X" and r["Status"] == "GRANT"
               and r["Resource"] == key_resources["P"] for r in info["locks"]), info
    victim = step("deadlock", "B2")[0][0]
    require("deadlock_victim", victim["ErrorNumber"] == 1205 and victim["TranCount"] == victim["XactState"] == 0,
            victim, "1205; no open transaction after cleanup")
    finish("A2", pending)
    step("deadlock", "A3")
    final_state({"P": 8, "Q": 6, "ORDER": "Completed", "RECEIPT": "Approved"})
    clean()

    start("ordered_keys")
    step("ordered", "A1")
    pending = step("ordered", "B1", concurrent=True)
    info = observe("B", "A", "P", pending)
    assert not any(r["SessionID"] == spids["B"] and r["Status"] == "GRANT"
                   and r["Resource"] == key_resources["Q"] for r in info["locks"]), info
    step("ordered", "A2")
    finish("B1", pending)
    step("ordered", "B2")
    final_state({"P": 13, "Q": 11, "ORDER": "Completed", "RECEIPT": "Received"})
    clean()

    run_file(observer, "business_wait_setup")
    for code, release, opening_batch_qty, status in [
        ("C", "A2", 8, "已完成"), ("R", "A3", 10, "待出库"),
    ]:
        start("business_receipt_after_" + ("commit" if code == "C" else "rollback"), reset=False)
        record("initial business state", run_file(observer, "business_wait_state", code))
        step("business_wait", "A1", round_code=code)
        pending = step("business_wait", "B1", concurrent=True, round_code=code)
        observe("B", "A", pending=pending)
        step("business_wait", release)
        finish("B1", pending)
        actual = record("final business state", run_file(observer, "business_wait_state", code))
        expected = [
            [{"BatchID": "W13WB" + code, "OnHandQty": opening_batch_qty},
             {"BatchID": "W13WRC" + code, "OnHandQty": 5}],
            [{"SaleStatus": status, "ReceiptStatus": "已收货"}],
            ([{"BatchID": "W13WB" + code, "QuantityDelta": -2, "MovementType": "销售出库"}]
             if code == "C" else [])
            + [{"BatchID": "W13WRC" + code, "QuantityDelta": 5, "MovementType": "采购入库"}],
        ]
        require(evidence[-1]["case"], actual == expected, actual, expected)
        clean()

    start("order_race", reset=False)
    run_file(observer, "business_setup")
    record("initial business state", run_file(observer, "business_state"))
    step("business_race", "A1")
    pending = step("business_race", "B1", concurrent=True)
    observe("B", "A", pending=pending)
    step("business_race", "A2")
    rejected = finish("B1", pending)[-1][0]
    require("second_order_rejected", rejected["ErrorNumber"] == 51804
            and "overcommitted" in rejected["ErrorMessage"]
            and rejected["TranCount"] == rejected["XactState"] == 0, rejected,
            "51804 for overcommitted batch; no open transaction")
    business_state = record("final business state", run_file(observer, "business_state"))
    stock, orders, reservations, movements, audit, points = business_state
    require("one_order_completed", stock == [{"BatchID": "W13BP", "OnHandQty": 4}]
            and orders[0]["OrderStatus"] == "已完成" and orders[0]["CompletedAt"] is not None
            and orders[1]["OrderStatus"] == "待出库" and orders[1]["CompletedAt"] is None
            and reservations == [{"ReservationID": "W13RA", "ReservedQty": 6, "ReservationStatus": "已转出库"}]
            and movements == [{"SalesItemID": "W13IA", "QuantityDelta": -6}]
            and audit == [{"BeforeQty": 10, "AfterQty": 4, "QuantityDelta": -6}]
            and points == [{"SalesOrderID": "W13OA", "PointsDelta": 30}], business_state,
            "P=4, only A completed with one reservation, shipment, audit and points entry")
    clean()

checks.finish()
(ROOT / "output" / "week13" / "sessions.json").write_text(
    json.dumps(evidence, ensure_ascii=False, indent=2, default=str) + "\n", encoding="utf-8")
