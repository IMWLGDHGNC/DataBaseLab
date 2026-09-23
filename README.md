# DataBaseLab

数据库实验课程项目，以线上零食网店为场景，逐步完成业务需求分析、数据库设计与实现。

## 文档

- [第一周任务讲解](docs/第一周任务讲解.md)
- [第一周业务分析](docs/Week1.md)
- [第二周任务讲解](docs/第二周任务讲解.md)
- [第二周关系模式草稿](docs/Week2.md)
- [第三周任务讲解](docs/第三周任务讲解.md)
- [第三周建库、CRUD 与复现结果](docs/Week3.md)
- [第四周任务讲解](docs/第四周任务讲解.md)
- [第四周查询、视图、约束、权限与复现结果](docs/Week4.md)
- [v0.1 阶段报告](docs/阶段报告-v0.1.md)
- [v0.1 运行结果](result/README.md)
- [AI 使用记录](docs/AI使用记录.md)
- [本地 SQL Server 环境配置](docs/本地SQL环境.md)
- [服务器 SQL Server 连接与运维](docs/服务器SQL环境.md)

## 当前内容

第一周完成业务分析，第二周形成 15 表关系模式并经用户确认人工复核。第三周在 SQL Server 2022 LocalDB 中实现 15 张表、107 个字段和 46 行样例数据，以及商品、库存与订单 CRUD。第四周增加连接查询、三个视图、异常解决说明约束与四类岗位权限；独立空库运行均通过，含 18 项约束正反例和 17 项权限正反例。第三、四周新增 SQL 仍需小组逐句人工复核，组内分工暂不填写。

本地实例为 `(localdb)\DataBaseLab`，原环境验证数据库为 `DataBaseLab`，第三周业务数据库为 `DataBaseLab_Week3`，第四周独立复现数据库为 `DataBaseLab_Week4`。课程服务器的 SQL Server 2022 容器同时保留 `DataBaseLab_Week3` 和已完成部署的 `DataBaseLab_Week4`，通过 SSH 隧道访问；连接信息、部署日志和重新导入注意事项见服务器环境说明。Mermaid 图可在 GitHub 文档页中查看。

从空库复现 v0.1：在 Windows PowerShell 的仓库根目录运行 `powershell.exe -NoProfile -File .\scripts\Run-Week4.ps1`。已有同名数据库时使用 `-Database DataBaseLab_Week4_自定义后缀` 选择新库；完整顺序和结果见[第四周说明](docs/Week4.md)。
