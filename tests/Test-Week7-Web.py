"""HTTP-to-SQL Server integration checks; run only on a dedicated sample database."""

import json
import os
from pathlib import Path
import secrets
import sys
from concurrent.futures import ThreadPoolExecutor

# Direct script execution puts tests/ on sys.path, so include the repository.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.db import Database
from app.web import create_app


config_path = os.environ.get("APP_CONFIG_FILE")
if not config_path:
    raise SystemExit("APP_CONFIG_FILE is required")
config = json.loads(Path(config_path).read_text(encoding="utf-8"))
if not config["db_name"].startswith("DataBaseLab_Week6_"):
    raise SystemExit("Integration tests require a dedicated Week6 sample database")
credential_path = Path(config_path).with_name("demo-credentials.txt")
passwords = {}
for line in credential_path.read_text(encoding="utf-8").splitlines():
    if ": " in line:
        name, password = line.split(": ", 1)
        passwords[name] = password

app = create_app(config)
app.testing = True
client = app.test_client()
checks = []
csrf = ""


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    checks.append(name)
    print("PASS", name)


def call(method, path, payload=None, token=True):
    headers = {"X-CSRF-Token": csrf} if token and method != "GET" else {}
    response = client.open(path, method=method, json=payload, headers=headers)
    return response.status_code, response.get_json()


def login(role):
    global csrf
    _, info = call("GET", "/api/session")
    csrf = info["data"]["csrf"]
    name = role + "_demo"
    status, result = call("POST", "/api/login",
                          {"username": name, "password": passwords[name]})
    check(role + "_login", status == 200 and result["data"]["user"]["role"] == role)
    csrf = result["data"]["csrf"]


def logout():
    global csrf
    status, _ = call("POST", "/api/logout")
    check("logout", status == 200)
    csrf = ""


status, html = client.get("/").status_code, client.get("/").get_data(as_text=True)
check("web_page", status == 200 and "零食网店" in html)
status, data = call("GET", "/api/session")
csrf = data["data"]["csrf"]
status, data = call("GET", "/api/products")
check("anonymous_products", status == 200 and any(p["ProductID"] == "S01" for p in data["data"]))
status, data = call("GET", "/api/inventory")
check("anonymous_inventory_denied", status == 401 and data["error"]["code"] == "UNAUTHENTICATED")

login("customer")
status, data = call("POST", "/api/orders", {}, token=False)
check("csrf_denied", status == 403 and data["error"]["code"] == "INVALID_CSRF")
status, data = call("GET", "/api/inventory")
check("customer_inventory_denied", status == 403 and data["error"]["code"] == "FORBIDDEN")
status, data = call("GET", "/api/orders/ST01")
check("other_customer_order_hidden", status == 404)

recipient = {"recipient_name": "课程测试收件人", "recipient_phone": "10000000000",
             "shipping_address": "模拟测试地址"}
status, data = call("GET", "/api/orders")
before_count = len(data["data"])
status, data = call("POST", "/api/orders", {**recipient,
    "items": [{"product_id": "S01", "quantity": 0}]})
check("invalid_quantity", status == 400 and data["error"]["code"] == "INVALID_INPUT")
status, data = call("POST", "/api/orders", {**recipient,
    "items": [{"product_id": "S01", "quantity": 100000}]})
check("insufficient_stock", status == 409 and data["error"]["code"] == "INSUFFICIENT_STOCK")
status, data = call("GET", "/api/orders")
check("failed_order_rolled_back", status == 200 and len(data["data"]) == before_count)

status, data = call("POST", "/api/orders", {**recipient,
    "items": [{"product_id": "S01", "quantity": 1}, {"product_id": "S00", "quantity": 1}]})
check("create_order", status == 201 and data["data"]["order_id"].startswith("SO"))
order_id = data["data"]["order_id"]
status, detail = call("GET", "/api/orders/" + order_id)
check("two_order_items", status == 200 and len(detail["data"]["items"]) == 2)
item_s01 = next(i["SalesItemID"] for i in detail["data"]["items"] if i["ProductID"] == "S01")
item_s00 = next(i["SalesItemID"] for i in detail["data"]["items"] if i["ProductID"] == "S00")
status, data = call("PATCH", f"/api/orders/{order_id}/items/{item_s01}", {"quantity": 2})
check("change_item_quantity", status == 200)
status, data = call("DELETE", f"/api/orders/{order_id}/items/{item_s00}")
check("delete_draft_item", status == 200)
status, data = call("POST", f"/api/orders/{order_id}/items",
                    {"product_id": "S00", "quantity": 1})
check("add_draft_item", status == 201)
status, data = call("PATCH", f"/api/orders/{order_id}",
                    {**recipient, "recipient_name": "课程测试收件人甲"})
check("change_recipient", status == 200)
status, data = call("POST", f"/api/orders/{order_id}/pay")
check("pay_order", status == 200 and data["data"]["status"] == "待出库")
status, data = call("POST", f"/api/orders/{order_id}/pay")
check("duplicate_payment_denied", status == 409)
status, data = call("DELETE", f"/api/orders/{order_id}")
check("paid_order_cannot_cancel", status == 409)

status, data = call("POST", "/api/orders", {**recipient,
    "items": [{"product_id": "S01", "quantity": 1}]})
cancel_id = data["data"]["order_id"]
status, data = call("DELETE", f"/api/orders/{cancel_id}")
check("cancel_releases_reservation", status == 200)
logout()

login("staff")
status, data = call("POST", "/api/products", {"product_id": "NOPE"})
check("staff_product_write_denied", status == 403)
status, data = call("GET", "/api/inventory")
before_stock = {b["BatchID"]: int(b["OnHandQty"]) for b in data["data"]}
status, data = call("POST", "/api/inventory/adjust",
                    {"batch_id": "B00", "delta": 1, "reason": "课程集成测试盘点"})
check("stock_adjustment", status == 200)
status, data = call("POST", f"/api/orders/{order_id}/fulfill")
check("fulfill_order", status == 200 and data["data"]["status"] == "已完成")
status, data = call("POST", f"/api/orders/{order_id}/fulfill")
check("duplicate_fulfillment_denied", status == 409)
status, data = call("GET", "/api/inventory")
after_stock = {b["BatchID"]: int(b["OnHandQty"]) for b in data["data"]}
check("stock_and_reservation_accounting", after_stock["B00"] == before_stock["B00"]-1
      and after_stock["B02"] == before_stock["B02"]-1)
with Database(config).session("staff") as repo:
    check("completed_order_persisted", repo.order(order_id)["OrderStatus"] == "已完成")
    check("member_points_awarded_once", repo.points_for_order(order_id) is not None)
logout()

login("manager")
status, data = call("GET", "/api/categories")
category = data["data"][0]["CategoryID"]
product_id = "W7" + secrets.token_hex(4).upper()
status, data = call("POST", "/api/products", {
    "product_id": product_id, "category_id": category, "name": "集成测试商品",
    "brand": "模拟测试品牌" + product_id, "specification": "单包", "unit": "包",
    "price": "2.50", "reorder_level": 0})
check("manager_create_product", status == 201)
status, data = call("PATCH", "/api/products/" + product_id,
                    {"price": "3.50", "status": "停售", "reorder_level": 2})
check("manager_update_product", status == 200)
status, data = call("DELETE", "/api/products/" + product_id)
check("manager_delete_unused_product", status == 200)
status, data = call("POST", "/api/products", {
    "product_id": "S01", "category_id": category, "name": "冲突商品",
    "brand": "冲突测试", "specification": "单包", "unit": "包",
    "price": "2.50", "reorder_level": 0})
check("duplicate_product_constraint_feedback", status == 409 and
      data["error"]["code"] == "CONSTRAINT_CONFLICT")
logout()

def competing_order():
    contender = app.test_client()
    token = contender.get("/api/session").get_json()["data"]["csrf"]
    login_result = contender.post("/api/login", json={
        "username": "customer_demo", "password": passwords["customer_demo"]},
        headers={"X-CSRF-Token": token})
    token = login_result.get_json()["data"]["csrf"]
    response = contender.post("/api/orders", json={**recipient,
        "items": [{"product_id": "S01", "quantity": 200}]},
        headers={"X-CSRF-Token": token})
    result = response.get_json()
    return response.status_code, contender, token, result


with ThreadPoolExecutor(max_workers=2) as pool:
    contenders = list(pool.map(lambda _: competing_order(), range(2)))
check("concurrent_stock_limit", sorted(row[0] for row in contenders) == [201, 409])
for status, contender, token, result in contenders:
    if status == 201:
        order_id_to_cancel = result["data"]["order_id"]
        cancelled = contender.delete("/api/orders/" + order_id_to_cancel,
                                     headers={"X-CSRF-Token": token})
        check("concurrent_order_cleanup", cancelled.status_code == 200)

offline = dict(config)
offline["db_port"] = 1
offline_app = create_app(offline)
offline_client = offline_app.test_client()
status = offline_client.get("/api/products").status_code
check("database_failure_friendly", status == 503)

from week7_review import run_review_checks
run_review_checks(app, config, passwords, check)
print(f"WEEK7_WEB_PASS {len(checks)}")
