let csrf = "";
let user = null;
let products = [];
let cart = [];

const $ = (selector) => document.querySelector(selector);
const esc = (value) => String(value ?? "").replace(/[&<>"']/g, (ch) => ({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[ch]));
const notice = (message, error=false) => { const el=$("#notice"); el.textContent=message; el.classList.toggle("error",error); };
const money = (value) => Number(value).toFixed(2);

async function api(path, options={}) {
  const response = await fetch(path, {credentials:"same-origin", ...options,
    headers:{...(options.body ? {"Content-Type":"application/json"} : {}),
             ...(options.method && options.method!=="GET" ? {"X-CSRF-Token":csrf} : {}),
             ...(options.headers||{})}});
  let result;
  try { result=await response.json(); } catch { throw new Error("服务器返回了无法读取的结果"); }
  if (!response.ok || !result.ok) throw new Error(result.error?.message || "操作失败");
  return result.data;
}

async function action(work, message) {
  try { await work(); notice(message); } catch(error) { notice(error.message,true); }
}

function renderAccount() {
  $("#account").innerHTML = user ? `${esc(user.username)} · ${esc({customer:"顾客",staff:"店员",manager:"管理员"}[user.role])} <button type="button" id="logout" class="text-button">退出</button>` : "未登录";
  $("#login-form").hidden=!!user;
  $("#orders-panel").hidden=!user;
  $("#inventory-panel").hidden=!(user && user.role!=="customer");
  $("#new-order-panel").hidden=!(user && user.role==="customer");
  $("#product-form").hidden=!(user && user.role==="manager");
  $("#product-action-title").hidden=!(user && user.role==="manager");
  $("#logout")?.addEventListener("click",()=>action(async()=>{await api("/api/logout",{method:"POST"});user=null;cart=[];csrf=(await api("/api/session")).csrf;await refresh();},"已退出"));
}

async function refresh() {
  renderAccount();
  await loadProducts();
  if (user) await loadOrders(); else $("#orders-body").innerHTML="";
  if (user && user.role!=="customer") await loadInventory();
}

async function loadProducts(search="") {
  products=await api("/api/products?q="+encodeURIComponent(search));
  $("#products-body").innerHTML=products.map(p=>`<tr><td>${esc(p.ProductID)}</td><td>${esc(p.ProductName)}<br><small class="muted">${esc(p.Brand)} · ${esc(p.Specification)}</small></td><td>${esc(p.CategoryName)}</td><td>¥${money(p.CurrentPrice)}</td><td>${esc(p.AvailableQty)}</td><td>${esc(p.SaleStatus)}</td><td>${user?.role==="manager"?`<div class="actions"><button data-product-edit="${esc(p.ProductID)}">修改</button><button class="danger" data-product-delete="${esc(p.ProductID)}">删除</button></div>`:""}</td></tr>`).join("") || `<tr><td colspan="7">暂无商品</td></tr>`;
  $("#cart-product").innerHTML=products.filter(p=>p.SaleStatus==="在售").map(p=>`<option value="${esc(p.ProductID)}">${esc(p.ProductName)} · ${esc(p.ProductID)} · ¥${money(p.CurrentPrice)}</option>`).join("");
}

async function loadCategories() {
  const rows=await api("/api/categories");
  $("#product-form select[name=category_id]").innerHTML=rows.map(row=>`<option value="${esc(row.CategoryID)}">${esc(row.CategoryName)} (${esc(row.CategoryID)})</option>`).join("");
}

async function loadInventory() {
  const rows=await api("/api/inventory");
  $("#inventory-body").innerHTML=rows.map(row=>`<tr><td>${esc(row.BatchID)}</td><td>${esc(row.ProductName)}<br><small class="muted">${esc(row.ProductID)}</small></td><td>${esc(row.ExpiryDate)}</td><td>${esc(row.BatchStatus)}</td><td>${esc(row.OnHandQty)}</td><td>${esc(row.ReservedQty)}</td><td>${esc(row.UnreservedQty)}</td><td><button data-adjust="${esc(row.BatchID)}">盘点调整</button></td></tr>`).join("");
}

async function loadOrders() {
  const rows=await api("/api/orders");
  $("#orders-body").innerHTML=rows.map(row=>`<tr><td>${esc(row.SalesOrderID)}</td><td>${esc(row.CustomerID)}</td><td>${esc(row.CreatedAt)}</td><td>${esc(row.OrderStatus)}</td><td>¥${money(row.TotalAmount)}</td><td><div class="actions"><button data-detail="${esc(row.SalesOrderID)}">详情</button>${user?.role==="customer" && row.OrderStatus==="待支付" ? `<button data-pay="${esc(row.SalesOrderID)}">模拟支付</button><button class="danger" data-cancel="${esc(row.SalesOrderID)}">取消</button>`:""}${user?.role!=="customer" && row.OrderStatus==="待出库" ? `<button data-fulfill="${esc(row.SalesOrderID)}">确认出库</button>`:""}</div></td></tr>`).join("") || `<tr><td colspan="6">暂无订单</td></tr>`;
}

function renderCart() {
  $("#cart-list").innerHTML=cart.map((item,index)=>`<li>${esc(item.product_id)} × ${esc(item.quantity)} <button type="button" data-cart-remove="${index}" class="text-button">移除</button></li>`).join("") || `<li class="muted">尚未添加商品</li>`;
}

async function showDetail(orderId) {
  const data=await api("/api/orders/"+encodeURIComponent(orderId));
  const o=data.order;
  $("#detail-content").innerHTML=`<div class="detail-grid"><div>订单：${esc(o.SalesOrderID)}</div><div>状态：${esc(o.OrderStatus)}</div><div>收货人：${esc(o.RecipientName)}</div><div>联系电话：${esc(o.RecipientPhone)}</div><div>地址：${esc(o.ShippingAddress)}</div><div>金额：¥${money(o.TotalAmount)}</div></div><h3>订单明细</h3><div class="table-wrap"><table><thead><tr><th>明细</th><th>商品</th><th>数量</th><th>历史单价</th><th>操作</th></tr></thead><tbody>${data.items.map(i=>`<tr><td>${esc(i.SalesItemID)}</td><td>${esc(i.ProductName)}</td><td>${esc(i.Quantity)}</td><td>¥${money(i.DealUnitPrice)}</td><td>${user?.role==="customer" && o.OrderStatus==="待支付" ? `<div class="actions"><button data-item-edit="${esc(i.SalesItemID)}" data-order="${esc(o.SalesOrderID)}" data-qty="${esc(i.Quantity)}">改数量</button><button class="danger" data-item-delete="${esc(i.SalesItemID)}" data-order="${esc(o.SalesOrderID)}">删明细</button></div>`:""}</td></tr>`).join("")}</tbody></table></div>${user?.role==="customer" && o.OrderStatus==="待支付" ? `<div class="detail-actions"><button data-recipient="${esc(o.SalesOrderID)}">改收货信息</button><button data-item-add="${esc(o.SalesOrderID)}">加商品</button></div>`:""}`;
  if (!$("#detail-dialog").open) $("#detail-dialog").showModal();
}

document.addEventListener("DOMContentLoaded",async()=>{
  try { const data=await api("/api/session");csrf=data.csrf;user=data.user;await refresh();await loadCategories();renderCart(); }
  catch(error) {notice(error.message,true);}
});

$("#login-form").addEventListener("submit",event=>{event.preventDefault();const element=event.currentTarget;action(async()=>{
  const form=new FormData(element);
  const data=await api("/api/login",{method:"POST",body:JSON.stringify(Object.fromEntries(form))});
  csrf=data.csrf;user=data.user;element.reset();await refresh();
},"登录成功");});

$("#search-form").addEventListener("submit",event=>{event.preventDefault();const element=event.currentTarget;action(async()=>{await loadProducts(new FormData(element).get("q")||"");},"商品已更新");});
$("#reload-inventory").addEventListener("click",()=>action(loadInventory,"库存已更新"));
$("#reload-orders").addEventListener("click",()=>action(loadOrders,"订单已更新"));
$("#close-detail").addEventListener("click",()=>$("#detail-dialog").close());

$("#product-form").addEventListener("submit",event=>{event.preventDefault();const element=event.currentTarget;action(async()=>{
  const data=Object.fromEntries(new FormData(element));
  await api("/api/products",{method:"POST",body:JSON.stringify(data)});
  element.reset();await loadProducts();
},"商品已创建");});

$("#cart-add").addEventListener("click",()=>{
  const product_id=$("#cart-product").value,quantity=Number($("#cart-qty").value);
  if(!product_id||!Number.isInteger(quantity)||quantity<=0){notice("请选择商品并填写正整数数量",true);return;}
  const current=cart.find(x=>x.product_id===product_id);
  if(current)current.quantity+=quantity;else cart.push({product_id,quantity});
  renderCart();notice("已加入待提交订单");
});

$("#cart-list").addEventListener("click",event=>{
  const index=event.target.dataset.cartRemove;
  if(index===undefined)return;cart.splice(Number(index),1);renderCart();
});

$("#order-form").addEventListener("submit",event=>{event.preventDefault();const element=event.currentTarget;action(async()=>{
  if(!cart.length)throw new Error("请先添加商品");
  const data={...Object.fromEntries(new FormData(element)),items:cart};
  const result=await api("/api/orders",{method:"POST",body:JSON.stringify(data)});
  cart=[];renderCart();element.reset();await loadOrders();
  notice(`订单 ${result.order_id} 已创建，可在订单列表中模拟支付`);
},"订单已创建");});

document.addEventListener("click",event=>{
  const button=event.target.closest("button[data-product-edit],button[data-product-delete],button[data-adjust],button[data-detail],button[data-pay],button[data-cancel],button[data-fulfill],button[data-item-edit],button[data-item-delete],button[data-item-add],button[data-recipient]");
  if(!button)return;
  action(async()=>{
    const d=button.dataset;
    if(d.productEdit){const p=products.find(x=>x.ProductID===d.productEdit);const price=prompt("新售价",p.CurrentPrice);if(price===null)return;const status=prompt("状态：在售或停售",p.SaleStatus);if(status===null)return;const reorder_level=prompt("补货阈值",p.ReorderLevel);if(reorder_level===null)return;await api("/api/products/"+encodeURIComponent(p.ProductID),{method:"PATCH",body:JSON.stringify({price,status,reorder_level})});await loadProducts();}
    else if(d.productDelete){if(!confirm("仅无历史引用的商品可以删除。确定删除？"))return;await api("/api/products/"+encodeURIComponent(d.productDelete),{method:"DELETE"});await loadProducts();}
    else if(d.adjust){const delta=prompt("盘点调整数量（正数增加，负数减少）");if(delta===null)return;const reason=prompt("调整原因");if(reason===null)return;await api("/api/inventory/adjust",{method:"POST",body:JSON.stringify({batch_id:d.adjust,delta,reason})});await loadInventory();await loadProducts();}
    else if(d.detail){await showDetail(d.detail);return;}
    else if(d.pay){await api("/api/orders/"+encodeURIComponent(d.pay)+"/pay",{method:"POST"});await loadOrders();}
    else if(d.cancel){if(!confirm("取消待支付订单并释放库存锁定？"))return;await api("/api/orders/"+encodeURIComponent(d.cancel),{method:"DELETE"});await loadOrders();await loadProducts();}
    else if(d.fulfill){if(!confirm("确认已付款订单出库并扣减库存？"))return;await api("/api/orders/"+encodeURIComponent(d.fulfill)+"/fulfill",{method:"POST"});await loadOrders();await loadInventory();}
    else if(d.itemEdit){const quantity=prompt("新的数量",d.qty);if(quantity===null)return;await api(`/api/orders/${encodeURIComponent(d.order)}/items/${encodeURIComponent(d.itemEdit)}`,{method:"PATCH",body:JSON.stringify({quantity})});await showDetail(d.order);await loadOrders();}
    else if(d.itemDelete){if(!confirm("删除这条待支付明细？"))return;await api(`/api/orders/${encodeURIComponent(d.order)}/items/${encodeURIComponent(d.itemDelete)}`,{method:"DELETE"});await showDetail(d.order);await loadOrders();}
    else if(d.itemAdd){const product_id=prompt("商品编号");if(product_id===null)return;const quantity=prompt("数量");if(quantity===null)return;await api(`/api/orders/${encodeURIComponent(d.itemAdd)}/items`,{method:"POST",body:JSON.stringify({product_id,quantity})});await showDetail(d.itemAdd);await loadOrders();}
    else if(d.recipient){const recipient_name=prompt("收货人");if(recipient_name===null)return;const recipient_phone=prompt("联系电话");if(recipient_phone===null)return;const shipping_address=prompt("收货地址");if(shipping_address===null)return;await api(`/api/orders/${encodeURIComponent(d.recipient)}`,{method:"PATCH",body:JSON.stringify({recipient_name,recipient_phone,shipping_address})});await showDetail(d.recipient);}
  },"操作完成");
});
