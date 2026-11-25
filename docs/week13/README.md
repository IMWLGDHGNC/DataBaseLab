# 第13周 并发控制

以两条独立 SQL Server 会话观察锁等待、隔离现象和死锁，更新出库与入库的库存访问顺序，并在真实数据库过程上复测。课程原文见[第十三周任务讲解](../course/第十三周任务讲解.md)，逐步实测见[结果](../../result/week13/README.md)。阶段对象和报告写作入口见[第三阶段报告](../reports/第三阶段报告.md)。

## 准备独立样例库

按[本地 SQL 环境](../guides/本地SQL环境.md#第13周与第三阶段复现)创建新库并按第10、11、12周脚本安装。当前的 `procedure.sql` 和 `restock_transaction.sql` 已包含本周改进。Windows 自动重放运行 `python tests/Test-Week13.py`，执行的步骤来自下列同一批 SQL 文件，两个连接分别持有 A、B 事务，另开一个连接采集 DMV。输出位于 `output/week13/`，复跑完整测试时用新样例库。

## 手工重放库存锁实验

1. 将三个窗口连到同一独立样例库。在观察窗口执行 [setup.sql](../../sql/week13/setup.sql)，再执行 [state.sql](../../sql/week13/state.sql) 检查 P=10、Q=8、订单待完成、补货单已批准。实验表用商品主键代表该商品的单一库存记录，`Document` 记录订单和补货的终态。这样可单独观察库存键锁，避开应用锁和入库新批次的影响。
2. 在 A、B 各执行 [session.sql](../../sql/week13/session.sql)，确认不同 `@@SPID`，记录 SQL Server 版本、初始 `READ COMMITTED` 和 RCSI 设置。观察窗口在 [observe.sql](../../sql/week13/observe.sql) 填入该轮 SPID。观察 P/Q 的锁键时可在事务开始前运行 `SELECT ProductID, %%lockres%% FROM week13_lab.Stock;`。
3. 只选中表中指明的步骤执行。出现“观察”时保留正在等待的查询，到第三个窗口采集锁，再继续非阻塞会话的下一步。手工操作超过 30 秒可以在 A/B 的 `session.sql` 调整 `LOCK_TIMEOUT`，采集到 1222 时按超时处理。
4. 每轮结束在 A、B 分别执行 [cleanup.sql](../../sql/week13/cleanup.sql)，核对 `@@TRANCOUNT=0`、`XACT_STATE()=0`，恢复默认锁等待和 `READ COMMITTED`。在独立窗口读终态后重跑初始化，准备下一轮。

| 场景 | 会话脚本 | 执行顺序与结果 |
| --- | --- | --- |
| 写等待：提交 | [A](../../sql/week13/lock_wait_A.sql) · [B](../../sql/week13/lock_wait_B.sql) | A1 → B1（等待）→ 观察 → A2 → B1 返回 → B2。P=13，订单完成，补货已入库 |
| 写等待：回滚 | 同上 | A1 → B1（等待）→ 观察 → A3 → B1 返回 → B2。P=15，订单仍待完成，补货已入库 |
| 脏读与已提交读 | [A](../../sql/week13/dirty_read_A.sql) · [B](../../sql/week13/dirty_read_B.sql) | A1 → B1 读 15 → A2 回滚，P=10。重置后 A1 → B2，RCSI 关时先观察等待，A2 后 B2 读 10。RCSI 开时 B2 直接读 10，随后 A2 |
| 强制锁式读 | 同上 | 重置后 A1 → B3（`READCOMMITTEDLOCK`）→ 观察 → A2 → B3 读 10 |
| 不可重复读 | [A](../../sql/week13/repeatable_read_A.sql) · [B](../../sql/week13/repeatable_read_B.sql) | A1 读 10 → B1 补货并提交 → A2 重读 15 |
| 可重复读 | 同上 | A3 读 10 → B1（等待）→ 观察 → A4 重读 10 并提交 → B1 返回，终态 P=15 |
| 反序死锁 | [A](../../sql/week13/deadlock_A.sql) · [B](../../sql/week13/deadlock_B.sql) | A1 持 P → B1 持 Q → A2 请求 Q（等待）→ 观察 → B2 请求 P，因较低优先级收到 1205 → A2 返回 → A3 提交。P=8、Q=6，补货单仍已批准 |
| 统一顺序 | [A](../../sql/week13/ordered_A.sql) · [B](../../sql/week13/ordered_B.sql) | A1 持 P → B1 请求 P（等待）→ 观察 → A2 更新 Q 并提交 → B1 返回 → B2 完成。P=13、Q=11，两笔业务均提交 |

观察其他会话的权限依 SQL Server 环境而定。无 DMV 权限时可由助教在第三窗口采集。RCSI 用数据库当前值，两个隔离级别对照使用各自会话设置。可重复读保留已读取键的共享锁，范围内的新行仍可能产生幻读。

## 真实业务过程和回归

- [订单完成](../../sql/week10/procedure.sql)按商品编号和批次编号升序逐项获取锁与扣减。对每批先锁商品主键，再检查批次归属、质量、有效期及预留总量。转出库该批预留后，用带库存条件的更新扣货并核对影响行数。单据、流水、审计和积分仍一起提交。
- [采购入库](../../sql/week12/restock_transaction.sql)沿用单商品整单入库，确认采购单身份和批准数量后锁定同一商品主键，再写入新批次、审计、入库流水及收货状态。两个过程沿用 Web 与独立 SQL 调用共用的事务级应用锁 `DataBaseLab.WebWrite`，有外层事务时由调用者提交或回滚。
- 实际订单与入库等待对照先运行 [business_wait_setup.sql](../../sql/week13/business_wait_setup.sql)。在 [A](../../sql/week13/business_wait_A.sql)、[B](../../sql/week13/business_wait_B.sql) 和[终态查询](../../sql/week13/business_wait_state.sql)中使用同一轮次 `C` 或 `R`。A1 完成过程写入并持有外层事务，启动 B1 后观察应用锁等待。C 轮用 A2 提交，B1 继续后两个批次共 8+5=13。R 轮用 A3 回滚，B1 继续后两个批次共 10+5=15。两轮使用不同模拟商品，各自期初 10 件。
- 两笔 P×6 的订单用 [business_setup.sql](../../sql/week13/business_setup.sql) 初始化。[A](../../sql/week13/business_race_A.sql) 的订单先持有合法预留，[B](../../sql/week13/business_race_B.sql) 的第二个预留在测试事务中临时插入，用于让真实出库过程核查库存不足。A1 → B1 等待 → 观察 → A2 → B1 返回 51804，B 的临时预留被回滚。[终态查询](../../sql/week13/business_state.sql)检查 P=4，只有 A 有完成时间、出库流水、审计和积分。正常 Web 下单已在预留入口拒绝超额数量。
- 复跑 [Test-Week12.py](../../tests/Test-Week12.py) 的两项正常提交、写入后失败回滚、重复调用及业务拒绝证据。更早的对象、窗口及 Web 回归入口见[第三阶段复现顺序](../guides/本地SQL环境.md#第13周与第三阶段复现)。

自动验证见[结果页](../../result/week13/README.md)。课程服务器和组员人工审核待确认。可核实的提交贡献见[组内分工](../submission/组内分工.md)。
