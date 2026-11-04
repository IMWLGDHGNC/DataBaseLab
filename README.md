# DataBaseLab：线上零食网店数据库实验

我们以线上零食网店为场景，完成了业务分析、关系模式设计、SQL Server 建库、增删改查、连接查询、视图、完整性约束和角色授权。当前实现包含 v0.1 数据库原型、v1.0 规范化迁移和三角色 Web 应用。迁移前后的初始样例均为 **15 张业务表、46 行业务数据**；后续应用测试会新增业务记录。

## 从这里开始

| 你想了解什么 | 阅读或执行入口 |
| --- | --- |
| 项目做什么、业务范围是什么 | 本页下方的“项目范围、角色与流程” |
| 老师要求什么、每周做了什么 | [文档导航](docs/README.md)：课程原文、各周成果和阶段材料 |
| 在自己电脑上跑起来 | 本页“从空库复现 v0.1”；脚本用途见[脚本导航](scripts/README.md) |
| 在授权服务器上运行第七至九周 Web 应用 | [应用操作手册](app/README.md)与[Week7 设计说明](docs/week7/README.md) |
| 数据库如何实现、SQL 按什么顺序运行 | [SQL 导航](sql/README.md) |
| 查看通过结果和截图 | [结果导航](result/README.md)：先看最新验证，再看历史记录 |
| 核对当前第二阶段提交 | [第5–9周核对清单](docs/submission/第5-9周提交核对.md)、[第二阶段报告](docs/reports/第二阶段报告.md)、[组内分工](docs/submission/组内分工.md) |
| 参与修改和公开上传 | [仓库工作规则](AGENTS.md)、[敏感信息规则](docs/guides/公开材料与敏感信息规则.md) |

**当前阶段：** 仓库保存第一至第四周 v0.1 原型、第五周 ER 模型、第六周 v1.0 迁移，以及第七至九周 Web 应用。服务器原版通过 39 项检查；review 修复版在独立 LocalDB 和课程服务器新样例库各通过 103 项检查，服务器三角色页面流程另通过 21 项核对，见[最新结果](result/week7/README.md)。组员逐项人工验收仍待确认。

## 项目范围、角色与流程

我们将经营范围限定为单店、单仓库、人民币计价的零食网店，记录商品与供应商、采购单及明细、批次库存、销售订单及明细、模拟支付、顾客和会员积分、订单异常。商品浏览点击、真实支付凭据、物流追踪、退货退款及积分兑换暂不进入 v0.1；这些信息尚无完整的业务闭环，提前存入会让状态和金额难以核对。

| 角色 | 本阶段职责 |
| --- | --- |
| 店长 | 查看经营统计，审批采购，维护商品价格和状态 |
| 采购员 | 维护供应商资料，建立采购需求和采购单 |
| 库存管理员 | 验收入库、管理批次质量，复核销售出库 |
| 订单管理员 | 查看订单并登记、处理履约异常 |
| 普通顾客 | 浏览公开商品信息，查看本人订单 |
| 会员 | 具备普通顾客能力，并查看本人积分 |
| 供应商 | 提供采购商品与联系资料；本阶段不设数据库登录角色 |

我们按“补货需求 → 采购单 → 审批验收 → 库存批次及入库流水”记录采购；按“浏览商品 → 下单并锁定批次 → 模拟支付 → 出库复核 → 完成订单 → 会员赠分”记录销售。**锁定只减少可售量，真正出库才减少现存量；已支付也不等于已完成。**支付失败或待支付取消释放锁定；批次到期等异常暂停出库并保留原因。Web 入口提供管理员建立并审批单商品采购、店员整单验收入库及销售流程，详见 [Week7](docs/week7/README.md)。

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| [`sql/week3/`](sql/week3/) | 建库、建表、样例数据、CRUD、数据核对和非法写入测试 |
| [`sql/week4/`](sql/week4/) | 连接与统计查询、三个视图、补充约束和角色授权 |
| [`sql/week5/`](sql/week5/) | ER 模型与数据库目录、边界探针 |
| [`sql/week6/`](sql/week6/) | v1.0 迁移和回归 SQL |
| [`sql/week7/`](sql/week7/) | Web 应用受限数据库角色与授权 |
| [`app/`](app/README.md) | 浏览器页面、路由、业务服务、DAO 和复现手册 |
| [`tests/`](tests/Test-Week7-Web.py) | HTTP 到 SQL Server 的集成验证和页面截图脚本 |
| [`scripts/`](scripts/README.md) | 安装与初始化环境、执行 SQL、一键复现；索引注明各脚本的作用 |
| [`docs/`](docs/README.md) | 课程任务原文、各周说明、阶段报告及环境与公开规则 |
| [`result/`](result/README.md) | 最新验证证据、历史运行日志和日志展示图 |

```text
DataBaseLab/
├─ README.md              项目入口、业务范围、流程与复现
├─ AGENTS.md              协作与公开上传规则
├─ ai_log.md              统一 AI 记录与审核事实
├─ 原始表设计草稿.png     保留原路径的设计演变证据
├─ app/                   Web 页面、服务与数据访问
├─ sql/                   按周保存的 SQL 交付
├─ scripts/               环境、复现与验证脚本
├─ tests/                 Web 集成检查与截图脚本
├─ docs/
│  ├─ README.md           唯一文档总索引
│  ├─ course/             课程原文，沿用原文件名
│  ├─ week1/ … week7/     每周说明；第7–9周共用 week7
│  ├─ reports/            两阶段公开报告
│  ├─ guides/             环境与公开材料规则
│  ├─ submission/         提交清单、分工与 AI 索引
│  └─ verification/       保留原路径的第三周复现记录
├─ result/                验证输出与截图，历史路径保留
└─ output/                被 Git 忽略的本机产物与私有配置
```

每周说明以 `docs/weekN/README.md` 为入口，同周图源、字典和分析材料放在一起。第7–9周合并为 `docs/week7/`。课程原文按用途归入 `docs/course/`，SQL 和历史结果仍沿用课程规定的路径；材料对应关系见[文档导航](docs/README.md)。

## 从空库复现 v0.1

**环境：** Windows PowerShell、SQL Server 2022 Express LocalDB。请在运行 LocalDB 实例的同一个 Windows 账户下操作。首次安装与初始化见[本地 SQL 环境说明](docs/guides/本地SQL环境.md)；正常运行不需要 SSMS 或 `sqlcmd`。

在仓库根目录打开普通 PowerShell。若当前账户尚未初始化实例，先运行：

```powershell
powershell.exe -NoProfile -File .\scripts\Initialize-LocalDB.ps1
```

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

## 重跑和排错

- `01-schema.sql` 要求空数据库；`02-seed.sql` 不会覆盖已有样例。完整重跑时请使用新数据库名，不要删除现有数据库。
- 若提示找不到 LocalDB 实例，请在**同一个 Windows 账户和终端**重新运行 `Initialize-LocalDB.ps1`。
- 若中途失败，应查看出错的 SQL 文件、SQL Server 错误号和该次运行的退出状态；不要只根据此前输出过的 `PASS` 判定整轮成功。
- 上述第四周脚本验证数据库原型；第七至九周为采购审批、验收入库、销售下单、模拟支付、确认出库、盘点和赠分实现受控 Web 入口。Web 采购限定单商品整单验收。跨表规则由脚本回归和 Web 集成检查分别核对。

## 课程阶段与当前交付

| 阶段 | 设计与任务 | 执行与验证 | 提交材料 |
| --- | --- | --- | --- |
| 第一阶段：第1–4周 v0.1 原型 | [文档导航](docs/README.md)中的第1–4周 | 本页空库复现步骤、[历史与最新结果](result/README.md) | [v0.1复核清单](docs/submission/复核清单.md)、[第一阶段报告](docs/reports/阶段报告-v0.1.md) |
| 第二阶段：第5–9周 v1.0 与 Web | [ER审查](docs/week5/README.md)、[规范化与迁移](docs/week6/README.md)、[应用设计](docs/week7/README.md) | [第六周迁移结果](result/week6/README.md)、[Web运行手册](app/README.md)、[Web验证结果](result/week7/README.md) | [第5–9周核对清单](docs/submission/第5-9周提交核对.md)、[第二阶段报告](docs/reports/第二阶段报告.md) |

课程原文、逐周材料和环境说明统一从[文档导航](docs/README.md)查找。第五周 review 修复已按用户授权合入 main；第六周修复验证保留逐行迁移比较与检查器反例；Web修复版在独立 LocalDB 和课程服务器各通过103项检查，服务器另有21项三角色流程核对。运行结果与学生逐项人工验收分别记录，以[AI记录](ai_log.md)及相应结果页为依据。正式库未执行本轮迁移。

## 公开版与课程提交包

本仓库按可核实的公开 GitHub 作者记录提交贡献，见[组内分工](docs/submission/组内分工.md)；历史成员 A/B 的人工职责保留原记录，账户对应未经确认时不推断。学号、私人联系方式及远程账户截图仅保留在私下课程提交包中。正式署名 PDF 不上传 GitHub，公开材料以文字报告、SQL、运行日志和无私人信息的历史日志图片为准。业务样例中的人物、联系方式均为模拟数据。

所有分支、提交及 GitHub 上传均遵循[公开材料与敏感信息规则](docs/guides/公开材料与敏感信息规则.md)。提交前必须检查暂存内容与文件元数据；原始署名材料及私下提交包保存在仓库外或被忽略的私密目录中。Agent 工作规则见 [AGENTS.md](AGENTS.md)。
