# SQL 导航

本目录保存 v0.1 原型、v1.0 应用基线及 v2.0 第10至13周的 SQL。当前 Web 安装流程加载第10至12周目录的对象，订单和采购过程已包含第13周的并发改进。Linux 部署见[应用手册](../app/README.md)，Windows 专项复现见[LocalDB 指南](../docs/guides/本地SQL环境.md)。

## 文件用途

| 阶段 | SQL 文件 | 做什么 |
| --- | --- | --- |
| 本地环境 | [00-verify-environment.sql](00-verify-environment.sql) | 创建/验证环境用 `DataBaseLab` 数据库及 SQL Server 配置；由初始化脚本调用 |
| 第三周建库 | [00-create-database.sql](week3/00-create-database.sql) | 为 Windows LocalDB 创建实验库；执行器按校验后的参数替换目标库名 |
| 第三周建表 | [01-schema.sql](week3/01-schema.sql) | 15 张业务表、字段、主外码、唯一性及基础完整性约束 |
| 第三周样例 | [02-seed.sql](week3/02-seed.sql) | 装入 46 行互相关联的模拟业务数据 |
| 第三周 CRUD | [03-crud.sql](week3/03-crud.sql) | 商品、库存、订单增删改查；教学写入回滚 |
| 数据复核 | [04-verify.sql](week3/04-verify.sql) | 样例数量、业务一致性和逐表摘要；在多个阶段前后调用 |
| 第三周反例 | [05-constraint-tests.sql](week3/05-constraint-tests.sql) | 12 项非法数据被实际约束拒绝的验证 |
| 第四周查询 | [query.sql](week4/query.sql) | 多表连接、聚合、子查询、已完成销售及库存查询 |
| 第四周视图 | [view.sql](week4/view.sql) | 创建并核对订单详情、商品销量和库存状态三个视图 |
| 第四周约束 | [constraint.sql](week4/constraint.sql) | 异常解决说明 CHECK 与 6 项合法/非法写入验证 |
| 第四周权限 | [role.sql](week4/role.sql) | 六类最小权限角色、本人订单/积分过程、辅助身份映射及 34 项权限正反例 |

## 从空库安装当前 Web 应用

[Run-Week7-Server.sh](../scripts/Run-Week7-Server.sh) 先运行第六周脚本准备 v1.0 基线，然后安装应用登录和第7周授权。接着加载第10周迁移、函数、过程与授权，第11周触发器，以及第12周分类递归、入库过程和收货权限。

`week11/window_query.sql` 用于窗口查询演示。`week12/test_data.sql` 和 `week12/order_transaction.sql` 用于隔离实验，安装脚本只加载当前应用所需对象。

## v0.1 与 v1.0 基线执行顺序

```text
00-create-database（在 master 中）
→ 01-schema → 02-seed → 04-verify
→ 03-crud → 04-verify
→ constraint → 05-constraint-tests
→ query → view → role
→ 04-verify
```

以上是v0.1基线顺序。随后执行 `week5/verify-er.sql` → `week6/migration.sql` → `week4/role.sql` → `week6/regression.sql`；Web部署再创建应用登录并应用 `week7/permissions.sql`。部署脚本封装上述顺序。

其余 SQL 在本次目标库执行。建表与样例脚本要求空库；视图和角色脚本可在已有第四周库重复执行。Linux 服务器的建库方式与 sqlcmd 参数见[服务器环境](../docs/guides/服务器SQL环境.md)。

15 张表是业务模型；`customer_security.CustomerPrincipal` 是权限辅助表，单独计数。v0.1角色脚本使用WITHOUT LOGIN测试用户核对授权正反例；v1.0的应用认证与跨表业务事务已由[第7–9周Web应用](../docs/week7-9/README.md)实现。

## 第五周模型验证

第五周包含 [week5/verify-er.sql](week5/verify-er.sql)：逐项核对业务 ER 字段、主码、候选码、外码及过滤唯一索引，并执行 9 项回滚探针，定位现有约束边界。该周已按用户授权修复 review 问题并合入 main，设计与执行说明见 [Week5](../docs/week5/README.md)，图源、规则和问题清单见 [docs/week5](../docs/week5/er-model.md)。

课程指定的 `query.sql`、`view.sql`、`constraint.sql`、`role.sql` 保留在 `week4/`，对应要求见[第四周任务讲解](../docs/course/第四周任务讲解.md)。

## 第六周 v1.0 迁移

[week6/migration.sql](week6/migration.sql)仅对新的 `DataBaseLab_Week6_<时间戳>` 样例库执行：核对 v0.1 前提后，在事务中保存业务查询基线、删除 `InventoryMovement.PurchaseItemID` 及相关约束，逐行比较迁移前后库存流水与采购来源。[week6/regression.sql](week6/regression.sql)核对四组实际查询与本库迁移前快照、15 表 46 行、目标目录 106 属性/23 外键/9 项 UNIQUE、业务对账、四种合法流水和十一项命中重建 CHECK 的负例及角色边界。`week6_baseline` 的五张辅助审核表不计入业务表；快照无顾客读取权限，当前日期库存视图要求迁移和回归同日执行。第五周 `verify-er.sql` 和第三周 `04-verify.sql` 必须在迁移前运行；迁移后不再适用 v0.1 字段和全库表数检查。具体顺序及版本对应结果见[Week6](../docs/week6/README.md)和[结果](../result/week6/README.md)。

## 第七至九周 Web 授权

第7–9周授权为管理员采购建单与审批、店员验收入库配置了基础表级和列级权限。当前部署继续应用第10、12周授权，将订单完成、盘点和验收入库所需的直接写入权限收回，由相应过程执行。所有业务写入先获取同一事务级应用锁。

[week7/permissions.sql](week7/permissions.sql)在第六周独立 v1.0 样例库中创建顾客、店员、管理员三个应用数据库角色，给新建的随机 SQL 登录授予所需表级及列级操作，最后确认登录未进入 `db_owner` 等宽权限角色。该脚本的登录占位符由[部署脚本](../scripts/Run-Week7-Server.sh)在服务器私下替换，不能直接把占位符原样运行。顾客“仅本人”行级限制在 Web 服务层，数据库端目前是表级授权；边界见 [第7–9周](../docs/week7-9/README.md)。

## 第10周 过程、函数与应用集成

v1.0之后执行 [week10/migration.sql](week10/migration.sql) → [function.sql](week10/function.sql) → [procedure.sql](week10/procedure.sql)；第7周授权后执行 [permissions.sql](week10/permissions.sql)。迁移只运行一次，程序对象可重装。[调用示例](week10/call_examples.sql)与[本周说明](../docs/week10/README.md)定义含首尾日的销售口径、批次调整、会员折扣快照、补货选择和订单完成；[87项结果](../result/week10/README.md)包含异常和回滚证据。

## 第11周 触发器与窗口查询

第10周之后执行 [week11/trigger.sql](week11/trigger.sql)，新增库存审计辅助表与两项集合触发器，可重复安装且保留审计数据。[window_query.sql](week11/window_query.sql)提供商品收入排名、逐订单累计收入及最近三笔订单均额。批量正反例与独立计算见[本周说明](../docs/week11/README.md)、[72项结果](../result/week11/README.md)。

## 第12周 递归查询与业务事务

升级已安装第10、11周的数据库时，重装 [week10/procedure.sql](week10/procedure.sql)，再执行 [recursive_query.sql](week12/recursive_query.sql) → [restock_transaction.sql](week12/restock_transaction.sql) → [permissions.sql](week12/permissions.sql)。此前需有第10周创建的应用角色；已有 Web 授权环境最后应用第12周授权。第12周安装可重复执行。新建 Web 样例库时部署脚本会依次安装。

[test_data.sql](week12/test_data.sql)仅在新建的实验副本运行，准备分类树、P/Q库存、待出库订单和待验收采购单。[order_transaction.sql](week12/order_transaction.sql)调用订单完成过程并核对出库结果。补货调用示例见过程文件底部。自动提交、回滚和重复调用验证见[第12周说明](../docs/week12/README.md)。

## 第13周 并发控制

新库按现有顺序安装。已安装前一版第12周对象的库先重装 [procedure.sql](week10/procedure.sql)，再重装 [restock_transaction.sql](week12/restock_transaction.sql)。两个过程先获取商品键，订单完成按商品和批次编号依序更新。原有事务级应用锁和应用授权继续生效。

专用样例库按 [第13周 A/B 操作表](../docs/week13/README.md#手工重放库存锁实验)运行 [初始化](week13/setup.sql)、各场景 A/B SQL、[锁观察](week13/observe.sql)、[状态查询](week13/state.sql)和[清理](week13/cleanup.sql)。`business_*` 脚本调用实际订单和采购过程。[第三阶段复现](../docs/guides/本地SQL环境.md#第13周与第三阶段复现)提供统一执行入口。
