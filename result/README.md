# 实验结果导航

本目录保存实际运行证据。完整执行步骤见[根 README](../README.md)，SQL 与脚本用途见 [sql](../sql/README.md)和 [scripts](../scripts/README.md)。核对当前实现时先看最新验证；历史文件保留原版本结果。

## 当前 v0.1 的最新证据

| 证据 | 环境与结果 |
| --- | --- |
| [2026-10-01 提交前空库验证](week4-submission-validation-20261001.txt) | SQL Server 2022 LocalDB：15 张业务表、46 行样例、6 项本周约束、12 项非法写入、34 项权限，最终 WEEK4_PASS |
| [2026-09-30 顾客会员权限升级](week4-customer-access-deploy-20260930.txt) | 课程服务器 SQL Server 2022：视图回归、34 项权限、15 表 46 行及正式库部署对象复核 |

15 张是业务表数量；权限辅助身份映射单独计数。新的 34 项权限结果应与上面两份日志核对，旧图片中的较少案例反映当时版本。

## 历史运行记录

| 日志 | 用途与版本 |
| --- | --- |
| [首次空库运行](week4-run.txt) | LocalDB：完整建库、CRUD、查询、视图、约束和初版权限结果 |
| [第二次空库复现](week4-reproduction.txt) | LocalDB：在另一个独立库复现首次流程 |
| [服务器合并前验证](week4-server-preflight.txt) | 课程服务器：补强失败案例事务隔离及权限后完整运行，17 项角色正反例 |
| [服务器正式部署](week4-server-deploy.txt) | 课程服务器：当时合并后的 main 部署输出，早于顾客会员权限升级 |

第三周双空库复现、比较与重复执行防护日志保留在 [docs/verification](../docs/verification/)，说明见 [Week3](../docs/Week3.md)。

## 公开日志展示图

以下 PNG 把首次运行的原始日志片段在浏览器中打开后截取，用于阅读；它们是历史日志展示图，未作为最新 SQL 管理界面的现场截图。

| 运行阶段 | 日志截图 |
| --- | --- |
| 建库和 15 表 46 行 | [build](week4-build.png) |
| 商品、库存和订单 CRUD | [crud](week4-crud.png) |
| 正常及非法约束案例 | [constraints](week4-constraints.png) |
| 多表连接和关键查询 | [queries](week4-queries.png) |
| 三个统计视图 | [views](week4-views.png) |
| 初版角色权限正反例 | [roles](week4-roles.png) |

课程私下提交包另保留了 2026-09-30 的六张 VS Code 现场截图；原图含远程账户信息，仅在私下材料中提供。公开材料的处理规则见[敏感信息规则](../docs/公开材料与敏感信息规则.md)。

## 第五周 ER 模型

[第五周结果](week5/README.md)索引完整/分区 ER 图、原始验证及[同步 main 后的复验](week5/sync-validation-20261001.md)。设计说明见 [Week5](../docs/Week5.md)，图源与字典见 [docs/week5](../docs/week5/er-model.md)。review 修复后的最新证据见 [2026-10-01 修复验证](week5/review-validation-20261001.md)，包含7项检查器反例及数据摘要一致性。第五周按用户授权合入 main。
