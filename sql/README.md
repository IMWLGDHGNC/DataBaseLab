# SQL 导航

本目录是课程要求的可执行 SQL 交付。当前 main 的 v0.1 由 `week3/` 和 `week4/` 组成；推荐使用 [Run-Week4.ps1](../scripts/Run-Week4.ps1)按顺序执行，完整命令与预期结果见[根 README](../README.md)。

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

## v0.1 执行链路

```text
00-create-database（在 master 中）
→ 01-schema → 02-seed → 04-verify
→ 03-crud → 04-verify
→ constraint → 05-constraint-tests
→ query → view → role
→ 04-verify
```

其余 SQL 在本次目标库执行。建表与样例脚本要求空库；视图和角色脚本可在已有第四周库重复执行。Linux 服务器的建库方式与 sqlcmd 参数见[服务器环境](../docs/服务器SQL环境.md)。

15 张表是业务模型；`customer_security.CustomerPrincipal` 是权限辅助表，单独计数。测试用户使用 WITHOUT LOGIN，证明授予范围内的允许/拒绝，应用认证与完整跨表业务事务仍按后续课程阶段实现。

## 第五周模型验证

第五周包含 [week5/verify-er.sql](week5/verify-er.sql)：逐项核对业务 ER 字段、主码、候选码、外码及过滤唯一索引，并执行 9 项回滚探针，定位现有约束边界。该周已按用户授权修复 review 问题并合入 main，设计与执行说明见 [Week5](../docs/Week5.md)，图源、规则和问题清单见 [docs/week5](../docs/week5/er-model.md)。

课程指定的 `query.sql`、`view.sql`、`constraint.sql`、`role.sql` 保留在 `week4/`，对应要求见[第四周任务讲解](../docs/第四周任务讲解.md)。
