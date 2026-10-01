# Week5 同步 main 后的验证（2026-10-01）

同步来源：`main` 的 `73e9334`，包含 v0.1 提交修订及顾客/会员权限升级。本分支为 `codex/week5-er-model`，第五周及本轮适配仍待人工审核。

## 独立空库运行

在 SQL Server 2022 LocalDB 的新库 `DataBaseLab_Week4_W5Sync20261001A` 顺序执行 `Run-Week4.ps1`、`sql/week5/verify-er.sql` 和 `sql/week3/04-verify.sql`，三个进程退出码均为 0。

| 验证 | 实际结果 | 日志 |
| --- | --- | --- |
| 第三、四周完整基线 | 15 张业务表、46 行样例；6 项本周约束、12 项非法写入、34 项权限；WEEK4_PASS | [基线](sync-baseline-20261001.txt) |
| 业务 ER 目录 | CATALOG_PASS：15 表、107 属性、25 外码；另有 1 张权限辅助表（2 列、1 主键、1 外码） | [目录与探针](sync-er-20261001.txt) |
| 约束边界 | ER_BOUNDARY_PASS，9/9 符合文档所述的现有行为；WEEK5_ER_PASS | [目录与探针](sync-er-20261001.txt) |
| 回滚后复核 | VERIFY_PASS：15 表、46 行；15 张业务表的 SHA-256 摘要与本次基线全部一致 | [回滚后](sync-after-probes-20261001.txt) |

`CATALOG_PASS` 的 TableCount、AttributeCount、ForeignKeyCount 只统计 dbo 业务模型；SecurityTableCount 单列权限辅助表数量。脚本还核对全库总数，防止额外对象被过滤条件掩盖。旧版无辅助表的目录口径仍受支持，当前这轮实际运行验证的是带辅助表的新版。

本轮保留原 2026-09-30 的历史日志；未重绘未变更的业务 ER 图。探针 PASS 表示现有约束行为与问题清单一致，不意味着所有业务规则已由数据库约束保证。
