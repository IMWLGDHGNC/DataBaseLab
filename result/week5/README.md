# 第五周 ER 模型与验证结果

最新结果见 [2026-10-01 review 修复验证](review-validation-20261001.md)：具体目录与图源核对、7项检查器反例、9项业务探针及34项权限案例通过。第五周按用户授权合入 main。以下保留最初交付与同步阶段的历史结果。

2026-09-30 基于当时的 v0.1（17 项权限案例），在独立 SQL Server 2022 LocalDB 库 `DataBaseLab_Week4_W520260930194047` 执行。设计说明与运行命令见 [Week5](../../docs/Week5.md)。

| 结果 | 说明 |
| --- | --- |
| [baseline-run.txt](baseline-run.txt) | 最新第三、四周脚本从空库完整执行，WEEK4_PASS |
| [er-verification.txt](er-verification.txt) | 15 表、107 属性、25 外码的目录、多商品／会员／普通顾客和库存查询，9 项回滚探针及 WEEK5_ER_PASS |
| [after-probes.txt](after-probes.txt) | 探针回滚后原复核：15 表、46 行及逐表数据哈希 |
| [model-check.txt](model-check.txt) | 实际目录／DDL／图源逐字段和码核对、Word 原文保留、15表哈希一致及本周链接检查 |
| [完整 PNG](er-v0.1.png) / [SVG](er-v0.1.svg) | 全部实体与属性；4200 像素宽；演示时优先放大 SVG |
| [采购 PNG](er-purchase.png) / [SVG](er-purchase.svg) | 类别、商品、供应商、采购头／行、经办员工和入库批次 |
| [销售 PNG](er-sales.png) / [SVG](er-sales.svg) | 顾客、会员身份、销售头／行、支付和积分 |
| [库存 PNG](er-stock.png) / [SVG](er-stock.svg) | 商品追溯、批次锁定、实物流水、员工和异常 |

图源位于 [docs/week5](../../docs/week5/er-model.md)，使用 Mermaid 11.12.0 渲染为 SVG 并在浏览器导出 PNG。图是 ER 模型导出，不是 SQL 管理界面截图。日志来自实际运行，不是构造的预期输出。探针接受的不完整业务用于证明约束边界，每例已回滚。

## 2026-10-01 同步复验

同步阶段提交修订后的 main，34 项权限及 9 项 ER 边界探针均通过；业务表保持 15 张、107 属性，权限辅助表单独计数。详情与新日志见[同步验证](sync-validation-20261001.md)。本次同步时的待审核状态保留在历史验证说明中；后续 review 修复与用户合并授权见下方最新记录。
