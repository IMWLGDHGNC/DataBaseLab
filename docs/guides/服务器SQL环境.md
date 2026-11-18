# 服务器 SQL Server 环境

本页说明课程服务器的连接和复现方式。本机开发与第10至12周专项复现见[本地 SQL 环境](本地SQL环境.md)。

## 按版本选择复现方式

| 任务 | 脚本或证据 |
| --- | --- |
| 从空样例库启动当前 Web 应用 | 按[应用手册](../../app/README.md)运行部署脚本，安装到第12周 |
| 核对第7–9周课程服务器实测 | [2026-10-14 独立样例库结果](../../result/week7/README.md)，覆盖 103 项集成检查和 21 项浏览器流程 |
| 核对第一阶段 v0.1 正式演示库 | [2026-09-30 权限升级结果](../../result/week4-customer-access-deploy-20260930.txt)及下方历史核对命令 |

第10至12周的自动验证记录来自 LocalDB。当前 GitHub 代码版本与课程服务器的已验证版本分别见[结果导航](../../result/README.md)。

## 第一阶段部署记录

第三周数据库于 2026-09-21 部署，第四周 v0.1 于 2026-09-23 部署。2026-09-30 补充顾客、会员权限并修正订单详情视图。下表记录当时的环境。

| 项目 | 值 |
| --- | --- |
| SSH 主机 | 向服务器管理员获取，不写入公开仓库 |
| SSH 端口 | 向服务器管理员获取，不写入公开仓库 |
| SSH 用户 | 向服务器管理员获取，不写入公开仓库 |
| 数据库引擎 | SQL Server 2022 Developer CU27，`16.0.4295.3` |
| Docker 容器 | 通过私密渠道取得名称并设置 `DB_CONTAINER` |
| Docker 镜像 | `mcr.microsoft.com/mssql/server:2022-latest` |
| 持久化卷 | Docker 命名卷，挂载到容器 `/var/opt/mssql` |
| 重启策略 | `unless-stopped` |
| 数据库 | `DataBaseLab_Week3`、`DataBaseLab_Week4` |
| SQL 登录 | 历史部署使用内置管理员 `sa`，Web 应用使用独立受限登录 |
| SQL 监听 | 服务器本机 `127.0.0.1:1433`，不直接暴露到局域网 |

SSH 连接参数、SQL 登录和目标数据库由服务器管理员通过小组私密渠道提供。公开材料中的连接示例使用占位符和环回地址。凭据处理见[公开材料规则](公开材料与敏感信息规则.md)。

## 从 Windows 连接

先通过私密渠道取得连接参数，在一个 PowerShell 窗口设置临时变量并建立 SSH 隧道。保持该窗口运行：

```powershell
$ServerAddress = '<向管理员获取>'
$ServerUser = '<向管理员获取>'
$ServerSshPort = '<向管理员获取>'
ssh -p $ServerSshPort -L 14330:127.0.0.1:1433 "${ServerUser}@${ServerAddress}"
```

首次连接时核对主机指纹并完成 SSH 认证，再用 SSMS 或 VS Code 的 MSSQL 扩展连接。Azure Data Studio 已于 2026-02-28 退役。[Microsoft 工具迁移说明](https://learn.microsoft.com/en-us/azure-data-studio/whats-happening-azure-data-studio)

- 服务器：`localhost,14330`
- 身份验证：SQL Login / SQL Server Authentication
- 用户名：管理员为目标库提供的 SQL 登录
- 数据库：管理员提供的已授权目标库。第一阶段历史库名见上表
- 加密：启用；若客户端不信任容器的自签名证书，勾选“信任服务器证书”

本地端口 `14330` 只是一条隧道入口；数据库在服务器上仍监听 `127.0.0.1:1433`。如果本机 `14330` 已被占用，可把命令和客户端地址中的 `14330` 同时换成其他未占用端口。

## 状态检查和常用运维

登录服务器：

```powershell
$ServerAddress = '<向管理员获取>'
$ServerUser = '<向管理员获取>'
$ServerSshPort = '<向管理员获取>'
ssh -p $ServerSshPort "${ServerUser}@${ServerAddress}"
```

在已授权的服务器终端私下设置 `DB_CONTAINER`，再查看容器状态、最近日志和端口绑定。

```bash
docker ps --filter "name=$DB_CONTAINER"
docker logs --tail 100 "$DB_CONTAINER"
docker port "$DB_CONTAINER"
```

正常端口输出应为 `127.0.0.1:1433`。按需重启数据库：

```bash
docker restart "$DB_CONTAINER"
```

重启后等待业务库完成恢复再连接。持久化卷存放数据库文件，重跑试验使用独立样例库。

第一阶段服务器部署归档曾使用以下路径。当前复现脚本的输出位置见[脚本导航](../../scripts/README.md)。

```text
$HOME/database-lab-deploy
$HOME/database-lab-deploy/logs
$HOME/database-lab-deploy/week4
```

## 核对第一阶段历史样例

如需复核第4周基线，在已授权的服务器终端从仓库根目录执行。以下命令沿用部署脚本的容器内配置读取 SQL 凭据，目标库须仍为第4周样例。

```bash
docker exec -i "$DB_CONTAINER" sh -lc \
  'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -I -b -r 1 -f 65001 -d DataBaseLab_Week4 -i /dev/stdin' \
  < sql/week3/04-verify.sql
```

成功结果应包含：

```text
VERIFY_PASS          15          46
```

`15` 是业务表数，`46` 是样例数据总行数。2026-09-21 的第三周部署通过了 `CRUD_PASS` 和 `CONSTRAINT_TESTS_PASS`（12 项约束测试），并在重启容器后再次得到 `VERIFY_PASS`。2026-09-23 的第四周部署还通过 `CONSTRAINT_PASS`（6 项）、`QUERY_PASS`、`VIEW_PASS` 和 `ROLE_PASS`（17 项），正式日志位于服务器的 `database-lab-deploy/logs/week4-deploy-20260923.log`，仓库副本见[第四周服务器部署日志](../../result/week4-server-deploy.txt)。2026-09-30 在独立空库完整复现顾客、会员权限更新后，正式库升级通过 `VIEW_PASS`、`ROLE_PASS`（34 项）、`VERIFY_PASS` 和 `DEPLOY_OBJECTS_PASS`；日志见[权限升级部署结果](../../result/week4-customer-access-deploy-20260930.txt)。升级前备份位于容器持久卷的 `/var/opt/mssql/data/DataBaseLab_Week4_pre_customer_access_20260930.bak`，已通过 `RESTORE VERIFYONLY`。

## 重建第一阶段历史样例

仓库的 [`00-create-database.sql`](../../sql/week3/00-create-database.sql) 为 Windows LocalDB 编写，会解析反斜杠文件路径，不能直接用于 Linux 容器。服务器上新建空库时使用普通的 `CREATE DATABASE [数据库名]`，然后按以下顺序执行：

```text
01-schema.sql
02-seed.sql
04-verify.sql
03-crud.sql
04-verify.sql
week4/constraint.sql
05-constraint-tests.sql
week4/query.sql
week4/view.sql
week4/role.sql
04-verify.sql
```

手工执行 SQL 时，使用 `-I` 启用 `QUOTED_IDENTIFIER`。仓库的 Linux 脚本通过标准输入传入 SQL，历史核对命令另显式指定 UTF-8 编码。

- `-I` 满足筛选唯一索引需要的会话设置。
- `-f 65001` 为手工核对指定 UTF-8 编码。
- `-b` 让 SQL 错误产生非零退出码。
- `-C` 信任当前容器的服务器证书。

`01-schema.sql` 只接受空数据库，`02-seed.sql` 不会覆盖已存在的数据。不要为了重跑脚本直接删除未知数据库或持久化卷；先核对目标库、备份数据，再使用新的数据库名或明确制定迁移方案。

## 已知问题与边界

- SSH 服务偶尔返回 `Exceeded MaxStartups`，表现为输入密码前连接就被关闭。这是服务器未认证连接数限流，不是密码错误；降低重试频率，稍后重新连接。
- 第一阶段部署记录证明使用了 Docker 卷和一次升级前备份。实际备份策略与恢复流程由服务器管理员确认。
- 部署脚本需要数据库管理权限来建样例库及受限登录。Web 运行时使用第7、10、12周脚本配置的应用权限。
- 第三、第四周数据库用于实验和演示，跨表业务规则、并发事务和生产级权限边界仍以 [Week3](../week3/README.md) 与 [Week4](../week4/README.md) 的说明为准。
