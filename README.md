# DataBaseLab · 零食网店数据库应用 v2.0

**v2.0 第三阶段评审版。** 在第5–9周 v1.0 的 ER 审查、规范化和 Web 应用基础上，第10至13周完成过程、函数、触发器、高级查询及业务事务，并验证锁等待、隔离级别、死锁和并发订单。使用 **SQL Server 2022 + Flask + pymssql**。v1.0 基线为15张业务表、106个业务字段及46行样例，第三阶段新增字段及审计辅助表。组员人工审核待确认。

## 功能与流程

场景为单店、单仓、人民币计价的零食网店，支持商品、采购、库存、订单、模拟支付和会员积分；真实支付、配送、退货退款及积分兑换不在v1.0范围。

| 角色 | 主要操作 |
| --- | --- |
| 顾客 | 浏览商品，下单，修改或取消本人待支付订单，模拟支付 |
| 店员 | 采购验收入库，盘点库存，查看订单并确认出库 |
| 管理员 | 维护商品，建立并审批采购，执行库存与出库操作 |

采购流程：商品维护 → 采购审批 → 验收入库。销售流程：下单锁定 → 模拟支付 → 确认出库 → 完成订单并赠分。**下单只锁定可售库存，确认出库才减少现存量。** 角色、事务与业务边界详见[第7–9周设计说明](docs/week7-9/README.md)。

## 运行应用

在已准备SQL Server容器、Python 3.12和uv的Linux环境中，私下设置 `DB_CONTAINER`，从仓库根目录执行：

```bash
bash scripts/Run-Week7-Server.sh
export APP_CONFIG_FILE="$(cat output/week7/config-path.txt)"
bash scripts/Start-Week7-Web.sh
```

默认访问 `http://127.0.0.1:8767`。部署脚本在独立样例库安装当前应用所需的 SQL，配置及演示账号保存在私有目录。Linux 启动与操作见[Web 手册](app/README.md)，Windows 专项复现见[LocalDB 指南](docs/guides/本地SQL环境.md)。

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
| [第11周](docs/week11/README.md) / [验证结果](result/week11/README.md) | 库存审计、完成触发器及三类窗口查询 |
| [第12周](docs/week12/README.md) / [验证结果](result/week12/README.md) | 商品分类递归、订单完成与补货入库事务 |
| [第13周](docs/week13/README.md) / [验证结果](result/week13/README.md) | 锁等待、隔离级别、死锁、统一访问顺序和真实业务并发 |
| [第三阶段报告](docs/reports/第三阶段报告.md) | 第10至13周对象、实验流程、结果与组员补写入口 |
| [组内分工](docs/submission/组内分工.md) / [ai_log.md](ai_log.md) | 实际贡献、AI辅助与审核记录 |

当前 LocalDB 验证包括 **14 项第13周专项**和 **103 项 Web 回归**，见[第13周结果](result/week13/README.md)。课程服务器的 **103 项集成检查**和 **21 项三角色核对**对应[第7–9周版本](result/week7/README.md)。

参与修改前阅读[仓库规则](AGENTS.md)和[公开材料规则](docs/guides/公开材料与敏感信息规则.md)。署名报告、私下提交包和凭据保存在公开仓库之外。
