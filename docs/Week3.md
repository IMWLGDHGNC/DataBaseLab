# Week3 - 线上零食网店建库与增删改查

根据[第三周任务讲解](第三周任务讲解.md)，本周已将[第二周关系模式](Week2.md)实现为 SQL Server 的 15 张业务表、107 个字段和 46 行关联样例数据。商品、库存、订单的 CRUD 已实际执行，两次独立空库复现、数据核对及 12 项非法数据测试均通过。

## 1. 交付清单

| 课程要求 | 对应文件 | 实现内容 |
| --- | --- | --- |
| 建库 | [00-create-database.sql](../sql/week3/00-create-database.sql) | 默认创建 `DataBaseLab_Week3`，显式指定实例目录中的唯一物理文件名 |
| 建表和数据类型 | [01-schema.sql](../sql/week3/01-schema.sql) | 15 张表，字段含义注释、PK、UNIQUE、FK、NOT NULL、DEFAULT、CHECK |
| 样例数据 | [02-seed.sql](../sql/week3/02-seed.sql) | 第二周全部 46 行样例，按父表到子表的顺序插入 |
| 增删改查 | [03-crud.sql](../sql/week3/03-crud.sql) | 商品、批次库存、销售订单三组操作及前后查询 |
| 样例一致性检查 | [04-verify.sql](../sql/week3/04-verify.sql) | 数量、金额、库存、锁定、支付、积分、时间及逐表数据哈希 |
| 约束验证 | [05-constraint-tests.sql](../sql/week3/05-constraint-tests.sql) | 12 项应失败的写操作，核对 SQL Server 错误编号 |
| 一次执行 | [Run-Week3.ps1](../scripts/Run-Week3.ps1) | 按顺序建库、建表、装载、验证、CRUD、复查和约束测试 |
| 独立空库复现 | [Test-Week3Reproduction.ps1](../scripts/Test-Week3Reproduction.ps1) | 创建两个新数据库，比对表结构与数据，并保存执行日志 |

本周使用本地实例 `(localdb)\DataBaseLab`，Windows 身份验证，SQL Server 2022 LocalDB `16.0.1000.6`。`DataBaseLab` 是原环境验证数据库，`DataBaseLab_Week3` 是本周业务数据库，二者用途不同。

2026-09-21，`DataBaseLab_Week3` 另行部署到课程服务器的 SQL Server 2022 CU27 容器，并在容器重启后通过 15 表、46 行数据复验。共享连接、运维命令和 Linux 容器导入差异见[服务器 SQL Server 环境](服务器SQL环境.md)。

## 2. 表结构和约束

沿用第二周全部表名、字段名、长度、精度、可空性和默认值，未新增业务字段。`VARCHAR` 用于 ASCII 编号和电话，`NVARCHAR` 用于中文文字，`DECIMAL(10,2)` 用于金额，`INT` 用于数量与积分，`BIT` 表示会员身份，`DATE` 和 `DATETIME2(0)` 保存日期及秒精度时间。字符长度应理解为 SQL Server 类型的存储单位：`VARCHAR(n)` 的 n 为字节数，`NVARCHAR(n)` 的 n 为双字节单位数。

非空标识和必填文字还检查去除首尾空格后长度大于零；金额为正、数量不为负、枚举状态、生产与到期时间关系等由 CHECK 保证。未设置默认值的可空字段省略时自然得到 NULL。销售单位中的“包、瓶、袋”是示例，允许其他非空单位，不将其误设为封闭枚举。

主外键默认不级联删除。已被历史业务引用的商品等记录不能直接删除，仍按第一周约定使用停售或停用状态维护。

本周补充两组支持复合外键的 UNIQUE 超码：

- `InventoryBatch(BatchID, PurchaseItemID)`，使入库流水的批次与采购明细必须配套；即使商品相同，也不能错引另一采购来源。
- `SalesOrder(SalesOrderID, CustomerID)`，使积分流水的受益顾客必须属于该订单。

这些组合包含原有主码，是实现复合外键需要的超码，不是新的最小候选码。`PaymentRecord` 另有仅针对“成功”记录的过滤唯一索引，保证每单至多一笔成功支付，同时允许保存失败记录。积分流水要求实付至少 1 元，积分等于金额向下取整；不足 1 元时不插入积分流水。

## 3. 从空数据库复现

先在仓库根目录打开普通 Windows PowerShell，使用已安装 LocalDB 的当前 Windows 用户。若当前终端尚无实例，先运行：

```powershell
powershell.exe -NoProfile -File .\scripts\Initialize-LocalDB.ps1
```

本机的 `DataBaseLab_Week3` 已完成装载。要现场演示从空库开始，使用新的数据库名，下面命令可以直接运行：

```powershell
$week3Database = 'DataBaseLab_Week3_' + (Get-Date -Format 'yyyyMMddHHmmss')
powershell.exe -NoProfile -File .\scripts\Run-Week3.ps1 -Database $week3Database
```

新机器首次构建也可以不传 `-Database`，默认使用 `DataBaseLab_Week3`。脚本不删除数据库；指定数据库已有用户表时拒绝建表。若之前建表或装载中断，先检查错误，需完整重演时换用新的数据库名，勿直接删除不明来源的数据。

执行顺序为 `00 → 01 → 02 → 04 → 03 → 04 → 05`。`00` 在 master 中执行，其余脚本在目标业务库中执行。PowerShell 执行器负责连接数据库；SQL 文件本身不硬编码 `USE`。在 SSMS 中手工执行时，也须先选择 master 执行建库脚本，再切换到新业务库。

各阶段的成功标记为 `VERIFY_PASS`、`CRUD_PASS`、`CONSTRAINT_TESTS_PASS`，最后为 `WEEK3_PASS`。不能只根据最后一次 SELECT 有输出就判断成功；执行遇到异常会停止。

建表和样例装载分别使用事务；第二次执行建表会因非空库被拒绝，第二次装载会因主码重复而回滚，不采取静默跳过或覆盖。CRUD 和非法数据测试只在事务内操作测试记录，结束时回滚，保留初始样例。

## 4. 现场演示 CRUD

在已有的本周业务库直接执行，无需重新建表：

```powershell
powershell.exe -NoProfile -File .\scripts\Invoke-LabSql.ps1 -Database DataBaseLab_Week3 -InputFile .\sql\week3\03-crud.sql
```

以下为实际执行结果摘要，完整前后查询见[运行日志 1](verification/week3-run-1.txt)。

| 对象 | 操作前 | INSERT 与 SELECT | UPDATE 后 | DELETE 后 |
| --- | --- | --- | --- | --- |
| 商品 `W3_PRODUCT` | 0 行 | 售价 3.00，默认在售、预警值 0 | 售价 3.50 | 0 行 |
| 库存 `W3_BATCH` | 0 行 | 采购入库 20，现存 20 | 报损 2，现存 18；流水合计 18 | 0 行 |
| 订单 `W3_ORDER` | 0 行 | 待支付，金额 4.40，地址 A；明细与批次锁定同时建立 | 地址 B，金额和状态保持不变 | 0 行 |

每条 UPDATE/DELETE 前均用相同 WHERE 条件查询目标。库存演示同时建立采购来源及流水，不把账面库存无理由改小；订单演示同时建立明细和锁定，删除时先清理子表。所有被删记录都由本次教学事务创建，真实历史订单和库存流水不能套用这个删除流程。

演示使用固定业务时间 `2026-09-17`，库存可售量检查使用 `2026-09-18`，以保证今后运行也得到相同历史场景，而非随电脑日期变化。完成整组演示后回滚，并再次验证 46 行样例数据。

## 5. 实际验证结果

验证日期：2026-09-17。两次完整构建记录保存在[运行日志 1](verification/week3-run-1.txt)、[运行日志 2](verification/week3-run-2.txt)；[复现比对结果](verification/week3-reproduction.txt)记录了数据库名称及每张表的 SHA-256 数据哈希。

| 检查项目 | 结果 |
| --- | --- |
| DOCX 所有非空段落、表格单元格文字在 Markdown 中保留 | 通过 |
| 实际 107 字段的类型、长度、精度、空值、默认值与第二周字典一致 | 通过 |
| 实际 46 行样例逐字段与第二周元组一致 | 通过 |
| 两个空库的列、默认值、CHECK、FK、索引与主候选码结构一致 | 通过 |
| 两个空库的 15 张表数据哈希一致 | 通过 |
| 商品、库存、订单三组 CRUD | 通过 |
| 库存流水、锁定量、订单金额、支付、积分及时间等快照检查 | 通过 |
| 12 项非法写入的实际错误编号与预期一致 | 12/12 通过 |
| 重复建表、重复装载被拒绝且不覆盖原数据 | 通过，见[重复执行检查](verification/week3-repeat-guards.txt) |

非法数据测试包含负售价、缺失类别外键、重复候选码、必填名称为 NULL、负库存、非法批次日期、完成订单缺少完成时间、重复成功支付、零积分、错误受益顾客、同商品错误采购来源及删除被引用商品。

样例库存验证输出为：

| 批次 | 现存 | 有效锁定 | 2026-09-18 可售量 |
| --- | ---: | ---: | ---: |
| B00 | 290 | 0 | 290 |
| B01 | 37 | 2 | 0 |
| B02 | 498 | 0 | 498 |

若需要再次验证两次独立空库复现，可直接运行：

```powershell
powershell.exe -NoProfile -File .\scripts\Test-Week3Reproduction.ps1
```

该脚本每次创建两个名称不同的新数据库，并保留供检查；会更新 `docs/verification` 下的两份运行日志与比对记录，不会清空原数据库。

## 6. 本周边界和人工复核

本周实现 DDL、关联样例数据和基础 CRUD。订单总额等于明细合计、库存现存量等于流水、锁定商品一致、整单锁定、角色职责和历史状态迁移等跨表或跨时规则，目前通过本周受控脚本与验证查询检查，**并非全部由数据库自动拦截任意写操作**。完整业务入口、并发支付/出库事务、权限隔离及更多异常场景留待后续实验；本周不声称已完成可上线的订单系统。

第二周已完成人工复核，但本周新增 SQL 的逐句人工检查、现场讲解以及实际组员分工仍需小组完成。AI 实际修改和执行记录见 [AI 使用记录](AI使用记录.md)，不将自动验证记作人工验收。
