# 本地 SQL Server 环境

使用 SQL Server 2022 Express LocalDB，实例名为 `DataBaseLab`，数据库名为 `DataBaseLab`，通过 Windows 身份验证连接。LocalDB 适合本机开发实验；已部署的共享 SQL Server 2022 容器及 SSH 隧道连接方式见[服务器 SQL Server 环境](服务器SQL环境.md)。参见 [Microsoft LocalDB 文档](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/sql-server-express-localdb?view=sql-server-ver17)。

## 安装

在仓库根目录打开**管理员 Windows PowerShell**（以当前 Windows 账户提权），执行：

```powershell
powershell.exe -NoProfile -File .\scripts\Setup-LocalDB.ps1
```

脚本从 Microsoft 下载 LocalDB MSI 并检查签名，安装时接受 SQL Server LocalDB 许可条款。日志保存在 `%LOCALAPPDATA%\DataBaseLab\setup\localdb-install.log`。如提示重启，重启后继续。

在仓库根目录打开当前用户的**普通 Windows PowerShell**，执行：

```powershell
powershell.exe -NoProfile -File .\scripts\Initialize-LocalDB.ps1
```

此步骤创建并启动 `(localdb)\DataBaseLab` 实例，创建不存在的 `DataBaseLab` 数据库，并执行环境验证 SQL。验证使用临时表及事务回滚，不创建业务表；最后应输出 `EnvironmentSmokeTest = PASS`。

新数据库显式使用当前实例 `master` 文件所在目录，物理文件名附带唯一后缀，避免不同实例在用户目录争用 `DataBaseLab.mdf`。已有同名数据库会复用，不移动文件；遗留的 MDF/LDF 不会被删除、覆盖或自动附加。验证输出会列出实际数据库文件路径。

## 连接与执行 SQL

- 服务器：`(localdb)\DataBaseLab`
- 身份验证：Windows Authentication
- 数据库：`DataBaseLab`

可在已安装的 SSMS 中使用以上连接信息；本脚本不安装 SSMS。也可直接使用 Windows PowerShell 执行 UTF-8 SQL 文件，无需安装 sqlcmd：

```powershell
powershell.exe -NoProfile -File .\scripts\Invoke-LabSql.ps1 -InputFile .\sql\00-verify-environment.sql
```

执行器支持独占一行的 `GO` 分隔符，不支持 sqlcmd 指令或 `GO` 重复次数。SQL 文件本身应负责业务事务与回滚。数据库文件由 LocalDB 管理，不放入 Git 仓库。

## 终端提示实例不存在

LocalDB 实例属于创建它的 Windows 用户。若当前终端提示“指定的 LocalDB 实例不存在”，请直接在出现错误的同一个终端中运行：

```powershell
powershell.exe -NoProfile -File .\scripts\Initialize-LocalDB.ps1
```

初始化会检查当前用户可见的实例，必要时创建实例和数据库，并自动执行真实存在的 `sql\00-verify-environment.sql`。无需自行替换文件名。示意名称“你的脚本.sql”不是仓库里的文件，不能原样执行。

SQL 执行器会先检查输入文件，再检查当前用户能否找到实例，并启动已有实例。另一终端验证成功不代表当前终端也能访问同一实例；若初始化后仍失败，请保留初始化的完整错误输出进一步检查运行账户及环境。

## LocalDB初始化的历史验证

2026-09-17：用户手动安装后，已检测到 SQL Server 2022 LocalDB `16.0.1000.6`，创建并启动 `DataBaseLab` 实例和同名数据库。通过 Windows 身份验证执行环境验证 SQL，返回 `EnvironmentSmokeTest = PASS`；临时表建表、插入、查询与事务回滚执行成功，0.50 元和 1.00 元的积分计算分别返回 0 和 1。修复了 Windows PowerShell 对连接字符串构造器属性赋值的兼容问题，改为使用标准连接字符串键。

上述环境脚本仅验证连接和基本 SQL 能力。第三周已另在 `DataBaseLab_Week3` 数据库实现 15 张业务表，具体脚本与结果见 [Week3.md](../week3/README.md)。无需重复安装；上述初始化脚本可以再次运行，保留已有实例和数据库。

## v1.0 数据库复现

初始化LocalDB后，在仓库根目录运行：

```powershell
powershell.exe -NoProfile -File .\scripts\Run-Week6.ps1
```

脚本自动选择新的独立数据库，按顺序重建v0.1样例、核对第五周ER、迁移为v1.0并执行回归。预期最后输出 `W6_REGRESSION_PASS 15 46 15 64.50` 和 `WEEK6_PASS`。迁移、回归须在同一天执行；完整SQL顺序见[SQL导航](../../sql/README.md)。Web应用的Linux部署、私有配置与三角色操作另见[应用手册](../../app/README.md)。

## 第一阶段 v0.1 空库复现

以下保留第一阶段数据库原型的完整复现与核对步骤，命令均在仓库根目录执行。初始化方法见本页“安装”。

随后运行完整的第四周复现脚本：

```powershell
powershell.exe -NoProfile -File .\scripts\Run-Week4.ps1
```

默认目标数据库为 `DataBaseLab_Week4`。如果该库已经有业务表，脚本不会清空或覆盖它；请为本次运行选择一个新名字。`-Database` 只接受 `DataBaseLab_Week4`，或在其后加下划线、英文字母和数字：

```powershell
$db = 'DataBaseLab_Week4_' + (Get-Date -Format 'yyyyMMddHHmmss')
powershell.exe -NoProfile -File .\scripts\Run-Week4.ps1 -Database $db
```

脚本先创建目标数据库，然后按以下顺序执行仓库中的 SQL：

| 顺序 | 文件 | 用途 |
| ---: | --- | --- |
| 1 | `week3/01-schema.sql`、`02-seed.sql`、`04-verify.sql` | 建立 15 张表、装入 46 行样例并核对 |
| 2 | `week3/03-crud.sql`、`04-verify.sql` | 演示商品、库存、订单 CRUD，回滚后再次核对 |
| 3 | `week4/constraint.sql`、`week3/05-constraint-tests.sql` | 验证新增约束及 12 项非法写入 |
| 4 | `week4/query.sql`、`view.sql`、`role.sql` | 查询、三个视图和六类角色的权限正反例 |
| 5 | `week3/04-verify.sql` | 最后检查业务表和样例数据 |

完整运行后，终端应依次出现 `VERIFY_PASS`、`CRUD_PASS`、`CONSTRAINT_PASS`、`CONSTRAINT_TESTS_PASS`、`QUERY_PASS`、`VIEW_PASS`、`ROLE_PASS`，最后输出 `WEEK4_PASS: <本次数据库名>`。重点核对：

| 检查项 | 预期结果 |
| --- | ---: |
| 业务表及样例数据 | `VERIFY_PASS 15 46` |
| 本周约束案例 | `CONSTRAINT_PASS 6` |
| 第三周非法写入案例 | `CONSTRAINT_TESTS_PASS 12` |
| 角色权限正反例 | `ROLE_PASS 34` |
| 已完成订单商品件数、销售额 | 15 件、64.50 元 |

CRUD、合法约束用例和角色写入测试均在事务中回滚，运行结束后仍应有 46 行样例。已支付但待出库的 `ST02` 不计入完成销售额。`query.sql` 用固定日期演示到期批次，而 `vw_InventoryStatus` 按运行当天判断到期；比较两者结果时要注意日期口径。

### 重跑和排错

- `01-schema.sql` 要求空数据库；`02-seed.sql` 不会覆盖已有样例。完整重跑时请使用新数据库名，不要删除现有数据库。
- 若提示找不到 LocalDB 实例，请在**同一个 Windows 账户和终端**重新运行 `Initialize-LocalDB.ps1`。
- 若中途失败，应查看出错的 SQL 文件、SQL Server 错误号和该次运行的退出状态；不要只根据此前输出过的 `PASS` 判定整轮成功。
- 上述第四周脚本验证数据库原型；第七至九周为采购审批、验收入库、销售下单、模拟支付、确认出库、盘点和赠分实现受控 Web 入口。Web 采购限定单商品整单验收。跨表规则由脚本回归和 Web 集成检查分别核对。
