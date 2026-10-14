"""Drive the three-role Web flow on an isolated server sample database.

Run on the server. Private credentials stay there; only checked screenshots and
the redacted status summary are candidates for publication.
"""

from datetime import timedelta
from decimal import Decimal
import json
import os
from pathlib import Path
import secrets
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import Select, WebDriverWait

from app.db import Database


config_path = Path(os.environ["APP_CONFIG_FILE"])
config = json.loads(config_path.read_text(encoding="utf-8"))
if not config["db_name"].startswith("DataBaseLab_Week6_"):
    raise SystemExit("Use only a dedicated Week6 sample database")
credentials = dict(line.split(": ", 1) for line in
                   config_path.with_name("demo-credentials.txt").read_text(encoding="utf-8").splitlines()
                   if ": " in line)
base = os.environ.get("APP_BASE_URL", "http://127.0.0.1:8767")
out = Path(os.environ.get("SCREENSHOT_DIR", "output/week7/server-flow"))
out.mkdir(parents=True, exist_ok=True)
db = Database(config)
options = Options()
options.add_argument("-headless")
if os.environ.get("FIREFOX_BINARY"):
    options.binary_location = os.environ["FIREFOX_BINARY"]
browser = webdriver.Firefox(options=options)
browser.set_window_size(1380, 1000)
wait = WebDriverWait(browser, 20)
checks = []
screenshots = []


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    checks.append(name)
    print("PASS", name)


def shot(name):
    height = browser.execute_script("return document.documentElement.scrollHeight")
    browser.set_window_size(1380, min(max(height + 80, 1000), 3600))
    browser.save_screenshot(str(out / name))
    browser.set_window_size(1380, 1000)
    screenshots.append(name)


def fill(selector, value):
    element = browser.find_element(By.CSS_SELECTOR, selector)
    element.clear()
    element.send_keys(str(value))


def login(role):
    fill("#login-form input[name=username]", role + "_demo")
    fill("#login-form input[name=password]", credentials[role + "_demo"])
    browser.find_element(By.CSS_SELECTOR, "#login-form button[type=submit]").click()
    wait.until(lambda b: role + "_demo" in b.find_element(By.ID, "account").text)
    check(role + "_browser_login", True)


def logout():
    browser.find_element(By.ID, "logout").click()
    wait.until(EC.visibility_of_element_located((By.ID, "login-form")))


def api(method, path):
    return browser.execute_async_script("""
      const method=arguments[0], path=arguments[1], done=arguments[2];
      (async()=>{
        const session=await (await fetch('/api/session')).json();
        const response=await fetch(path,{method,credentials:'same-origin',
          headers:{'X-CSRF-Token':session.data.csrf,'Content-Type':'application/json'},
          ...(method==='GET'?{}:{body:'{}'})});
        const body=await response.json();
        done({status:response.status,code:body.error?.code||null});
      })().catch(error=>done({status:0,code:String(error)}));
    """, method, path)


try:
    browser.get(base)
    wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "#products-body tr")))
    product_id = "W7UI" + secrets.token_hex(3).upper()
    product_name = "服务器复验零食" + product_id
    with db.session("manager") as repo:
        today = repo.today()
        points_before = int(repo.one("SELECT PointsBalance FROM dbo.Customer WHERE CustomerID=%s", ("C00",))["PointsBalance"])

    login("manager")
    check("manager_can_maintain_product", browser.find_element(By.ID, "product-form").is_displayed())
    check("manager_can_approve_purchase", browser.find_element(By.ID, "purchase-form").is_displayed())
    fill("#product-form input[name=product_id]", product_id)
    fill("#product-form input[name=name]", product_name)
    fill("#product-form input[name=brand]", "模拟课程品牌" + product_id)
    fill("#product-form input[name=specification]", "单包")
    fill("#product-form input[name=price]", "2.50")
    browser.find_element(By.CSS_SELECTOR, "#product-form button[type=submit]").click()
    wait.until(lambda b: product_id in b.find_element(By.ID, "products-body").text)
    shot("server-01-manager-product.png")

    Select(browser.find_element(By.ID, "purchase-product")).select_by_value(product_id)
    fill("#purchase-form input[name=quantity]", "10")
    fill("#purchase-form input[name=unit_cost]", "1.00")
    browser.find_element(By.CSS_SELECTOR, "#purchase-form button[type=submit]").click()
    wait.until(lambda b: product_name in b.find_element(By.ID, "receive-purchase").text)
    shot("server-02-approved-purchase.png")
    logout()

    login("staff")
    check("staff_can_receive", browser.find_element(By.ID, "receive-form").is_displayed())
    check("staff_cannot_maintain_product", not browser.find_element(By.ID, "product-form").is_displayed())
    Select(browser.find_element(By.ID, "receive-purchase")).select_by_visible_text(
        next(o.text for o in Select(browser.find_element(By.ID, "receive-purchase")).options
             if product_name in o.text))
    fill("#receive-form input[name=supplier_batch_no]", "SIM-" + product_id)
    fill("#receive-form input[name=production_date]", (today - timedelta(days=1)).isoformat())
    fill("#receive-form input[name=expiry_date]", (today + timedelta(days=365)).isoformat())
    fill("#receive-form input[name=reason]", "服务器复验入库")
    browser.find_element(By.CSS_SELECTOR, "#receive-form button[type=submit]").click()
    wait.until(lambda b: product_name in b.find_element(By.ID, "inventory-body").text)
    check("staff_product_write_denied", api("POST", "/api/products")["status"] == 403)
    shot("server-03-staff-received.png")
    logout()

    login("customer")
    check("customer_inventory_denied", api("GET", "/api/inventory")["status"] == 403)
    check("customer_cannot_view_inventory", not browser.find_element(By.ID, "inventory-panel").is_displayed())
    Select(browser.find_element(By.ID, "cart-product")).select_by_value(product_id)
    fill("#cart-qty", "9999")
    browser.find_element(By.ID, "cart-add").click()
    fill("#order-form input[name=recipient_name]", "模拟复验收件人")
    fill("#order-form input[name=recipient_phone]", "10000000000")
    fill("#order-form input[name=shipping_address]", "模拟复验地址")
    browser.find_element(By.CSS_SELECTOR, "#order-form button[type=submit]").click()
    wait.until(lambda b: b.find_element(By.ID, "notice").get_attribute("class").find("error") >= 0)
    check("stock_error_friendly", "库存" in browser.find_element(By.ID, "notice").text)
    shot("server-04-insufficient-stock.png")
    browser.find_element(By.CSS_SELECTOR, "#cart-list button[data-cart-remove]").click()
    before = {row["SalesOrderID"] for row in browser.execute_async_script("""
      fetch('/api/orders').then(r=>r.json()).then(x=>arguments[0](x.data));
    """)}
    fill("#cart-qty", "2")
    browser.find_element(By.ID, "cart-add").click()
    browser.find_element(By.CSS_SELECTOR, "#order-form button[type=submit]").click()
    def new_order(b):
        rows = b.execute_async_script("fetch('/api/orders').then(r=>r.json()).then(x=>arguments[0](x.data));")
        return next((row["SalesOrderID"] for row in rows if row["SalesOrderID"] not in before), None)
    order_id = wait.until(new_order)
    check("customer_created_order", order_id.startswith("SO"))
    wait.until(lambda b: order_id in b.find_element(By.ID, "orders-body").text)
    shot("server-05-customer-order.png")
    browser.find_element(By.CSS_SELECTOR, f'button[data-detail="{order_id}"]').click()
    wait.until(EC.visibility_of_element_located((By.ID, "detail-dialog")))
    browser.find_element(By.CSS_SELECTOR, "#detail-content button[data-item-edit]").click()
    wait.until(EC.visibility_of_element_located((By.ID, "confirm-dialog")))
    fill("#prompt-value", "3")
    browser.find_element(By.ID, "confirm-accept").click()
    wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, '#detail-content button[data-qty="3"]')))
    shot("server-06-customer-edited.png")
    browser.find_element(By.ID, "close-detail").click()
    browser.find_element(By.CSS_SELECTOR, f'button[data-pay="{order_id}"]').click()
    def order_row(b):
        button = b.find_element(By.CSS_SELECTOR, f'button[data-detail="{order_id}"]')
        return button.find_element(By.XPATH, "./ancestor::tr").text
    wait.until(lambda b: "待出库" in order_row(b))
    check("customer_paid", True)
    check("duplicate_payment_denied", api("POST", f"/api/orders/{order_id}/pay")["status"] == 409)
    shot("server-07-customer-paid.png")
    logout()

    login("staff")
    browser.find_element(By.CSS_SELECTOR, f'button[data-fulfill="{order_id}"]').click()
    wait.until(EC.visibility_of_element_located((By.ID, "confirm-dialog")))
    browser.find_element(By.ID, "confirm-accept").click()
    wait.until(lambda b: "已完成" in order_row(b))
    shot("server-08-staff-fulfilled.png")
    with db.session("manager") as repo:
        summary = repo.one("""SELECT b.BatchID,b.OnHandQty,c.PointsBalance,o.TotalAmount,o.OrderStatus
            FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem pi ON pi.PurchaseItemID=b.PurchaseItemID
            JOIN dbo.SalesOrder o ON o.SalesOrderID=%s
            JOIN dbo.Customer c ON c.CustomerID=o.CustomerID WHERE pi.ProductID=%s""", (order_id, product_id))
        reservation = repo.one("""SELECT COALESCE(SUM(r.ReservedQty),0) AS Qty
            FROM dbo.InventoryReservation r JOIN dbo.SalesOrderItem i ON i.SalesItemID=r.SalesItemID
            WHERE i.SalesOrderID=%s AND r.ReservationStatus=N'有效'""", (order_id,))
        payments = repo.one("SELECT COUNT(*) AS Qty FROM dbo.PaymentRecord WHERE SalesOrderID=%s AND PaymentStatus=N'成功'", (order_id,))
        movements = repo.one("""SELECT COUNT(*) AS Qty FROM dbo.InventoryMovement m
            JOIN dbo.SalesOrderItem i ON i.SalesItemID=m.SalesItemID
            WHERE i.SalesOrderID=%s AND m.MovementType=N'销售出库'""", (order_id,))
    check("final_stock_seven", int(summary["OnHandQty"]) == 7)
    check("final_reservation_zero", int(reservation["Qty"]) == 0)
    check("final_amount_7_50", Decimal(str(summary["TotalAmount"])) == Decimal("7.50"))
    check("member_points_once", int(summary["PointsBalance"]) == points_before + 7)
    check("payment_and_outbound_once", int(payments["Qty"]) == 1 and int(movements["Qty"]) == 1)
    check("order_completed", summary["OrderStatus"] == "已完成")
    result = {"commit": os.environ.get("DEPLOY_COMMIT", ""), "product_id": product_id,
              "batch_id": summary["BatchID"], "order_id": order_id,
              "stock_after": int(summary["OnHandQty"]), "active_reservation_after": int(reservation["Qty"]),
              "total_amount": str(summary["TotalAmount"]), "points_delta": int(summary["PointsBalance"]) - points_before,
              "successful_payments": int(payments["Qty"]), "outbound_movements": int(movements["Qty"]),
              "checks": checks, "screenshots": screenshots}
    (out / "server-flow-summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("WEEK7_SERVER_FLOW_PASS", len(checks))
finally:
    browser.quit()
