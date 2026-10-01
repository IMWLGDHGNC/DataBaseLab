# 脚本导航

这里的脚本负责本地环境和 SQL 执行。业务规则实现在 [sql](../sql/README.md)，阶段复现与预期结果以[根 README](../README.md)为准。PowerShell 命令均在仓库根目录运行。

## 选择脚本

| 脚本 | 什么时候用 | 作用与输出 |
| --- | --- | --- |
| [Setup-LocalDB.ps1](Setup-LocalDB.ps1) | 尚未安装 SQL Server 2022 LocalDB | 在管理员 PowerShell 中安装组件，验证安装包的 Microsoft 签名；安装后的用户初始化另行执行 |
| [Initialize-LocalDB.ps1](Initialize-LocalDB.ps1) | 首次使用，或当前 Windows 用户尚无实例 | 创建/启动 `DataBaseLab` 实例，执行环境 SQL；使用将来实际运行实验的 Windows 账户 |
| [Run-Week4.ps1](Run-Week4.ps1) | 完整复现当前 v0.1 | 从空库执行第三、四周 SQL；打印各阶段 PASS 和最终 WEEK4_PASS |
| [Run-Week3.ps1](Run-Week3.ps1) | 单独检查第三周交付 | 建库、建表、样例、CRUD、数据核对及 12 项非法写入案例；最终 WEEK3_PASS |
| [Invoke-LabSql.ps1](Invoke-LabSql.ps1) | 在指定实验库执行一个 SQL 文件 | 使用 LocalDB 集成身份验证，支持独立 GO 分隔符；输出 SQL 返回结果 |
| [Test-Week3Reproduction.ps1](Test-Week3Reproduction.ps1) | 复验第三周两个独立空库的一致性 | 创建并保留两个新实验库，更新 `docs/verification/` 的历史复现文件；执行后检查 Git 差异 |

## 常用入口

已经完成环境初始化时，选择一个新的数据库名并运行：

```powershell
$db = 'DataBaseLab_Week4_' + (Get-Date -Format 'yyyyMMddHHmmss')
powershell.exe -NoProfile -File .\scripts\Run-Week4.ps1 -Database $db
```

执行单个 SQL 文件时，先确认目标库已完成前置建表与样例步骤：

```powershell
powershell.exe -NoProfile -File .\scripts\Invoke-LabSql.ps1 -Database $db -InputFile .\sql\week3\04-verify.sql
```

完整复现需使用空库；建表和样例脚本会拒绝覆盖已有业务数据。默认库名和更完整的顺序见[根 README](../README.md)，环境问题见[本地 SQL 环境](../docs/本地SQL环境.md)。

## 第五周模型验证

第五周提供 [Render-Week5Er.cjs](Render-Week5Er.cjs)，将 Mermaid ER 源导出为 SVG/PNG。其依赖、参数与复验步骤见 [Week5](../docs/Week5.md)；可复现的 [Test-Week5Model.ps1](Test-Week5Model.ps1) 核对 DDL、图源、具体目录定义并执行9项业务探针；[Test-Week5Validation.ps1](Test-Week5Validation.ps1) 在独立测试库中验证5项目录变化和2项图源变化确实被拒绝。

生成日志或图后，按[公开材料规则](../docs/公开材料与敏感信息规则.md)检查实际内容和元数据再提交。
