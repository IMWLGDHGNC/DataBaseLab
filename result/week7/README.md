# 第 7–9 周 Web 应用运行结果

## 最新课程服务器复验：2026-10-14

从最新 `main` 提交 `7ea2c31` 在课程服务器另建独立样例库，完整执行第六周建库、迁移和回归，得到 `W6_REGRESSION_PASS 15 46 15 64.50`、`WEEK6_SERVER_PASS`；新建三类受限登录和应用配置，得到 `WEEK7_LOGINS_PASS`、`WEEK7_PERMISSIONS_PASS`、`WEEK7_DEPLOY_PREP_PASS`。旧部署和正式演示库未修改。

修复版在 Linux、真实 pymssql、SQL Server 2022 容器和 Gunicorn 下运行 [103 项集成检查](server-validation-20261014.txt)，结果为 `WEEK7_WEB_PASS 103`。[安全流程摘要](server-review-evidence-20261014.json)保留自动测试中的模拟编号、金额、回滚及错误响应。另用 Firefox 页面逐步操作管理员、店员和顾客，得到 [21 项三角色核对](server-flow-summary-20261014.json)与 `WEEK7_SERVER_FLOW_PASS 21`：管理员建商品并审批 10 件采购，店员验收入库，顾客遇到缺货提示后下单、修改为 3 件、模拟支付，店员确认出库。最终该批次现存 7、有效锁定 0、订单金额 7.50 元、会员增加 7 分，成功支付及出库流水各 1 条。店员改商品、顾客查库存和重复支付均被后端拒绝。

| 服务器页面截图 | 核对内容 |
| --- | --- |
| [管理员新增商品](server-01-manager-product.png) | 新商品进入目录 |
| [管理员审批采购](server-02-approved-purchase.png) | 单商品采购已批准 |
| [店员验收入库](server-03-staff-received.png) | 批次现存 10 件 |
| [顾客缺货提示](server-04-insufficient-stock.png) | 超额下单收到友好错误 |
| [顾客创建订单](server-05-customer-order.png) | 订单进入待支付 |
| [顾客修改明细](server-06-customer-edited.png) | 数量和金额重算 |
| [顾客支付](server-07-customer-paid.png) | 订单进入待出库 |
| [店员确认出库](server-08-staff-fulfilled.png) | 本次订单已完成，现存 7、锁定 0 |

截图使用模拟身份与模拟收货资料；逐张检查可见内容，PNG 仅有图像常规数据块。私有配置、演示密码和原始异常日志均保留在服务器被忽略的目录。上述是实际运行和自动化页面操作结果，组员逐项人工审核仍待确认。

## 最新 review 修复验证：2026-10-14

修复版在新建独立 SQL Server 2022 LocalDB 样例库中通过 **103 项 Web 集成检查**，并在浏览器完成同一商品、同一订单的管理员采购审批 → 店员验收入库 → 顾客下单/明细修改/支付 → 店员出库。详细环境、六项修复、回滚与并发结果见[验证报告](review-validation-20261014.md)；[安全检查输出](review-validation-20261014.txt)保留实际 PASS；[响应与流程 JSON](review-evidence-20261014.json)记录 49 个后端响应、7 个流程步骤及回滚核对表范围。

| 修复版截图 | 实际结果 |
| --- | --- |
| [管理员采购审批](fix-01-approved-purchase.jpg) | 新商品 FIX20261014 尚无库存，采购 10 件已批准 |
| [后端缺货拒绝](fix-02-backend-input-error.jpg) | 顾客提交超出可售量的订单，页面显示后端库存不足提示 |
| [店员验收入库](fix-03-stock-received.jpg) | 同商品批次现存 10 件，采购与入库流水已更新 |
| [顾客修改同一订单明细](fix-04-order-detail-edited.jpg) | 订单 SO22FB1CE582 数量改为 3，金额 7.50 元 |
| [顾客模拟支付](fix-05-order-paid.jpg) | 同一订单变为待出库 |
| [店员出库及库存余额](fix-06-fulfilled-and-stock.jpg) | 同一订单已完成，现存 7 件、有效锁定 0 |

截图使用模拟身份和收货资料，逐张核对可见内容；六个 JPG 无 EXIF，元数据只有常规 JFIF 信息。此处 103 项结果来自先前独立 LocalDB 和私有 ODBC 适配；上方为随后完成的真实课程服务器复验。正式库未修改，学生逐项人工验收仍待确认。

## 历史服务器部署与 39 项检查

我们在课程服务器已有的 SQL Server 2022 容器上，**另建独立样例库**运行第六周完整建库、迁移和回归，再部署 Web 应用。迁移前样例为 15 张业务表、46 行；迁移后第六周回归给出 `W6_REGRESSION_PASS 15 46 15 64.50` 和 `WEEK6_SERVER_PASS`。随后部署检查给出 `WEEK7_LOGINS_PASS`、`WEEK7_PERMISSIONS_PASS`、`WEEK7_DEPLOY_PREP_PASS`。正式演示库未迁移。

Web 服务运行于服务器环回地址。首页和商品 API 均返回 HTTP 200；HTTP 到真实 SQL Server 的[集成测试记录](integration-20261014.txt)有 39 项通过，覆盖三种角色、明细变更、支付、出库、库存、约束、失败回滚、并发争抢和数据库不可用提示。测试会写入独立样例库，因此测试后的行数不应再拿来当 46 行初始基线。

## 历史服务器页面证据

| 截图 | 说明 |
| --- | --- |
| [公开商品与登录页](01-public-products.png) | 未登录时可浏览商品，库存和订单需登录 |
| [顾客订单](02-customer-orders.png) | 顾客账号的商品、下单和本人订单界面 |
| [店员库存](03-staff-inventory.png) | 批次现存、有效锁定、可用量与盘点入口 |
| [管理员商品](04-manager-products.png) | 商品维护和管理视角 |
| [输入错误提示](05-friendly-input-error.png) | 页面显示业务错误，不展示 SQL 或堆栈 |

截图由实际运行的页面生成，使用虚构样例和演示身份；公开副本已检查可见内容。演示密码、私有配置和含内部堆栈的原始日志仅保留在服务器私有目录，不在本仓库发布。这里记录的是程序运行和自动验证结果；尚未据此声称组员逐项人工验收完成。
