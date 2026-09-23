# 服务器 SQL Server 环境

本项目的第三周数据库已于 2026-09-21 部署到课程服务器，第四周 v0.1 已于 2026-09-23 部署。远端环境用于小组共享、演示和服务器端验证；本机开发环境仍见[本地 SQL Server 环境](本地SQL环境.md)。

## 当前部署

| 项目 | 值 |
| --- | --- |
| SSH 主机 | 向服务器管理员获取，不写入公开仓库 |
| SSH 端口 | 向服务器管理员获取，不写入公开仓库 |
| SSH 用户 | 向服务器管理员获取，不写入公开仓库 |
| 数据库引擎 | SQL Server 2022 Developer CU27，`16.0.4295.3` |
| Docker 容器 | `database-lab-sqlserver` |
| Docker 镜像 | `mcr.microsoft.com/mssql/server:2022-latest` |
| 持久化卷 | `database-lab-sql-data`，挂载到容器 `/var/opt/mssql` |
| 重启策略 | `unless-stopped` |
| 数据库 | `DataBaseLab_Week3`、`DataBaseLab_Week4` |
| SQL 登录名 | `sa` |
| SQL 监听 | 服务器本机 `127.0.0.1:1433`，不直接暴露到局域网 |

SSH 主机、端口、用户名和密码通过小组认可的私密渠道向服务器管理员获取，不进入 Git。SQL 密码同样不进入 Git；随机生成的密码仅保存在服务器当前 SSH 用户的 `$HOME/.config/database-lab/sa-password`，权限为 `600`。不要把任何凭据复制到文档、Issue、公开聊天记录或提交中。

## 从 Windows 连接

先通过私密渠道取得连接参数，在一个 PowerShell 窗口设置临时变量并建立 SSH 隧道。保持该窗口运行：

```powershell
$ServerAddress = '<向管理员获取>'
$ServerUser = '<向管理员获取>'
$ServerSshPort = '<向管理员获取>'
ssh -p $ServerSshPort -L 14330:127.0.0.1:1433 "${ServerUser}@${ServerAddress}"
```

首次连接需确认主机指纹，并输入服务器账户密码。随后登录 SSMS 或 Azure Data Studio：

- 服务器：`localhost,14330`
- 身份验证：SQL Login / SQL Server Authentication
- 用户名：`sa`
- 数据库：`DataBaseLab_Week4`（需要查看第三周原始部署时选择 `DataBaseLab_Week3`）
- 加密：启用；若客户端不信任容器的自签名证书，勾选“信任服务器证书”

需要 SQL 密码时，在已登录的服务器终端中查看：

```bash
cat ~/.config/database-lab/sa-password
```

本地端口 `14330` 只是一条隧道入口；数据库在服务器上仍监听 `127.0.0.1:1433`。如果本机 `14330` 已被占用，可把命令和客户端地址中的 `14330` 同时换成其他未占用端口。

## 状态检查和常用运维

登录服务器：

```powershell
$ServerAddress = '<向管理员获取>'
$ServerUser = '<向管理员获取>'
$ServerSshPort = '<向管理员获取>'
ssh -p $ServerSshPort "${ServerUser}@${ServerAddress}"
```

查看容器状态、最近日志和端口绑定：

```bash
docker ps --filter name=database-lab-sqlserver
docker logs --tail 100 database-lab-sqlserver
docker port database-lab-sqlserver
```

正常端口输出应为 `127.0.0.1:1433`。按需重启数据库：

```bash
docker restart database-lab-sqlserver
```

重启后 SQL Server 会先恢复系统库和业务库。容器显示 `Up` 不代表业务库已经完成恢复，应稍等后再连接。不要删除容器所用的 `database-lab-sql-data` 卷；删除该卷会丢失数据库文件。

服务器上的部署文件和日志位于：

```text
$HOME/database-lab-deploy
$HOME/database-lab-deploy/logs
$HOME/database-lab-deploy/week4
```

## 验证数据库

进入服务器后，可直接在容器内执行仓库的验证脚本：

```bash
read -r DBPASS < ~/.config/database-lab/sa-password
docker cp "$HOME/database-lab-deploy/04-verify.sql" \
  database-lab-sqlserver:/tmp/database-lab-verify.sql
docker exec database-lab-sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$DBPASS" -C -I -b -r1 -f 65001 \
  -d DataBaseLab_Week4 \
  -i /tmp/database-lab-verify.sql
unset DBPASS
```

成功结果应包含：

```text
VERIFY_PASS          15          46
```

`15` 是业务表数，`46` 是样例数据总行数。2026-09-21 的第三周部署通过了 `CRUD_PASS` 和 `CONSTRAINT_TESTS_PASS`（12 项约束测试），并在重启容器后再次得到 `VERIFY_PASS`。2026-09-23 的第四周部署还通过 `CONSTRAINT_PASS`（6 项）、`QUERY_PASS`、`VIEW_PASS` 和 `ROLE_PASS`（17 项），正式日志位于服务器的 `database-lab-deploy/logs/week4-deploy-20260923.log`，仓库副本见[第四周服务器部署日志](../result/week4-server-deploy.txt)。

## 重新导入时的注意事项

仓库的 [`00-create-database.sql`](../sql/week3/00-create-database.sql) 为 Windows LocalDB 编写，会解析反斜杠文件路径，不能直接用于 Linux 容器。服务器上新建空库时使用普通的 `CREATE DATABASE [数据库名]`，然后按以下顺序执行：

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

Linux 容器内执行 SQL 文件必须使用 `sqlcmd -I -f 65001`：

- `-I` 启用 `QUOTED_IDENTIFIER`，筛选唯一索引需要该设置。
- `-f 65001` 按 UTF-8 读取中文 SQL 文件。
- `-b` 让 SQL 错误产生非零退出码，部署脚本才能停止。
- `-C` 信任当前容器的服务器证书。

`01-schema.sql` 只接受空数据库，`02-seed.sql` 不会覆盖已存在的数据。不要为了重跑脚本直接删除未知数据库或持久化卷；先核对目标库、备份数据，再使用新的数据库名或明确制定迁移方案。

## 已知问题与边界

- SSH 服务偶尔返回 `Exceeded MaxStartups`，表现为输入密码前连接就被关闭。这是服务器未认证连接数限流，不是密码错误；降低重试频率，稍后重新连接。
- 当前只配置了 Docker 卷持久化，尚未配置定时 `.bak` 备份和异机备份。存入不可重新生成的数据前，应先补充备份方案。
- 当前使用 `sa` 便于课程实验。若用于长期共享或接入应用，应创建最小权限账号，不应让应用使用 `sa`。
- 第三、第四周数据库用于实验和演示，跨表业务规则、并发事务和生产级权限边界仍以 [Week3](Week3.md) 与 [Week4](Week4.md) 的说明为准。
