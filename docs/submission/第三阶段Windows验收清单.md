# 第三阶段 Windows 运行与证据清单

本清单用于第10—13周课程展示和报告取证。只在新建的独立样例库运行；测试会提交模拟订单、采购、库存与审计数据。历史 `result/week10/` 至 `result/week13/` 是旧版本的已保存证据，不能替代本次运行。

## 1. 准备机器与版本

- 使用 Windows、SQL Server 2022 Express LocalDB、Python 3.12、可用的 SQL Server ODBC Driver 17/18、PowerShell。按[本地环境指南](../guides/本地SQL环境.md)安装并以同一 Windows 用户执行 `scripts/Initialize-LocalDB.ps1`。第10/11周 Web 集成测试还需 `app/requirements.txt`；Python 测试需要 `pyodbc`。
- 在仓库根目录记录 `git rev-parse HEAD`、`python --version`、`py -m pip show pyodbc Flask pymssql`、`sqllocaldb info DataBaseLab`。保存版本文字，不把用户目录、连接口令或设备名放入公开结果。
- 建议把完整终端记录留在被 Git 忽略的 `output/third-stage/`；需要上交的日志、截图和 JSON 在人工检查敏感字段后另复制到提交包。

## 2. 新库安装与自动测试

在仓库根目录的普通 PowerShell 执行。`Run-Week10` 创建全新样例库；后续脚本沿用同一个库名。每次从头复跑都换一个新库名。

```powershell
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force output/third-stage | Out-Null
Start-Transcript -Path output/third-stage/windows-run.txt
$env:LAB_TEST_DATABASE = 'DataBaseLab_Week6_Week10' + (Get-Date -Format 'yyyyMMddHHmmss')
./scripts/Run-Week10.ps1 -Database $env:LAB_TEST_DATABASE
./scripts/Run-Week11.ps1 -Database $env:LAB_TEST_DATABASE
./scripts/Run-Week12.ps1 -Database $env:LAB_TEST_DATABASE
python tests/Test-Week10.py
python tests/Test-Week11.py
python tests/Test-Week12.py
python tests/Test-Week13.py
Stop-Transcript
```

先按 `app/requirements.txt` 和 `pyodbc` 安装依赖；缺少依赖时先修复环境，再在**新库**完整重跑。任一步报错即停止，不凭此前某个 PASS 判断整套完成。核对 `WEEK10_PASS 87`、第11周新增完成订单明细保护后的实际通过数、`WEEK12_PASS 23`、`WEEK13_PASS 14`。第11周旧记录为72项，本轮增加了两个错误用例及其无部分写入核对，预计为76项，**以实测输出为准**。测试还会走 Flask 路由及数据库写入；保存 Web 回归最终标记和失败清单。

运行后保存：终端 transcript、`output/week10/` 至 `output/week13/` 中的 checks/会话 JSON、测试失败时的原始错误、数据库名与 Git 提交号。原始日志先留私有目录；公开或上传前按[敏感信息规则](../guides/公开材料与敏感信息规则.md)检查。

## 3. 人工观察与截图

在另一份新建的专用样例库按[第13周 A/B 操作表](../week13/README.md)打开 A、B、观察三个查询窗口，分别记录三个不同的 `@@SPID`。每轮先运行 `setup.sql`，只选中 A1/B1/A2 等指定步骤，不要一次执行整份脚本。截图须同时能辨认轮次、步骤、窗口、等待关系和结果；每轮结束运行 `cleanup.sql` 并核对 `@@TRANCOUNT=0`、`XACT_STATE()=0`。

| 场景 | 当场观察 | 报告中保留的证据 |
| --- | --- | --- |
| 同库存写等待，A 提交／回滚 | B 等待 A 的库存键 X 锁；终态 P 分别为13／15，订单状态不同 | A/B 步骤、DMV 阻塞者和等待者、锁资源与模式、两轮终态 |
| 脏读与已提交读 | 未提交读先见15，A 回滚后为10；已提交读在 RCSI 关闭时等待，开启时读已提交快照 | 隔离级别与 RCSI 值、读值和先后顺序；开启 RCSI 用另一份新库 |
| 不可重复读／可重复读 | 前者同事务两次见10／15；后者 B 等待，A 两次见10 | 两次读值、共享锁与等待状态、B 放行后的终态 |
| 反序死锁与同序访问 | 反序出现 1205 和循环等待；统一 P→Q 后只发生普通等待 | 死锁受害者错误、A/B 各持有与请求的键、回滚和最终 P/Q 数量 |
| 真实订单／补货与两单竞争 | 等待先发生在事务级应用锁；两单各买6件时只有一单完成，库存余4 | 应用锁 DMV、订单和采购终态、库存批次、出库流水、审计及积分 |

## 4. 报告落稿核对

- [第三阶段报告底稿](../reports/第三阶段报告.md)中的每个数字和结论要能对应本次保存的脚本输出或截图；新增“实验总结”，说明已达到的目标、全局应用锁的吞吐取舍，以及直接数据库访问与 Web 本人订单限制的边界。
- 对照[课程清单](../course/第十三周任务讲解.md)检查 README、SQL、结果、报告、组内分工和 AI 记录。实名分工及两人的实际验收记录放在私下提交包，不上传公开仓库。
