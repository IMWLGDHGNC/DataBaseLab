# DataBaseLab · 零食网店数据库应用 v1.0

**v1.0 已完成。** 项目覆盖第5–9周的ER审查、规范化迁移和Web应用开发，其中第7–9周为一个完整的应用开发任务。使用 **SQL Server 2022 + Flask + pymssql**，数据库包含15张业务表、106个业务字段及46行初始样例数据。

**当前进展：第10周数据库编程已完成自动验证。** 存储过程接管库存调整和订单完成，SQL函数实现补货、销售汇总及会员优惠；本机87项专项与103项完整Web回归通过。当前应用需同时安装第10周SQL，详见[本周说明](docs/week10/README.md)。上述15表/106字段/46行指v1.0基线；新周次新增快照字段，人工审核另行确认。

## 功能与流程

场景为单店、单仓、人民币计价的零食网店，支持商品、采购、库存、订单、模拟支付和会员积分；真实支付、配送、退货退款及积分兑换不在v1.0范围。

| 角色 | 主要操作 |
| --- | --- |
| 顾客 | 浏览商品，下单，修改或取消本人待支付订单，模拟支付 |
| 店员 | 采购验收入库，盘点库存，查看订单并确认出库 |
| 管理员 | 维护商品，建立并审批采购，执行库存与出库操作 |

采购流程：商品维护 → 采购审批 → 验收入库。销售流程：下单锁定 → 模拟支付 → 确认出库 → 完成订单并赠分。**下单只锁定可售库存，确认出库才减少现存量。** 角色、事务与业务边界详见[第7–9周设计说明](docs/week7-9/README.md)。

## 运行 v1.0

在已准备SQL Server容器、Python 3.12和uv的Linux环境中，私下设置 `DB_CONTAINER`，从仓库根目录执行：

```bash
bash scripts/Run-Week7-Server.sh
export APP_CONFIG_FILE="$(cat output/week7/config-path.txt)"
bash scripts/Start-Week7-Web.sh
```

默认访问 `http://127.0.0.1:8767`。脚本依次完成基线建库 → ER核对 → v1.0迁移与回归 → 应用授权与配置；配置及演示账号保存在私有目录。安装前提、登录、测试和排错见[Web操作手册](app/README.md)，Windows数据库复现见[LocalDB指南](docs/guides/本地SQL环境.md)。

## 项目与文档入口

```text
DataBaseLab/
├─ app/       Web页面、路由、服务与DAO
├─ sql/       按周SQL交付
├─ scripts/   环境与复现脚本
├─ tests/     应用集成检查
├─ result/    验证结果与截图
└─ docs/      课程原文、设计、指南与报告
```

| 目录或材料 | 内容 |
| --- | --- |
| [v1.0 ER图](result/week6/er-v1.0.svg) / [设计分析](docs/week6/README.md) | 函数依赖、更新异常、范式及分解/保留方案 |
| [Web手册](app/README.md) / [SQL导航](sql/README.md) / [脚本导航](scripts/README.md) | 运行环境、配置、执行顺序与复现 |
| [文档导航](docs/README.md) / [验证结果](result/README.md) | 逐周材料、测试输出与截图 |
| [第二阶段报告](docs/reports/第二阶段报告.md) / [提交清单](docs/submission/第5-9周提交核对.md) | 第5–9周v1.0交付 |
| [第10周](docs/week10/README.md) / [验证结果](result/week10/README.md) | 数据库过程、函数、折扣与应用集成 |
| [组内分工](docs/submission/组内分工.md) / [ai_log.md](ai_log.md) | 实际贡献、AI辅助与审核记录 |

已有验证包含LocalDB及课程服务器各 **103项集成检查**，以及服务器 **21项三角色流程核对**，详见[验证结果](result/week7/README.md)。第一阶段v0.1的复现和历史材料保留在相应指南与周文档中。

参与修改前阅读[仓库规则](AGENTS.md)和[公开材料规则](docs/guides/公开材料与敏感信息规则.md)。署名报告、私下提交包和凭据保存在公开仓库之外。
