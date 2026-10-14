"""Regression checks for the complete Week 7-9 workflow and review fixes."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from datetime import timedelta
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import secrets
from threading import Event, current_thread
from unittest.mock import patch

import pymssql
from app.db import Database, Repository
from app.web import create_app


def run_review_checks(app, config, passwords, check):
    # Additional simulated customers exist only in this test process.
    for name, customer_id in (("other", "C01"), ("nonmember", "C02")):
        config["app_users"][name + "_test"] = {
            "role": "customer", "customer_id": customer_id,
            "password_hash": config["app_users"]["customer_demo"]["password_hash"]}
    actors = {}
    responses, flow = [], []
    db = Database(config)

    def actor(role):
        client = app.test_client()
        csrf = client.get("/api/session").get_json()["data"]["csrf"]
        name = role + "_test" if role in ("other", "nonmember") else role + "_demo"
        password = passwords["customer_demo" if role in ("other", "nonmember") else name]
        result = client.post("/api/login", json={"username": name, "password": password},
                             headers={"X-CSRF-Token": csrf})
        assert result.status_code == 200
        return client, result.get_json()["data"]["csrf"]

    def request(role, method, path, payload=None, fresh=False):
        if fresh or role not in actors:
            client, csrf = actor(role)
            if not fresh:
                actors[role] = client, csrf
        else:
            client, csrf = actors[role]
        response = client.open(path, method=method, json=payload, headers={"X-CSRF-Token": csrf})
        result = response.get_json()
        return response.status_code, result

    def expect(name, role, method, path, payload=None, status=200, code=None):
        actual, result = request(role, method, path, payload)
        check(name, actual == status and (code is None or result.get("error", {}).get("code") == code))
        # Publish the envelope and friendly error, never credentials or CSRF.
        responses.append({"case": name, "role": role, "method": method, "status": actual,
                          "request_id": result["request_id"], "ok": result["ok"],
                          **({"error": result["error"]} if not result["ok"] else {})})
        return result.get("data")

    tables = ("Product", "PurchaseOrder", "PurchaseOrderItem", "InventoryBatch", "InventoryMovement",
              "SalesOrder", "SalesOrderItem", "InventoryReservation", "PaymentRecord", "Customer", "PointsMovement")

    def digest():
        with db.session("manager") as repo:
            return {table: hashlib.sha256("\n".join(sorted(json.dumps(row, default=str, sort_keys=True)
                    for row in repo.all("SELECT * FROM dbo." + table))).encode()).hexdigest() for table in tables}

    @contextmanager
    def fail_after(method):
        original = getattr(Repository, method)
        def wrapped(repo, *args, **kwargs):
            original(repo, *args, **kwargs)
            repo.run("THROW 59000, 'Injected isolated regression failure.', 1")
        with patch.object(Repository, method, wrapped):
            yield

    recipient = {"recipient_name": "模拟回归收件人", "recipient_phone": "10000000000", "shipping_address": "模拟回归地址"}
    product_id = "W9" + secrets.token_hex(4).upper()
    category = expect("review_categories", "manager", "GET", "/api/categories")[0]["CategoryID"]
    suppliers = expect("review_suppliers", "manager", "GET", "/api/suppliers")
    supplier = suppliers[0]["SupplierID"]
    data = {"product_id": product_id, "category_id": category, "name": "完整流程模拟商品", "brand": product_id,
            "specification": "单包", "unit": "包", "price": "2.50", "reorder_level": 0}
    expect("new_product", "manager", "POST", "/api/products", data, 201)
    purchase = expect("create_approved_purchase", "manager", "POST", "/api/purchases",
                      {"product_id": product_id, "supplier_id": supplier, "quantity": 20, "unit_cost": "1.00"}, 201)
    expect("customer_cannot_purchase", "customer", "POST", "/api/purchases", {}, 403, "FORBIDDEN")
    expect("staff_cannot_approve_purchase", "staff", "POST", "/api/purchases", {}, 403, "FORBIDDEN")
    with db.session("manager") as repo:
        today = repo.today()
    receipt = {"purchase_item_id": purchase["purchase_item_id"], "supplier_batch_no": "SIM-" + product_id,
               "production_date": (today-timedelta(days=1)).isoformat(), "expiry_date": (today+timedelta(days=365)).isoformat(),
               "reason": "模拟完整流程验收"}
    expect("customer_cannot_receive", "customer", "POST", "/api/inventory", receipt, 403, "FORBIDDEN")
    expect("expired_receipt_rejected", "staff", "POST", "/api/inventory", {**receipt, "expiry_date": today.isoformat()}, 400, "INVALID_INPUT")
    before = digest()
    with fail_after("receive_purchase"):
        expect("receipt_failure_after_writes", "staff", "POST", "/api/inventory", receipt, 500, "TRANSACTION_FAILED")
    check("receipt_rollback_all_affected_tables", digest() == before)
    received = expect("receive_new_product", "staff", "POST", "/api/inventory", receipt, 201)
    expect("duplicate_receipt_rejected", "staff", "POST", "/api/inventory", receipt, 409, "BUSINESS_CONFLICT")
    flow.extend([{"step": "manager_create_product", **data}, {"step": "manager_approve_purchase", **purchase},
                 {"step": "staff_receive", **received}])
    batch_id = received["batch_id"]

    def batch():
        return next(b for b in request("staff", "GET", "/api/inventory")[1]["data"] if b["BatchID"] == batch_id)
    check("new_product_can_be_sold", int(batch()["OnHandQty"]) == 20)
    order_payload = {**recipient, "items": [{"product_id": product_id, "quantity": 2}]}
    before = digest()
    with fail_after("insert_reservation"):
        expect("order_failure_after_reservation", "customer", "POST", "/api/orders", order_payload, 500, "TRANSACTION_FAILED")
    check("order_rollback_all_affected_tables", digest() == before)
    order = expect("new_product_order", "customer", "POST", "/api/orders", order_payload, 201)
    order_id = order["order_id"]
    detail = request("customer", "GET", "/api/orders/" + order_id)[1]["data"]
    item_id = detail["items"][0]["SalesItemID"]
    flow.append({"step": "customer_create_order", **order, "on_hand": batch()["OnHandQty"], "reserved": batch()["ReservedQty"]})
    check("ordering_reserves_without_shipping", int(batch()["OnHandQty"]) == 20 and int(batch()["ReservedQty"]) == 2)
    before = digest()
    for method, path, payload in (("GET", f"/api/orders/{order_id}", None), ("PATCH", f"/api/orders/{order_id}", recipient),
            ("POST", f"/api/orders/{order_id}/items", {"product_id": "S00", "quantity": 1}),
            ("PATCH", f"/api/orders/{order_id}/items/{item_id}", {"quantity": 3}),
            ("DELETE", f"/api/orders/{order_id}/items/{item_id}", None), ("DELETE", f"/api/orders/{order_id}", None),
            ("POST", f"/api/orders/{order_id}/pay", None)):
        expect("ownership_" + method + "_" + path.split("/")[-1], "other", method, path, payload, 404, "NOT_FOUND")
    check("ownership_denials_preserve_data", digest() == before)
    expect("manager_order_creation_matches_matrix", "manager", "POST", "/api/orders", order_payload, 403, "FORBIDDEN")
    for quantity in (2147483648, float("inf"), float("nan")):
        expect("invalid_quantity_" + str(quantity), "customer", "PATCH", f"/api/orders/{order_id}/items/{item_id}",
               {"quantity": quantity}, 400, "INVALID_INPUT")
    expect("integer_reorder_limit", "manager", "PATCH", "/api/products/" + product_id,
           {"price": "2.50", "status": "在售", "reorder_level": 2147483648}, 400, "INVALID_INPUT")
    expect("nonfinite_inventory_adjustment", "staff", "POST", "/api/inventory/adjust",
           {"batch_id": batch_id, "delta": float("inf"), "reason": "模拟错误输入"}, 400, "INVALID_INPUT")
    expect("change_quantity", "customer", "PATCH", f"/api/orders/{order_id}/items/{item_id}", {"quantity": 3})
    flow.append({"step": "customer_change_quantity", "order_id": order_id, "quantity": 3,
                 "total_amount": "7.50", "on_hand": batch()["OnHandQty"], "reserved": batch()["ReservedQty"]})
    pay = expect("pay_new_product_order", "customer", "POST", f"/api/orders/{order_id}/pay")
    flow.append({"step": "customer_pay", **pay, "on_hand": batch()["OnHandQty"], "reserved": batch()["ReservedQty"]})
    expect("paid_item_change_denied", "customer", "PATCH", f"/api/orders/{order_id}/items/{item_id}", {"quantity": 1}, 409, "BUSINESS_CONFLICT")
    before = digest()
    with fail_after("award_points"):
        expect("fulfillment_failure_after_points", "staff", "POST", f"/api/orders/{order_id}/fulfill", None, 500, "TRANSACTION_FAILED")
    check("fulfillment_rollback_all_affected_tables", digest() == before)
    with db.session("staff") as repo:
        points_before = int(repo.customer("C00")["PointsBalance"])
    fulfilled = expect("fulfill_new_product_order", "staff", "POST", f"/api/orders/{order_id}/fulfill")
    with db.session("staff") as repo:
        points_after = int(repo.customer("C00")["PointsBalance"])
    check("new_product_full_flow_accounting", int(batch()["OnHandQty"]) == 17 and int(batch()["ReservedQty"]) == 0 and points_after-points_before == 7)
    flow.append({"step": "staff_fulfill", **fulfilled, "on_hand": batch()["OnHandQty"], "reserved": batch()["ReservedQty"], "points_added": points_after-points_before})
    expect("expired_existing_batch_denied", "staff", "POST", "/api/orders/ST02/fulfill", None, 409, "BUSINESS_CONFLICT")
    before = digest()
    with fail_after("change_stock"):
        expect("stock_failure_after_movement", "staff", "POST", "/api/inventory/adjust",
               {"batch_id": batch_id, "delta": 1, "reason": "模拟回滚检查"}, 500, "TRANSACTION_FAILED")
    check("stock_rollback_all_affected_tables", digest() == before)

    # The create path already checked this boundary; both edit paths must do so.
    expect("high_price_allowed", "manager", "PATCH", "/api/products/" + product_id,
           {"price": "50000000.00", "status": "在售", "reorder_level": 0})
    expensive = expect("bounded_initial_order", "customer", "POST", "/api/orders",
                       {**recipient, "items": [{"product_id": product_id, "quantity": 1}]}, 201)
    eid = expensive["order_id"]
    ei = request("customer", "GET", "/api/orders/" + eid)[1]["data"]["items"][0]["SalesItemID"]
    before = digest()
    expect("edited_total_overflow", "customer", "PATCH", f"/api/orders/{eid}/items/{ei}", {"quantity": 2}, 400, "INVALID_INPUT")
    check("edited_total_rollback", digest() == before)
    with db.session("manager") as repo:
        sample_product = repo.product("S00")
    expect("second_high_price_product", "manager", "PATCH", "/api/products/S00",
           {"price": "50000000.00", "status": "在售", "reorder_level": 0})
    before = digest()
    expect("added_total_overflow", "customer", "POST", f"/api/orders/{eid}/items", {"product_id": "S00", "quantity": 1}, 400, "INVALID_INPUT")
    check("added_total_rollback", digest() == before)
    expect("cancel_boundary_order", "customer", "DELETE", "/api/orders/" + eid)
    expect("restore_new_product_price", "manager", "PATCH", "/api/products/" + product_id,
           {"price": "2.50", "status": "在售", "reorder_level": 0})
    expect("restore_sample_price", "manager", "PATCH", "/api/products/S00",
           {"price": str(sample_product["CurrentPrice"]), "status": sample_product["SaleStatus"], "reorder_level": sample_product["ReorderLevel"]})

    # Force the previously failing create-versus-fulfill overlap. With the common
    # write lock the fulfilment may wait at entry; without it it reaches stock.
    pending = expect("concurrency_order", "customer", "POST", "/api/orders", order_payload, 201)["order_id"]
    expect("concurrency_order_pay", "customer", "POST", f"/api/orders/{pending}/pay")
    held, release, stock_locked = Event(), Event(), Event()
    original_customer, original_reservations = Repository.customer, Repository.active_reservations_for_order
    def scheduled_customer(repo, customer_id, lock=False):
        result = original_customer(repo, customer_id, lock)
        if current_thread().name.startswith("CreateRegression") and lock:
            held.set()
            if not release.wait(10):
                raise AssertionError("Concurrency scheduling deadline")
        return result
    def scheduled_reservations(repo, oid):
        result = original_reservations(repo, oid)
        stock_locked.set()
        return result
    with patch.object(Repository, "customer", scheduled_customer), patch.object(Repository, "active_reservations_for_order", scheduled_reservations):
        with ThreadPoolExecutor(max_workers=1, thread_name_prefix="CreateRegression") as creates, ThreadPoolExecutor(max_workers=1, thread_name_prefix="FulfillRegression") as ships:
            created = creates.submit(request, "customer", "POST", "/api/orders", order_payload, True)
            assert held.wait(10)
            shipped = ships.submit(request, "staff", "POST", f"/api/orders/{pending}/fulfill", None, True)
            stock_locked.wait(1)
            release.set()
            create_status, create_result = created.result(timeout=25)
            ship_status, _ = shipped.result(timeout=25)
    check("create_fulfill_overlap_no_deadlock", create_status == 201 and ship_status == 200)
    expect("concurrency_cleanup", "customer", "DELETE", "/api/orders/" + create_result["data"]["order_id"])
    # Two separate customer identities, and two simultaneous payments.
    def compete(role):
        return request(role, "POST", "/api/orders", {**recipient, "items": [{"product_id": product_id, "quantity": 10}]}, True)
    with ThreadPoolExecutor(max_workers=2) as pool:
        competitions = list(pool.map(compete, ("customer", "other")))
    check("different_customer_stock_limit", sorted(status for status, _ in competitions) == [201, 409])
    for role, (status, result) in zip(("customer", "other"), competitions):
        if status == 201:
            expect("different_customer_cleanup", role, "DELETE", "/api/orders/" + result["data"]["order_id"])
    nonmember = expect("nonmember_order", "nonmember", "POST", "/api/orders", order_payload, 201)["order_id"]
    with ThreadPoolExecutor(max_workers=2) as pool:
        payments = list(pool.map(lambda _: request("nonmember", "POST", f"/api/orders/{nonmember}/pay", fresh=True)[0], range(2)))
    check("simultaneous_payment_unique_success", sorted(payments) == [200, 409])
    with db.session("staff") as repo:
        balance_before = int(repo.customer("C02")["PointsBalance"])
    expect("nonmember_fulfill", "staff", "POST", f"/api/orders/{nonmember}/fulfill")
    with db.session("staff") as repo:
        check("nonmember_no_points", int(repo.customer("C02")["PointsBalance"]) == balance_before and repo.points_for_order(nonmember) is None)
    current_stock = int(batch()["OnHandQty"])
    expect("zero_inventory_with_audit", "staff", "POST", "/api/inventory/adjust",
           {"batch_id": batch_id, "delta": -current_stock, "reason": "模拟库存退出，保留历史"})
    check("zero_inventory_keeps_batch_and_history", int(batch()["OnHandQty"]) == 0)
    offline = {**config, "db_port": 1}
    response = create_app(offline).test_client().get("/api/products")
    result = response.get_json()
    check("connection_failure_classified_and_recorded", response.status_code == 503 and result["error"]["code"] == "DATABASE_UNAVAILABLE")
    responses.append({"case": "database_connection_failure", "role": "anonymous", "method": "GET", "status": response.status_code,
                      "ok": result["ok"], "request_id": result["request_id"], "error": result["error"]})

    evidence = Path(__file__).resolve().parents[1] / "output/week7/review-evidence.json"
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(json.dumps({"environment": "isolated sample database; simulated users",
                                   "flow": flow, "responses": responses, "rollback_tables": list(tables)},
                                  ensure_ascii=False, indent=2, default=str) + "\n", encoding="utf-8")
