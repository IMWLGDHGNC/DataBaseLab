"""Business rules and transaction boundaries for the Week 7–9 application."""

from collections import defaultdict
from decimal import Decimal, InvalidOperation
import secrets


class AppError(Exception):
    def __init__(self, code, message, status=400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status


def required_text(value, label, limit):
    if not isinstance(value, str) or not value.strip() or len(value.strip()) > limit:
        raise AppError("INVALID_INPUT", f"{label}不能为空，且不能超过 {limit} 个字符")
    return value.strip()


def positive_int(value, label):
    if isinstance(value, bool):
        raise AppError("INVALID_INPUT", f"{label}必须为正整数")
    try:
        number = int(value)
    except (ValueError, TypeError):
        raise AppError("INVALID_INPUT", f"{label}必须为正整数") from None
    if number <= 0 or str(number) != str(value):
        raise AppError("INVALID_INPUT", f"{label}必须为正整数")
    return number


def nonnegative_int(value, label):
    if isinstance(value, bool):
        raise AppError("INVALID_INPUT", f"{label}不能为负数")
    try:
        number = int(value)
    except (ValueError, TypeError):
        raise AppError("INVALID_INPUT", f"{label}必须为整数") from None
    if number < 0 or str(number) != str(value):
        raise AppError("INVALID_INPUT", f"{label}不能为负数")
    return number


def money(value):
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, TypeError):
        raise AppError("INVALID_INPUT", "价格格式不正确") from None
    if not amount.is_finite() or amount <= 0 or amount > Decimal("99999999.99"):
        raise AppError("INVALID_INPUT", "价格必须大于零且在允许范围内")
    if amount.as_tuple().exponent < -2:
        raise AppError("INVALID_INPUT", "价格最多保留两位小数")
    return amount.quantize(Decimal("0.01"))


def new_id(prefix):
    return prefix + secrets.token_hex(5).upper()


def require_role(user, *roles):
    if user is None:
        raise AppError("UNAUTHENTICATED", "请先登录", 401)
    if user["role"] not in roles:
        raise AppError("FORBIDDEN", "当前账号无权执行此操作", 403)


class ShopService:
    def __init__(self, database):
        self.db = database

    @staticmethod
    def _visible_order(order, user):
        if order is None or (user["role"] == "customer" and
                             order["CustomerID"] != user["customer_id"]):
            raise AppError("NOT_FOUND", "订单不存在", 404)
        return order

    @staticmethod
    def _editable_order(order):
        if order["OrderStatus"] != "待支付":
            raise AppError("BUSINESS_CONFLICT", "只有待支付订单可以修改", 409)

    @staticmethod
    def _recipient(payload):
        if not isinstance(payload, dict):
            raise AppError("INVALID_INPUT", "请填写收货信息")
        return {
            "recipient_name": required_text(payload.get("recipient_name"), "收货人", 40),
            "recipient_phone": required_text(payload.get("recipient_phone"), "联系电话", 20),
            "shipping_address": required_text(payload.get("shipping_address"), "收货地址", 200),
        }

    @staticmethod
    def _lines(payload):
        items = payload.get("items") if isinstance(payload, dict) else None
        if not isinstance(items, list) or not items or len(items) > 20:
            raise AppError("INVALID_INPUT", "订单需要 1 至 20 条商品明细")
        lines = []
        seen = set()
        for item in items:
            if not isinstance(item, dict):
                raise AppError("INVALID_INPUT", "商品明细格式不正确")
            product_id = required_text(item.get("product_id"), "商品编号", 12)
            if product_id in seen:
                raise AppError("INVALID_INPUT", "同一商品请合并为一条明细")
            seen.add(product_id)
            lines.append((product_id, positive_int(item.get("quantity"), "数量")))
        return sorted(lines)

    @staticmethod
    def _allocate(repo, product_id, quantity):
        product = repo.product(product_id, lock=True)
        if product is None or product["SaleStatus"] != "在售":
            raise AppError("BUSINESS_CONFLICT", "商品不存在或已停售", 409)
        remaining = quantity
        allocations = []
        for batch in repo.batches_for_product(product_id):
            available = int(batch["OnHandQty"]) - int(batch["ReservedQty"])
            if available <= 0:
                continue
            take = min(remaining, available)
            allocations.append((batch["BatchID"], take))
            remaining -= take
            if remaining == 0:
                break
        if remaining:
            raise AppError("INSUFFICIENT_STOCK", f"商品 {product_id} 可售库存不足", 409)
        return product, allocations

    def products(self, search=""):
        if not isinstance(search, str) or len(search) > 100:
            raise AppError("INVALID_INPUT", "搜索内容过长")
        # Anonymous readers use the customer read-only permission set.
        with self.db.session("customer") as repo:
            return repo.products(search.strip())

    def categories(self):
        with self.db.session("customer") as repo:
            return repo.categories()

    def add_product(self, user, payload):
        require_role(user, "manager")
        if not isinstance(payload, dict):
            raise AppError("INVALID_INPUT", "商品信息格式不正确")
        data = {
            "product_id": required_text(payload.get("product_id"), "商品编号", 12),
            "category_id": required_text(payload.get("category_id"), "类别编号", 12),
            "name": required_text(payload.get("name"), "商品名称", 100),
            "brand": required_text(payload.get("brand"), "品牌", 60),
            "specification": required_text(payload.get("specification"), "规格", 60),
            "unit": required_text(payload.get("unit"), "销售单位", 10),
            "price": money(payload.get("price")),
            "reorder_level": nonnegative_int(payload.get("reorder_level", 0), "补货阈值"),
        }
        with self.db.session("manager", write=True) as repo:
            repo.insert_product(data)
        return {"product_id": data["product_id"]}

    def change_product(self, user, product_id, payload):
        require_role(user, "manager")
        product_id = required_text(product_id, "商品编号", 12)
        if not isinstance(payload, dict):
            raise AppError("INVALID_INPUT", "商品信息格式不正确")
        status = payload.get("status")
        if status not in ("在售", "停售"):
            raise AppError("INVALID_INPUT", "商品状态只能是在售或停售")
        data = {"price": money(payload.get("price")), "status": status,
                "reorder_level": nonnegative_int(payload.get("reorder_level"), "补货阈值")}
        with self.db.session("manager", write=True) as repo:
            if repo.update_product(product_id, data) != 1:
                raise AppError("NOT_FOUND", "商品不存在", 404)
        return {"product_id": product_id}

    def remove_product(self, user, product_id):
        require_role(user, "manager")
        product_id = required_text(product_id, "商品编号", 12)
        with self.db.session("manager", write=True) as repo:
            if repo.delete_product(product_id) != 1:
                raise AppError("NOT_FOUND", "商品不存在", 404)
        return {"product_id": product_id}

    def inventory(self, user):
        require_role(user, "staff", "manager")
        with self.db.session(user["role"]) as repo:
            return repo.inventory()

    def adjust_inventory(self, user, payload):
        require_role(user, "staff", "manager")
        if not isinstance(payload, dict):
            raise AppError("INVALID_INPUT", "库存调整信息格式不正确")
        batch_id = required_text(payload.get("batch_id"), "批次编号", 12)
        reason = required_text(payload.get("reason"), "调整原因", 200)
        try:
            delta = int(payload.get("delta"))
        except (TypeError, ValueError):
            raise AppError("INVALID_INPUT", "调整数量必须为非零整数") from None
        if isinstance(payload.get("delta"), bool) or delta == 0 or abs(delta) > 100000 or str(delta) != str(payload.get("delta")):
            raise AppError("INVALID_INPUT", "调整数量必须为非零整数")
        with self.db.session(user["role"], write=True) as repo:
            batch = repo.batch(batch_id, lock=True)
            if batch is None:
                raise AppError("NOT_FOUND", "批次不存在", 404)
            reserved = repo.reserved_in_batch(batch_id)
            if int(batch["OnHandQty"]) + delta < reserved:
                raise AppError("BUSINESS_CONFLICT", "调整后库存不能低于有效锁定量", 409)
            repo.change_stock(batch_id, delta, new_id("IM"), user["employee_id"], reason)
        return {"batch_id": batch_id, "delta": delta}

    def orders(self, user):
        require_role(user, "customer", "staff", "manager")
        customer_id = user["customer_id"] if user["role"] == "customer" else None
        with self.db.session(user["role"]) as repo:
            return repo.orders(customer_id)

    def order_detail(self, user, order_id):
        require_role(user, "customer", "staff", "manager")
        order_id = required_text(order_id, "订单编号", 12)
        with self.db.session(user["role"]) as repo:
            order = self._visible_order(repo.order(order_id), user)
            return {"order": order, "items": repo.order_items(order_id)}

    def create_order(self, user, payload):
        require_role(user, "customer")
        recipient = self._recipient(payload)
        lines = self._lines(payload)
        with self.db.session("customer", write=True) as repo:
            customer = repo.customer(user["customer_id"], lock=True)
            if customer is None or customer["ActiveStatus"] != "正常":
                raise AppError("BUSINESS_CONFLICT", "顾客账号不可下单", 409)
            planned = []
            total = Decimal("0.00")
            for product_id, quantity in lines:
                product, allocations = self._allocate(repo, product_id, quantity)
                total += product["CurrentPrice"] * quantity
                planned.append((product_id, quantity, product["CurrentPrice"], allocations))
            if total > Decimal("99999999.99"):
                raise AppError("INVALID_INPUT", "订单金额超出允许范围")
            order_id = new_id("SO")
            repo.insert_order(order_id, user["customer_id"], recipient, total)
            for product_id, quantity, price, allocations in planned:
                item_id = new_id("SI")
                repo.insert_item(item_id, order_id, product_id, quantity, price)
                for batch_id, take in allocations:
                    repo.insert_reservation(new_id("RS"), item_id, batch_id, take)
        return {"order_id": order_id, "total_amount": total}

    def change_recipient(self, user, order_id, payload):
        require_role(user, "customer")
        data = self._recipient(payload)
        with self.db.session("customer", write=True) as repo:
            order = self._visible_order(repo.order(order_id, lock=True), user)
            self._editable_order(order)
            repo.update_order_recipient(order_id, data)
        return {"order_id": order_id}

    def add_order_item(self, user, order_id, payload):
        require_role(user, "customer")
        if not isinstance(payload, dict):
            raise AppError("INVALID_INPUT", "明细格式不正确")
        product_id = required_text(payload.get("product_id"), "商品编号", 12)
        quantity = positive_int(payload.get("quantity"), "数量")
        with self.db.session("customer", write=True) as repo:
            order = self._visible_order(repo.order(order_id, lock=True), user)
            self._editable_order(order)
            if len(repo.order_items(order_id)) >= 20:
                raise AppError("INVALID_INPUT", "订单明细不能超过 20 条")
            product, allocations = self._allocate(repo, product_id, quantity)
            item_id = new_id("SI")
            repo.insert_item(item_id, order_id, product_id, quantity, product["CurrentPrice"])
            for batch_id, take in allocations:
                repo.insert_reservation(new_id("RS"), item_id, batch_id, take)
            total = repo.order_total(order_id)
            repo.update_order_total(order_id, total)
        return {"order_id": order_id, "item_id": item_id, "total_amount": total}

    def change_order_item(self, user, order_id, item_id, payload):
        require_role(user, "customer")
        if not isinstance(payload, dict):
            raise AppError("INVALID_INPUT", "明细格式不正确")
        quantity = positive_int(payload.get("quantity"), "数量")
        with self.db.session("customer", write=True) as repo:
            order = self._visible_order(repo.order(order_id, lock=True), user)
            self._editable_order(order)
            item = next((x for x in repo.order_items(order_id) if x["SalesItemID"] == item_id), None)
            if item is None:
                raise AppError("NOT_FOUND", "订单明细不存在", 404)
            repo.release_item_reservations(item_id)
            _, allocations = self._allocate(repo, item["ProductID"], quantity)
            repo.update_item_quantity(item_id, quantity)
            for batch_id, take in allocations:
                repo.insert_reservation(new_id("RS"), item_id, batch_id, take)
            total = repo.order_total(order_id)
            repo.update_order_total(order_id, total)
        return {"order_id": order_id, "item_id": item_id, "total_amount": total}

    def remove_order_item(self, user, order_id, item_id):
        require_role(user, "customer")
        with self.db.session("customer", write=True) as repo:
            order = self._visible_order(repo.order(order_id, lock=True), user)
            self._editable_order(order)
            items = repo.order_items(order_id)
            if not any(x["SalesItemID"] == item_id for x in items):
                raise AppError("NOT_FOUND", "订单明细不存在", 404)
            if len(items) == 1:
                raise AppError("BUSINESS_CONFLICT", "最后一条明细请通过取消订单处理", 409)
            repo.delete_item(item_id)
            total = repo.order_total(order_id)
            repo.update_order_total(order_id, total)
        return {"order_id": order_id, "item_id": item_id, "total_amount": total}

    def cancel_order(self, user, order_id):
        require_role(user, "customer")
        with self.db.session("customer", write=True) as repo:
            order = self._visible_order(repo.order(order_id, lock=True), user)
            self._editable_order(order)
            repo.release_order_reservations(order_id)
            repo.set_order_status(order_id, "已取消")
        return {"order_id": order_id}

    def pay_order(self, user, order_id):
        require_role(user, "customer")
        with self.db.session("customer", write=True) as repo:
            order = self._visible_order(repo.order(order_id, lock=True), user)
            self._editable_order(order)
            if repo.successful_payment(order_id):
                raise AppError("BUSINESS_CONFLICT", "订单已经支付", 409)
            if not repo.order_items(order_id):
                raise AppError("BUSINESS_CONFLICT", "空订单不能支付", 409)
            repo.insert_payment(new_id("PY"), order_id,
                                "SIM-W7-" + secrets.token_hex(8).upper(),
                                order["TotalAmount"])
            repo.set_order_status(order_id, "待出库")
        return {"order_id": order_id, "status": "待出库"}

    def fulfill_order(self, user, order_id):
        require_role(user, "staff", "manager")
        with self.db.session(user["role"], write=True) as repo:
            order = repo.order(order_id, lock=True)
            if order is None:
                raise AppError("NOT_FOUND", "订单不存在", 404)
            if order["OrderStatus"] != "待出库" or not repo.successful_payment(order_id):
                raise AppError("BUSINESS_CONFLICT", "订单尚未满足出库条件", 409)
            reservations = repo.active_reservations_for_order(order_id)
            if not reservations:
                raise AppError("BUSINESS_CONFLICT", "订单缺少库存锁定", 409)
            per_item = defaultdict(int)
            per_batch = defaultdict(int)
            expected = {}
            for reservation in reservations:
                item_id = reservation["SalesItemID"]
                expected[item_id] = int(reservation["Quantity"])
                if reservation["ReservationID"] is None:
                    raise AppError("BUSINESS_CONFLICT", "订单明细缺少有效锁定", 409)
                if reservation["ProductID"] != reservation["BatchProductID"]:
                    raise AppError("BUSINESS_CONFLICT", "锁定批次与商品不一致", 409)
                if reservation["BatchStatus"] != "合格":
                    raise AppError("BUSINESS_CONFLICT", "锁定批次不可出库", 409)
                if not reservation["IsUnexpired"]:
                    raise AppError("BUSINESS_CONFLICT", "锁定批次已到期，暂停出库", 409)
                per_item[item_id] += int(reservation["ReservedQty"])
                per_batch[reservation["BatchID"]] += int(reservation["ReservedQty"])
            if per_item != expected:
                raise AppError("BUSINESS_CONFLICT", "明细数量与库存锁定不一致", 409)
            for batch_id, quantity in per_batch.items():
                batch = repo.batch(batch_id, lock=True)
                if int(batch["OnHandQty"]) < repo.reserved_in_batch(batch_id) or int(batch["OnHandQty"]) < quantity:
                    raise AppError("BUSINESS_CONFLICT", "库存与有效锁定不一致", 409)
            for reservation in reservations:
                repo.ship_reservation(reservation, new_id("IM"), user["employee_id"],
                                      f"{order_id} 确认出库")
            repo.set_order_status(order_id, "已完成", completed=True)
            customer = repo.customer(order["CustomerID"], lock=True)
            if customer and customer["IsMember"]:
                if repo.points_for_order(order_id):
                    raise AppError("BUSINESS_CONFLICT", "该订单已赠送积分", 409)
                points = int(order["TotalAmount"])
                if points > 0:
                    repo.award_points(new_id("PM"), order["CustomerID"], order_id,
                                      points, order["TotalAmount"])
        return {"order_id": order_id, "status": "已完成"}
