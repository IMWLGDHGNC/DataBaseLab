# DataBaseLab

数据库实验课程项目，以线上零食网店为场景，逐步完成业务需求分析、数据库设计与实现。

## 文档

- [第一周任务讲解](docs/第一周任务讲解.md)
- [第一周业务分析](docs/Week1.md)
- [第二周任务讲解](docs/第二周任务讲解.md)
- [第二周关系模式草稿](docs/Week2.md)
- [第三周任务讲解](docs/第三周任务讲解.md)
- [第三周建库、CRUD 与复现结果](docs/Week3.md)
- [AI 使用记录](docs/AI使用记录.md)
- [本地 SQL Server 环境配置](docs/本地SQL环境.md)
- [服务器 SQL Server 连接与运维](docs/服务器SQL环境.md)

## 当前内容

第一周完成业务分析，第二周形成 15 表关系模式并经用户确认人工复核。第三周已在 SQL Server 2022 LocalDB 中实现 15 张表、107 个字段和 46 行样例数据，完成商品、库存与订单的 CRUD，以及两次独立空库复现和 12 项非法数据测试。本周新增 SQL 仍需小组逐句人工复核。

本地实例为 `(localdb)\DataBaseLab`，原环境验证数据库为 `DataBaseLab`，第三周业务数据库为 `DataBaseLab_Week3`。同一业务数据库已部署到课程服务器的 SQL Server 2022 容器，通过 SSH 隧道访问；连接信息、密码存放位置、状态检查和重新导入注意事项见服务器环境说明。运行方式、实际结果与脚本边界见第三周说明。Mermaid 图可在 GitHub 文档页中查看。
