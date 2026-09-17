# 本地 SQL Server 环境

使用 SQL Server 2022 Express LocalDB，实例名为 `DataBaseLab`，数据库名为 `DataBaseLab`，通过 Windows 身份验证连接。LocalDB 适合本机开发实验；远程组员连接和完整服务器管理实验需另行配置 SQL Server 服务实例。参见 [Microsoft LocalDB 文档](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/sql-server-express-localdb?view=sql-server-ver17)。

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

## 当前验证状态

2026-09-17：用户手动安装后，已检测到 SQL Server 2022 LocalDB `16.0.1000.6`，创建并启动 `DataBaseLab` 实例和同名数据库。通过 Windows 身份验证执行环境验证 SQL，返回 `EnvironmentSmokeTest = PASS`；临时表建表、插入、查询与事务回滚执行成功，0.50 元和 1.00 元的积分计算分别返回 0 和 1。修复了 Windows PowerShell 对连接字符串构造器属性赋值的兼容问题，改为使用标准连接字符串键。

上述环境脚本仅验证连接和基本 SQL 能力。第三周已另在 `DataBaseLab_Week3` 数据库实现 15 张业务表，具体脚本与结果见 [Week3.md](Week3.md)。无需重复安装；上述初始化脚本可以再次运行，保留已有实例和数据库。
