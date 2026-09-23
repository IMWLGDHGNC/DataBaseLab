# Week4 - 连接查询、统计视图、约束与角色权限

依据[第四周任务讲解](第四周任务讲解.md)，在第三周 15 表、46 行样例数据上完成四类 SQL 交付，并把第一阶段 v0.1 从空库复现串成一个命令。业务场景、岗位及流程分别见 [Week1](Week1.md) 与 [Week2](Week2.md)。

## 交付与执行顺序

| 文件 | 内容 |
| --- | --- |
| [query.sql](../sql/week4/query.sql) | 订单明细多表连接、已完成商品销量与销售额、会员消费、HAVING 与子查询、批次可售量 |
| [view.sql](../sql/week4/view.sql) | 订单详情、商品已完成销售统计、当前批次库存状态三个视图 |
| [constraint.sql](../sql/week4/constraint.sql) | 新增异常解决说明 CHECK，验证合法更新、FK、UNIQUE、NOT NULL、DEFAULT 和 CHECK |
| [role.sql](../sql/week4/role.sql) | 店长、采购员、库存管理员、订单管理员四个数据库角色；无登录测试用户及正反例 |
| [Run-Week4.ps1](../scripts/Run-Week4.ps1) | 从空库顺序执行第三周建库、建表、装载、CRUD、验证和本周脚本 |

在 Windows PowerShell、仓库根目录运行：

```powershell
powershell.exe -NoProfile -File .\scripts\Run-Week4.ps1
```

默认目标为 `DataBaseLab_Week4`，使用本机 `(localdb)\DataBaseLab`。如果该库已有业务表，运行会拒绝重建；可换一个新名字：

```powershell
$db = 'DataBaseLab_Week4_' + (Get-Date -Format 'yyyyMMddHHmmss')
powershell.exe -NoProfile -File .\scripts\Run-Week4.ps1 -Database $db
```

详细顺序：在 `master` 运行第三周建库 SQL（仅替换经过校验的数据库名）；在目标库运行 `01-schema.sql → 02-seed.sql → 04-verify.sql → 03-crud.sql → 04-verify.sql → constraint.sql → 05-constraint-tests.sql → query.sql → view.sql → role.sql → 04-verify.sql`。第三周 CRUD 和本周合法写入、角色写入测试均回滚，不更改 46 行样例。重复执行本周建视图、角色脚本会因对象已存在而失败；完整复现应使用新空库。

## 查询口径与样例核对

销售额使用 `SalesOrderItem.DealUnitPrice` 的历史成交价，且只统计 `已完成` 订单；`ST02` 已支付但仍待出库，不计为已完成销售。订单详情使用 `LEFT JOIN` 以保留尚无明细的订单；商品销量统计从商品表出发以保留零销量商品。当前库存视图按运行当天判断到期；`query.sql` 的演示库存查询固定在 `2026-09-18`，便于复现历史案例。

| 核对项 | 结果 |
| --- | ---: |
| 已完成订单件数 | 15 |
| 已完成订单销售额 | 64.50 元 |
| 待出库订单 | 1 |
| 订单详情视图行数 | 4 |
| 到期批次 B01 的可售量 | 0 |

## 完整性和权限

第三周已在数据库中实现主码、外码、候选码唯一性、非空、默认值和多项检查约束。本周增加 `CK_OrderException_ResolutionNote`：异常标为“已解决”时必须填写非空处理说明。`constraint.sql` 的六例包括两项成功写入和四项应失败的写入，按 SQL Server 错误号判定；每个写入案例都在独立事务中执行并回滚，即使预期失败的操作意外成功，也不会污染后续样例。第三周原有 12 项非法数据测试仍执行。

角色授权采取表/列和视图级别：店长可看经营视图并调整商品价格、状态和预警值；采购员可看采购资料并维护供应商联系信息；库存管理员可看库存并切换批次质量状态；订单管理员可看订单，并同时维护异常状态和处理说明。没有授予任何角色 `db_owner`、`db_datawriter`、直接修改库存数量、积分余额或支付结果的权限。`role.sql` 使用 `WITHOUT LOGIN` 用户验证 17 个正反例：整表无权返回 229、同表未授权列返回 230、违反检查约束返回 547；所有允许或意外允许的写入均在事务中回滚。这些测试用户用于实验，不可作为实际登录账号。

这些授权覆盖本阶段直接展示的安全操作。采购审批、创建整单订单、出入库与支付等多表原子操作需要受控存储过程或应用事务；本周没有提供可直接执行这些完整业务流程的低权限入口，也不把单表授权说成完整业务授权。订单总额与明细、库存余额与流水等跨表规则仍由受控脚本和 `04-verify.sql` 校验，尚未全部通过数据库约束自动拦截任意写入。

## 实际运行

2026-09-23 在 SQL Server 2022 LocalDB 上，两个独立空库均得到 `WEEK4_PASS`；初版日志包含 13 项角色正反例。补强失败用例事务隔离和异常解决权限后，又在课程服务器 SQL Server 2022 的独立临时库完整执行，得到 15 表、46 行、`CRUD_PASS`、六项本周约束用例、12 项第三周非法数据用例、`QUERY_PASS`、`VIEW_PASS` 和 17 项角色正反例。合并推送后，同一实现正式部署为服务器数据库 `DataBaseLab_Week4`，再次得到全部通过标记，并独立复核 3 个视图、4 个角色和已启用且可信的新增检查约束。完整输出见 [首次运行](../result/week4-run.txt)、[第二次复现](../result/week4-reproduction.txt)、[服务器合并前验证](../result/week4-server-preflight.txt)与[服务器正式部署](../result/week4-server-deploy.txt)。[结果目录](../result/README.md)还包含从实际日志截取并在浏览器呈现的图片；图片是日志呈现截图，不是 SSMS 界面截图。

本周新增 SQL 仍需组员逐句人工复核。组员姓名、实际分工和人工意见遵照当前要求暂不填写，不把自动验证记作人工验收。
