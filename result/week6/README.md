# 第六周迁移结果

当前版本的最新证据见 [review 修复验证](review-validation-20261010.md) 和 [结构化实际结果](review-validation-20261010.json)：LocalDB 全新样例库中四组查询的十三行迁移前/预期/迁移后值全部一致，21 项写入与权限回归通过，九项检查器反例均被拒绝并恢复。以下服务器输出保存为修复前历史版本，不包含本轮新增的审核快照和检查器验证。

2026-10-10 在课程服务器现有 SQL Server 2022 Docker 容器中，新建独立测试库 `DataBaseLab_Week6_20261010113646`，从本仓库第三、四周脚本重建 v0.1，再执行第五周模型核对、第六周迁移和回归。未在正式库执行迁移。完整 SQL 输出见[经敏感信息检查的执行记录](server-validation-20261010.txt)；只去除了 `sqlcmd` 表格行尾填充空格，不含远程地址、登录名、主机名、密码或用户目录。最初一次建表因 `sqlcmd` 未启用 `QUOTED_IDENTIFIER` 而中止；随后在全新测试库使用 `-I` 重跑并通过。前次失败库经确认无业务表后已清理，未用于后续结果。

| 阶段 | 实测结果 |
| --- | --- |
| v0.1 基线 | `VERIFY_PASS 15 46`；`ROLE_PASS 34` |
| 第五周模型复核 | `CATALOG_PASS`：15 表、107 属性、25 外键；`ER_BOUNDARY_PASS 9`；`WEEK5_ER_PASS`，回滚后仍为 15 表 46 行 |
| 第六周迁移 | `W6_MIGRATION_PASS`：15 表 46 行、库存流水 6 行；迁移脚本双向比较每条流水及其可还原的采购来源 |
| 目标目录和业务 | 15 表、106 属性、23 外键、9 项 UNIQUE；已完成销售 15 件、64.50 元；订单金额、库存与积分余额对账一致 |
| 写入与权限回归 | 合法商品写入后回滚；非法外键、零锁定数量均被 547 拒绝，历史批次来源改写被 51620 拒绝；经理可查销售视图、订单角色直接改库存被 229 拒绝、顾客仅见本人订单；再次 `ROLE_PASS 34` |
| 最终结果 | `W6_REGRESSION_PASS`、`WEEK6_SERVER_PASS` |

[完整目标 ER 图](er-v1.0.svg)可缩放查看，[PNG](er-v1.0.png)用于展示；可编辑源在 [docs/week6](../../docs/week6/er-v1.0.mmd)。

服务器复现入口为 [Run-Week6-Server.sh](../../scripts/Run-Week6-Server.sh)：将 `DB_CONTAINER` 私下设为现有容器名，在授权的 Linux 主机运行。它每次创建新测试库，原始 transcript 先留在被 Git 忽略的 `output/week6/`；检查内容后才能将脱敏副本放入 `result/week6/`。Windows LocalDB 入口为 [Run-Week6.ps1](../../scripts/Run-Week6.ps1)；初版未在 Windows 执行，本轮 review 修复已在 LocalDB 验证。

本页记录自动执行和脚本检查结果；尚无组员逐项人工审查意见，不能将这些 PASS 标记写作人工验收。测试库保留供复核，不自动删除。
