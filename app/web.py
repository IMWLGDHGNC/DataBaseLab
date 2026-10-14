"""Flask routes, login/session handling, and centralized API errors."""

import json
import logging
import os
from pathlib import Path
import secrets

from flask import Flask, g, jsonify, render_template, request, session
import pymssql
from werkzeug.exceptions import HTTPException
from werkzeug.security import check_password_hash

from app.db import Database
from app.service import AppError, ShopService


def create_app(config=None):
    if config is None:
        config_path = os.environ.get("APP_CONFIG_FILE")
        if not config_path:
            raise RuntimeError("APP_CONFIG_FILE must point to a private configuration file")
        config = json.loads(Path(config_path).read_text(encoding="utf-8"))
    app = Flask(__name__)
    app.secret_key = config["session_secret"]
    app.logger.setLevel(logging.INFO)
    app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax")
    service = ShopService(Database(config))
    users = config["app_users"]

    def current_user():
        name = session.get("username")
        user = users.get(name) if name else None
        if user is None:
            return None
        return {"username": name, "role": user["role"],
                "customer_id": user.get("customer_id"),
                "employee_id": user.get("employee_id")}

    def success(data=None, status=200):
        return jsonify({"ok": True, "data": data, "request_id": g.request_id}), status

    def failure(code, message, status):
        return jsonify({"ok": False, "error": {"code": code, "message": message},
                        "request_id": g.request_id}), status

    def body():
        value = request.get_json(silent=True)
        if not isinstance(value, dict):
            raise AppError("INVALID_INPUT", "请求内容必须为 JSON 对象")
        return value

    @app.before_request
    def prepare_request():
        g.request_id = secrets.token_hex(6)
        user = current_user()
        g.role = user["role"] if user else "anonymous"
        if request.path.startswith("/api/") and request.method in ("POST", "PATCH", "PUT", "DELETE"):
            token = session.get("csrf")
            if not token or not secrets.compare_digest(request.headers.get("X-CSRF-Token", ""), token):
                raise AppError("INVALID_CSRF", "页面已过期，请刷新后重试", 403)

    @app.after_request
    def log_result(response):
        app.logger.info("request_id=%s operation=%s role=%s status=%s result=%s",
                        g.request_id, request.endpoint or request.path, g.role,
                        response.status_code, "ok" if response.status_code < 400 else "failed")
        response.headers["X-Request-ID"] = g.request_id
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.errorhandler(AppError)
    def handle_app_error(exc):
        app.logger.warning("request_id=%s code=%s role=%s", g.request_id, exc.code, g.role)
        return failure(exc.code, exc.message, exc.status)

    @app.errorhandler(pymssql.DatabaseError)
    def handle_db_error(exc):
        number = exc.args[0] if exc.args and isinstance(exc.args[0], int) else None
        app.logger.exception("request_id=%s code=DB_%s role=%s", g.request_id, number, g.role)
        if number in (2601, 2627, 547, 515, 50000):
            return failure("CONSTRAINT_CONFLICT", "操作与现有数据或约束冲突，请检查输入", 409)
        return failure("DATABASE_UNAVAILABLE", "数据库暂时无法完成操作，请稍后重试", 503)

    @app.errorhandler(HTTPException)
    def handle_http_error(exc):
        return failure("NOT_FOUND" if exc.code == 404 else "HTTP_ERROR",
                       "请求的页面或操作不存在" if exc.code == 404 else "请求无法处理", exc.code)

    @app.errorhandler(Exception)
    def handle_unexpected_error(exc):
        app.logger.exception("request_id=%s code=INTERNAL role=%s", g.request_id, g.role)
        return failure("INTERNAL_ERROR", "系统暂时无法完成操作", 500)

    @app.get("/")
    def index():
        session.setdefault("csrf", secrets.token_urlsafe(24))
        return render_template("index.html")

    @app.get("/api/session")
    def session_info():
        session.setdefault("csrf", secrets.token_urlsafe(24))
        return success({"user": current_user(), "csrf": session["csrf"]})

    @app.post("/api/login")
    def login():
        value = body()
        name = value.get("username")
        password = value.get("password")
        record = users.get(name) if isinstance(name, str) else None
        if not isinstance(password, str) or record is None or not check_password_hash(record["password_hash"], password):
            raise AppError("AUTH_FAILED", "账号或密码不正确", 401)
        session.clear()
        session["username"] = name
        session["csrf"] = secrets.token_urlsafe(24)
        g.role = record["role"]
        return success({"user": current_user(), "csrf": session["csrf"]})

    @app.post("/api/logout")
    def logout():
        session.clear()
        g.role = "anonymous"
        return success({"message": "已退出"})

    @app.get("/api/products")
    def products():
        return success(service.products(request.args.get("q", "")))

    @app.get("/api/categories")
    def categories():
        return success(service.categories())

    @app.post("/api/products")
    def add_product():
        return success(service.add_product(current_user(), body()), 201)

    @app.patch("/api/products/<product_id>")
    def change_product(product_id):
        return success(service.change_product(current_user(), product_id, body()))

    @app.delete("/api/products/<product_id>")
    def remove_product(product_id):
        return success(service.remove_product(current_user(), product_id))

    @app.get("/api/inventory")
    def inventory():
        return success(service.inventory(current_user()))

    @app.post("/api/inventory/adjust")
    def adjust_inventory():
        return success(service.adjust_inventory(current_user(), body()))

    @app.get("/api/orders")
    def orders():
        return success(service.orders(current_user()))

    @app.post("/api/orders")
    def create_order():
        return success(service.create_order(current_user(), body()), 201)

    @app.get("/api/orders/<order_id>")
    def order_detail(order_id):
        return success(service.order_detail(current_user(), order_id))

    @app.patch("/api/orders/<order_id>")
    def change_recipient(order_id):
        return success(service.change_recipient(current_user(), order_id, body()))

    @app.post("/api/orders/<order_id>/items")
    def add_order_item(order_id):
        return success(service.add_order_item(current_user(), order_id, body()), 201)

    @app.patch("/api/orders/<order_id>/items/<item_id>")
    def change_order_item(order_id, item_id):
        return success(service.change_order_item(current_user(), order_id, item_id, body()))

    @app.delete("/api/orders/<order_id>/items/<item_id>")
    def remove_order_item(order_id, item_id):
        return success(service.remove_order_item(current_user(), order_id, item_id))

    @app.delete("/api/orders/<order_id>")
    def cancel_order(order_id):
        return success(service.cancel_order(current_user(), order_id))

    @app.post("/api/orders/<order_id>/pay")
    def pay_order(order_id):
        return success(service.pay_order(current_user(), order_id))

    @app.post("/api/orders/<order_id>/fulfill")
    def fulfill_order(order_id):
        return success(service.fulfill_order(current_user(), order_id))

    return app


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    create_app().run(host="127.0.0.1", port=int(os.environ.get("APP_PORT", "8767")))
