# v0.1 运行结果

- [Week 4 首次空库运行](week4-run.txt)：`DataBaseLab_Week4`，完整建库、CRUD、查询、视图、约束和角色结果。
- [Week 4 第二次空库复现](week4-reproduction.txt)：独立数据库中的同一流程。
- [Week 4 服务器合并前验证](week4-server-preflight.txt)：补强事务隔离和权限案例后，在 SQL Server 2022 课程服务器独立临时库执行的完整流程，包含 17 项角色正反例。
- [Week 4 服务器正式部署](week4-server-deploy.txt)：合并后的 `main` 实现在服务器 `DataBaseLab_Week4` 数据库中的正式部署输出。
- [Week 4 顾客会员权限升级](week4-customer-access-deploy-20260930.txt)：2026-09-30 正式库升级输出，含视图回归、34 项权限案例、15 表 46 行与部署对象复核。

前两份文件是 SQL Server 2022 LocalDB 的实际文本输出，后三份是课程服务器 SQL Server 2022 的实际文本输出。

课程提交包另外保留了 2026-09-30 的六张 VS Code 现场截图。原始图片包含远程账户等个人信息，因此不上传公开仓库；这里提供实际运行的文本日志及无个人身份信息的日志展示。34 项权限的最新证据见部署升级和本次提交验证日志。

以下 PNG 是把首次运行的相应原始日志片段在浏览器中打开后截取的图片，便于查看；它们不是 SSMS 界面截图，核对时以对应文本日志为准：

| 运行阶段 | 日志截图 |
| --- | --- |
| 建库和 15 表 46 行 | [build](week4-build.png) |
| CRUD 演示 | [crud](week4-crud.png) |
| 正反约束案例 | [constraints](week4-constraints.png) |
| 多表查询 | [queries](week4-queries.png) |
| 三个视图 | [views](week4-views.png) |
| 角色权限正反例 | [roles](week4-roles.png) |

## 本次提交验证（2026-10-01）

[独立 LocalDB 空库完整运行](week4-submission-validation-20261001.txt)：15 张业务表、46 行样例、6 项本周约束、12 项非法写入及 34 项角色权限案例通过，终止标记为 WEEK4_PASS。旧截图和旧日志用于保留历史过程，34 项权限以最新部署和本次验证日志为准。
