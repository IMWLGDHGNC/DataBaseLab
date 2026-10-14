# 第 7–9 周 Web 应用操作手册

本应用把第六周 SQL Server v1.0 样例库接入浏览器。页面、Flask 路由、业务服务、DAO 和数据库的职责见 [Week7 设计说明](../docs/Week7.md)。登录账号仅为课程演示账号，顾客账号绑定样例顾客，店员和管理员绑定样例员工；真实密码由部署时随机生成，不进入 Git。

## 环境与目录

- Python 3.12、`uv`、Flask、pymssql、Gunicorn；SQL Server 2022 容器监听服务器环回地址。
- `app/templates/` 与 `app/static/` 是页面；`web.py` 是路由、会话和统一错误；`service.py` 是角色与业务规则；`db.py` 是唯一执行 SQL 的 DAO；`bootstrap.py` 创建私有配置。
- `sql/week7/permissions.sql` 为顾客、店员、管理员分别授予本阶段所需的表级或列级权限。Web 不使用 `sa`；不得公开私有配置和演示口令。

## 从空样例库复现

在授权的 Linux 服务器上，把完整仓库放在独立目录，确认 SQL Server 容器可用并设置私有 `DB_CONTAINER` 变量，然后从仓库根目录执行：

```bash
scripts/Run-Week7-Server.sh
```

脚本先运行第六周完整复现，在**新建的独立库**中通过迁移和回归后，为 Web 应用创建虚拟环境、三个受限 SQL 登录、角色授权和私有配置。输出包含 `WEEK6_SERVER_PASS`、`WEEK7_PERMISSIONS_PASS`、`WEEK7_DEPLOY_PREP_PASS`。失败时停在当前阶段，不接触既有正式库。它不会删除旧数据库。

在同一服务器会话中启动页面：

```bash
export APP_CONFIG_FILE="$(cat output/week7/config-path.txt)"
scripts/Start-Week7-Web.sh
```

默认只监听服务器的 `127.0.0.1:8767`。保持进程运行；要从自己的电脑查看，请由授权人员建立 SSH 本地端口转发后在浏览器打开对应的本机地址。不要把课程服务器地址、账号或密码写入仓库。部署脚本打印私有演示口令文件的位置；文件权限为 `600`，仅在服务器受控终端查看。

停止 Web 服务时，在运行终端按 `Ctrl+C`。若后台启动，请读取 `output/week7/web.pid` 并向该进程发送 `TERM`；不要停止 SQL Server 容器。原始部署日志和访问日志留在被忽略的 `output/week7/`。

## 页面操作顺序

1. 顾客登录，浏览在售商品，添加一条或多条订单明细，填写收货人、电话和地址，提交订单。订单创建只建立有效库存锁定，现存量不变。
2. 顾客可在待支付阶段修改收货信息和明细数量、添加或删除明细，也可取消订单释放锁定。模拟支付后状态变为待出库，禁止再修改明细。
3. 店员登录，查看批次库存和所有订单。对待出库且批次仍合格、未到期的订单确认出库；数据库同时扣减现存量、写销售出库流水、结束锁定、完成订单并给会员赠分。店员可做有理由的盘点调整，调整后现存量不得低于有效锁定量。
4. 管理员可查看订单和库存、确认出库，另可新增商品、修改价格/状态/补货阈值，删除无历史引用的商品；有历史记录的商品应停售。
5. 管理员新增商品后，在库存区选择该商品和供应商，填写采购数量与成本，提交并审批单商品采购单。店员从待验收采购选择该单，填供应商批号、生产/到期日期及验收说明，确认整单入库。系统同时记录采购来源、批次、入库流水和收货状态，新商品随后可下单。

管理员负责商品、采购审批、库存和出库，顾客订单创建、草稿编辑、取消和支付均由顾客本人执行。已有库存退出通过带原因的盘点清零，保留批次和历史流水；有有效锁定时不能清零。本阶段的 Web 采购入口每单一个商品，已有多明细历史采购不经此入口重收货。

## API 与反馈

浏览器调用 `/api/*`，读请求采用 GET，写请求带会话 Cookie 和 `X-CSRF-Token`。主要接口：`/api/login`、`/api/products`、`/api/inventory`、`/api/inventory/adjust`、`/api/orders`、`/api/orders/<id>/items`、`/api/orders/<id>/pay`、`/api/orders/<id>/fulfill`。成功响应为 `ok/data/request_id`，失败为 `ok/error{code,message}/request_id`。页面不展示 SQL、连接信息或堆栈；私有日志记录请求标识、操作、角色、状态和错误类别。

可运行 `APP_CONFIG_FILE=<私有配置路径> output/week7/.venv/bin/python tests/Test-Week7-Web.py` 验证登录、角色差异、商品维护、订单明细变更、支付、出库、库存调整、缺货回滚和数据库故障提示。**测试会写入当前配置指向的数据库，只能对本次新建的独立样例库执行。**

该命令从仓库根目录直接运行，无需额外设置 PYTHONPATH。修复版共 103 项检查，还覆盖新增商品采购入库至销售出库的完整角色流程、整数/金额上限、写入中途失败后回滚、两个不同顾客争抢、同时支付，以及下单/出库交叉锁定的回归。安全的响应与流程摘要写入 `output/week7/review-evidence.json`，不包含口令、连接配置或内部堆栈；检查后可整理到 result。本轮实际 103 项通过环境为独立 SQL Server 2022 LocalDB，测试过程用私有 ODBC 适配连接，生产驱动的断连分类另用真实 pymssql 验证；原 Linux/pymssql/Gunicorn 修复版尚待重部署，详见[验证边界](../result/week7/review-validation-20261014.md)。

API 补充 `/api/suppliers`、`/api/purchases`（查询待验收及管理员建立审批）、`POST /api/inventory`（店员/管理员验收）。新版本部署时必须运行更新后的授权脚本；新样例库的部署脚本会自动应用。所有业务写入先获取事务级共同锁，十秒超时或死锁返回 `TRANSACTION_CONFLICT`；其他事务失败返回 `TRANSACTION_FAILED`，连接失败返回 `DATABASE_UNAVAILABLE`，数值超限返回 `INVALID_INPUT`。

## 页面截图复现

截图使用 Firefox 与 Selenium，属于证据采集依赖，不是 Web 服务启动必需依赖。在服务器安装 Firefox 后，可为本次隔离环境安装截图依赖并运行：

```bash
uv pip install --python output/week7/.venv/bin/python -r tests/requirements-screenshots.txt
export APP_CONFIG_FILE="$(cat output/week7/config-path.txt)"
output/week7/.venv/bin/python tests/Capture-Week7-Ui.py
```

脚本在服务器本地读取私有演示身份，默认写入被忽略的 `output/week7/screenshots/`。如果 Firefox 位于非标准路径，可通过 `FIREFOX_BINARY` 指定。发布前逐张检查页面可见内容和元数据；不要复制演示口令或私有配置。
