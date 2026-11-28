# Web 应用操作手册

Web 应用以第六周 SQL Server v1.0 样例库为基线。页面、Flask 路由、业务服务、DAO 和数据库的职责见[第7–9周设计说明](../docs/week7-9/README.md)。部署脚本为样例顾客、店员和管理员生成私有演示账号与密码。

当前代码整合第10至13周数据库实现。盘点、订单完成、计价与采购验收入库由 SQL Server 负责。会员下单享九五折，订单详情保留实际优惠及历史成交价。订单完成和采购入库采用统一库存访问顺序。已有 v1.0 库按 [SQL 安装顺序](../sql/README.md)升级后再连接当前应用。

## 环境与目录

- Python 3.12、`uv`、Flask、pymssql、Gunicorn；SQL Server 2022 容器监听服务器环回地址。
- `app/templates/` 与 `app/static/` 是页面；`web.py` 负责路由、会话和统一错误；`service.py` 负责角色、输入校验及请求组织；`db.py` 调用计价、盘点、订单完成和验收入库等 SQL 过程；`bootstrap.py` 创建私有配置。
- [第7周授权](../sql/week7/permissions.sql)创建三类受限角色。[第10周授权](../sql/week10/permissions.sql)配置盘点、订单完成等过程的执行权限，[第12周授权](../sql/week12/permissions.sql)配置入库过程执行权限。Web 用受限登录连接，部署配置和演示口令保存在私有目录。

## 从空样例库复现

在授权的 Linux 服务器上，把完整仓库放在独立目录，确认 SQL Server 容器可用并设置私有 `DB_CONTAINER` 变量，然后从仓库根目录执行：

```bash
bash scripts/Run-Week7-Server.sh
```

脚本创建 Python 虚拟环境，在**新建的独立库**中完成第六周迁移和回归，再建立三个受限 SQL 登录和私有配置，并按[安装顺序](../sql/README.md#从空库安装当前-web-应用)加载应用对象。等脚本输出 `WEEK7_DEPLOY_PREP_PASS` 后使用该次生成的配置启动页面。部署或验收在专用样例库进行。

在同一服务器会话中启动页面：

```bash
export APP_CONFIG_FILE="$(cat output/week7/config-path.txt)"
bash scripts/Start-Week7-Web.sh
```

默认只监听服务器的 `127.0.0.1:8767`；若同时保留旧演示进程，可在启动前设置未占用的 `APP_PORT`。保持进程运行；要从自己的电脑查看，请由授权人员建立本地端口转发后在浏览器打开对应的本机地址。部署脚本打印私有演示口令文件的位置；文件权限为 `600`，仅在服务器受控终端查看。

停止 Web 服务时，在运行终端按 `Ctrl+C`。若后台启动，请读取 `output/week7/web.pid` 并向该进程发送 `TERM`；不要停止 SQL Server 容器。原始部署日志和访问日志留在被忽略的 `output/week7/`。

## 页面操作顺序

1. 顾客登录，浏览在售商品，添加一条或多条订单明细，填写收货人、电话和地址，提交订单。订单创建只建立有效库存锁定，现存量不变。
2. 顾客可在待支付阶段修改收货信息和明细数量、添加或删除明细，也可取消订单释放锁定。模拟支付后状态变为待出库，禁止再修改明细。
3. 店员登录，查看批次库存和所有订单。对待出库且批次仍合格、未到期的订单确认出库；数据库同时扣减现存量、写销售出库流水、结束锁定、完成订单并给会员赠分。店员可做有理由的盘点调整，调整后现存量不得低于有效锁定量。
4. 管理员可查看订单和库存、确认出库，另可新增商品、修改价格/状态/补货阈值，删除无历史引用的商品；有历史记录的商品应停售。
5. 管理员新增商品后，在库存区选择该商品和供应商，填写采购数量与成本，提交并审批单商品采购单。店员从待验收采购选择该单，填供应商批号、生产/到期日期及验收说明，确认整单入库。系统同时记录采购来源、批次、入库流水和收货状态，新商品随后可下单。

管理员负责商品、采购审批、库存和出库，顾客订单创建、草稿编辑、取消和支付均由顾客本人执行。已有库存退出通过带原因的盘点清零，保留批次和历史流水；有有效锁定时不能清零。本阶段的 Web 采购入口每单一个商品，已有多明细历史采购不经此入口重收货。

## API 与反馈

浏览器调用 `/api/*`，读请求采用 GET，写请求带会话 Cookie 和 `X-CSRF-Token`。订单接口覆盖下单、明细修改、支付和出库。采购通过 `/api/purchases` 查询或建立已审批的采购单，通过 `POST /api/inventory` 验收。店员和管理员可通过 `/api/replenishment/<product_id>` 查询补货建议，或通过 `/api/sales-summary` 查询完成销售。完整路由见 [web.py](web.py)。

成功响应为 `ok/data/request_id`，失败为 `ok/error{code,message}/request_id`。私有日志记录请求标识、操作、角色、状态和错误类别。所有业务写入先获取事务级共同锁，锁等待超时或死锁返回 `TRANSACTION_CONFLICT`。其他事务失败返回 `TRANSACTION_FAILED`，连接失败返回 `DATABASE_UNAVAILABLE`，数值超限返回 `INVALID_INPUT`。

## 集成验证

在仓库根目录使用本次部署生成的配置运行回归。**测试会写入配置指向的数据库，只能对本次新建的独立样例库运行。**

```bash
export APP_CONFIG_FILE="$(cat output/week7/config-path.txt)"
output/week7/.venv/bin/python tests/Test-Week7-Web.py
```

103 项检查覆盖登录、角色权限、采购入库、订单编辑、支付、出库、库存调整、故障回滚及并发。响应和流程摘要写入 `output/week7/review-evidence.json`。当前代码已通过 [LocalDB 的 103 项回归](../result/week12/README.md)，连接层使用 ODBC 适配。真实 pymssql 与 Gunicorn 的[课程服务器实测](../result/week7/README.md)对应第7–9周版本。

## 页面截图复现

截图使用 Firefox 与 Selenium，属于证据采集依赖，不是 Web 服务启动必需依赖。在服务器安装 Firefox 后，可为本次隔离环境安装截图依赖并运行：

```bash
uv pip install --python output/week7/.venv/bin/python -r tests/requirements-screenshots.txt
export APP_CONFIG_FILE="$(cat output/week7/config-path.txt)"
export APP_BASE_URL="http://127.0.0.1:${APP_PORT:-8767}"
output/week7/.venv/bin/python tests/Capture-Week7-Ui.py
```

脚本在服务器本地读取私有演示身份，默认写入被忽略的 `output/week7/screenshots/`。如果 Firefox 位于非标准路径，可通过 `FIREFOX_BINARY` 指定。发布前逐张检查页面可见内容和元数据；不要复制演示口令或私有配置。

### 第7至9周历史三角色复验

[三角色脚本](../tests/Capture-Week7-Server-Flow.py)按第10周会员优惠上线前的金额 7.50 元断言。复现历史 21 项浏览器流程时，使用[当时的代码版本](https://github.com/IMWLGDHGNC/DataBaseLab/commit/7ea2c31)及该版本新建的独立样例库。原始 8 张服务器截图和逐项摘要见[第7–9周结果](../result/week7/README.md)。
