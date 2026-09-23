# v0.1 运行结果

- [Week 4 首次空库运行](week4-run.txt)：`DataBaseLab_Week4`，完整建库、CRUD、查询、视图、约束和角色结果。
- [Week 4 第二次空库复现](week4-reproduction.txt)：独立数据库中的同一流程。
- [Week 4 服务器合并前验证](week4-server-preflight.txt)：补强事务隔离和权限案例后，在 SQL Server 2022 课程服务器独立临时库执行的完整流程，包含 17 项角色正反例。

前两份文件是 SQL Server 2022 LocalDB 的实际文本输出，第三份是课程服务器 SQL Server 2022 的实际文本输出。课程要求的图形界面截图需现场在本机执行后留存；这里不把生成图片冒充真实界面截图。

以下 PNG 是把首次运行的相应原始日志片段在浏览器中打开后截取的图片，便于查看；它们不是 SSMS 界面截图，核对时以对应文本日志为准：

| 运行阶段 | 日志截图 |
| --- | --- |
| 建库和 15 表 46 行 | [build](week4-build.png) |
| CRUD 演示 | [crud](week4-crud.png) |
| 正反约束案例 | [constraints](week4-constraints.png) |
| 多表查询 | [queries](week4-queries.png) |
| 三个视图 | [views](week4-views.png) |
| 角色权限正反例 | [roles](week4-roles.png) |
