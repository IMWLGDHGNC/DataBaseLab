# DataBaseLab：线上零食网店数据库实验

我们以线上零食网店为场景，完成了业务分析、关系模式设计、SQL Server 建库、增删改查、连接查询、视图、完整性约束和角色授权。当前 v0.1 包含 **15 张业务表和 46 行相互关联的样例数据**。项目已在一台服务器上部署，并在独立空库完成全流程复现。

## 从这里开始

| 你想了解什么 | 阅读或执行入口 |
| --- | --- |
| 项目做什么、业务范围是什么 | 本页下方的“项目范围、角色与流程” |
| 老师要求什么、每周做了什么 | [文档导航](docs/README.md)：课程原文、各周成果和阶段材料 |
| 在自己电脑上跑起来 | 本页“从空库复现 v0.1”；脚本用途见[脚本导航](scripts/README.md) |
| 在授权服务器上运行第七至九周 Web 应用 | [应用操作手册](app/README.md)与[Week7 设计说明](docs/Week7.md) |
| 数据库如何实现、SQL 按什么顺序运行 | [SQL 导航](sql/README.md) |
| 查看通过结果和截图 | [结果导航](result/README.md)：先看最新验证，再看历史记录 |
| 核对阶段提交是否齐全 | [复核清单](复核清单.md)、[阶段报告](docs/阶段报告-v0.1.md)、[AI 记录](ai_log.md)、[组内分工](组内分工.md) |
| 参与修改和公开上传 | [仓库工作规则](AGENTS.md)、[敏感信息规则](docs/公开材料与敏感信息规则.md) |

**当前阶段：** 仓库保存第一至第四周 v0.1 原型、第五周 ER 模型、第六周 v1.0 迁移，以及第七至九周 Web 应用。Web 已在课程服务器独立样例库部署并通过 39 项集成检查；组员逐项人工验收状态单独记录。

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

我们按“补货需求 → 采购单 → 审批验收 → 库存批次及入库流水”记录采购；按“浏览商品 → 下单并锁定批次 → 模拟支付 → 出库复核 → 完成订单 → 会员赠分”记录销售。**锁定只减少可售量，真正出库才减少现存量；已支付也不等于已完成。**支付失败或待支付取消释放锁定；批次到期等异常暂停出库并保留原因。采购流程仍以数据库样例展示；销售流程现已通过受限 Web 入口实现，详见 [Week7](docs/Week7.md)。

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
├─ README.md              项目入口、业务范围与复现步骤
├─ AGENTS.md              协作与公开上传规则
├─ ai_log.md              AI 建议、人工取舍与验证记录
├─ 组内分工.md            组员实际贡献（公开版匿名）
├─ 复核清单.md            v0.1 课程提交要求与材料对应
├─ 原始表设计草稿.png     设计演变的原始证据
├─ docs/                  课程要求与设计文档
│  ├─ README.md           文档导航
│  ├─ 第N周任务讲解.md    对应周课程原文转换
│  ├─ WeekN.md            对应周实现与验证说明
│  └─ verification/       第三周脚本保存的历史复现记录
├─ sql/                   可执行 SQL，按课程周次组织
│  ├─ README.md           SQL 用途及顺序
│  ├─ week3/              建库、建表、样例、CRUD 与检查
│  └─ week4/              查询、视图、约束与角色
├─ scripts/               环境和复现脚本，入口为 README.md
└─ result/                运行日志与图，入口为 README.md
```

`第N周` / `WeekN` 是已有文件的命名说明。第五周交付包含 `docs/week5/`、`sql/week5/` 和 `result/week5/`，分别保存 ER 设计材料、验证 SQL、图与验证结果。目录沿用课程要求的 `sql` / `result` 及按周交付路径，具体验收项见[第四周阶段清单](docs/第四周任务讲解.md)。

## 从空库复现 v0.1

**环境：** Windows PowerShell、SQL Server 2022 Express LocalDB。请在运行 LocalDB 实例的同一个 Windows 账户下操作。首次安装与初始化见[本地 SQL 环境说明](docs/本地SQL环境.md)；正常运行不需要 SSMS 或 `sqlcmd`。

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
- 上述第四周脚本验证数据库原型；第七至九周已为销售下单、模拟支付、确认出库、盘点和赠分实现受控 Web 入口。采购审批仍以样例与 SQL 验证为主。跨表规则由脚本回归和 Web 集成检查分别核对。

## 文档和结果

- 业务分析与设计：[Week1](docs/Week1.md)、[Week2](docs/Week2.md)；建库与实验：[Week3](docs/Week3.md)、[Week4](docs/Week4.md)
- 课程任务：[第一周](docs/第一周任务讲解.md)、[第二周](docs/第二周任务讲解.md)、[第三周](docs/第三周任务讲解.md)、[第四周](docs/第四周任务讲解.md)
- [组内分工与贡献](组内分工.md)、[提交复核清单](复核清单.md)
- [阶段报告（公开文字版）](docs/阶段报告-v0.1.md)、[AI 使用记录](ai_log.md)、[运行日志和截图](result/README.md)

## 第五周 ER 模型

第五周已完成 15 个业务实体、107 个属性的 ER 模型、业务规则映射与问题清单。设计及验证入口见 [Week5](docs/Week5.md)，课程原文见[第五周任务讲解](docs/第五周任务讲解.md)，图和运行证据见[Week5 结果](result/week5/README.md)。模型以业务表为范围，顾客身份映射单独作为权限辅助对象说明。2026-10-01 按用户授权修复 review 问题后合入 `main`；可复现目录核对及检查器回归见 [Week5](docs/Week5.md)。

## 第六周函数依赖、迁移与回归

第六周以已核对的[第五周 ER 模型](docs/Week5.md)为起点，逐表分析函数依赖、范式与有意保留的余额缓存；目标模式删除库存流水中可沿批次还原的重复采购明细编号。完整分析、目标 ER 图、字典差异及第二阶段报告素材见[第六周说明](docs/Week6.md)。迁移和回归 SQL 分别为 [migration.sql](sql/week6/migration.sql) 与 [regression.sql](sql/week6/regression.sql)。

2026-10-10 初版在课程服务器的新建独立样例库通过迁移与回归；后续 review 修复在新的 Windows LocalDB 样例库验证。最新运行得到 15 张业务表、46 行，目标 106 属性/23 外键、完成销售 15 件/64.50 元及 34 项原角色权限；四组业务查询逐行一致，流水四种合法类型和十一项负例通过，九项检查器错误注入均被拒绝并恢复。详见[最新修复证据与历史输出](result/week6/README.md)。正式库未迁移。授权的 Linux 环境使用 [Run-Week6-Server.sh](scripts/Run-Week6-Server.sh)，Windows LocalDB 使用 [Run-Week6.ps1](scripts/Run-Week6.ps1)；检查器回归命令见 [Week6](docs/Week6.md)。迁移创建的 `week6_baseline` 只保存审核快照，不计入业务表与 ER 模型；迁移与回归需在同一天执行。原始日志先写入被忽略的 `output/week6/`，检查后再公开。

## 第七至九周 Web 应用

先读[Week7 设计说明](docs/Week7.md)，再按[应用手册](app/README.md)在授权服务器的新建独立样例库准备和启动。应用提供顾客下单与本人订单、店员盘点和出库、管理员商品维护；订单与库存写操作在服务层和参数化 DAO 中完成事务控制。服务器部署通过第六周基线与角色授权检查，Web 集成检查通过 39 项。截图、结果摘要见[第七至九周结果](result/week7/README.md)，设计过程与总结见[第二阶段报告](docs/第二阶段报告.md)。演示凭据和原始异常日志只保存在服务器私有目录。

## 公开版与课程提交包

本仓库使用成员 A/B 记录实际职责；姓名、学号及远程账户截图仅保留在私下课程提交包中。正式署名 PDF 不上传 GitHub，公开材料以文字报告、SQL、运行日志和无个人信息的历史日志图片为准。业务样例中的人物、联系方式均为模拟数据。

所有分支、提交及 GitHub 上传均遵循[公开材料与敏感信息规则](docs/公开材料与敏感信息规则.md)。提交前必须检查暂存内容与文件元数据；原始署名材料及私下提交包保存在仓库外或被忽略的私密目录中。Agent 工作规则见 [AGENTS.md](AGENTS.md)。
