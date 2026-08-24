# README 与 GitHub Actions 调度完善计划

## 目标

在不改变 solver、benchmark 配置或 artifact 结构的前提下，完善 README 对公开
仓库、invalid function evaluation 机制与 S2MPJ 的说明，并把 GitHub Actions
划分为两类：六个核心检查在每次 push 时运行，其余 correctness/maintenance 与
S2MPJ 实验按每月一天一个的方式错峰运行。所有按月运行的 workflow 继续支持
`workflow_dispatch`，方便必要时手动重跑。

本轮修改 README、workflow 顶层名称与触发条件，以及受新 schedule 直接影响的
workflow contract test；不修改 solver 或实验参数，不推送代码、不触发远端
workflow，也不请求 reviewer。

## 已确认的设计

### README

- issue 链接指向 canonical repository：
  `https://github.com/blockwise-direct-search/bds/issues`；
- `bladesopt/bds` 继续作为公开实验 workflow、status badge 和 artifacts 的位置；
- Invalid function evaluations 一节引用 `src/private/eval_fun.m` 并展示实际的
  `try`/`catch`、`NaN` 到 algorithmic `Inf` 的转换和 `is_valid` 标记；
- Solver comparisons 第一次出现 S2MPJ 时链接其官方仓库：
  `https://github.com/GrattonToint/S2MPJ`；
- 将实验 workflow 的说明更新为“每月自动运行且仍可手动触发”。

### 每次 push 运行的核心检查

- `bds_regression_test.yml`；
- `unit_test.yml`；
- `gradient_test.yml`；
- `spell_check.yml`；
- `spelling.yml`；
- `verify_norma.yml`。

其中 `unit_test.yml` 不再每日定时运行，`spell_check.yml` 不再用 paths filter
限制 push。`spelling.yml` 原有的 `pull_request_target` 和 `issue_comment` 触发及
相关逻辑保持不变。

### 每月错峰运行的其余 workflow

所有 cron 均使用 `0 18 D * *`，即在每月第 `D` 天 18:00 UTC 启动；对应北京时间
通常为次日 02:00。完整接力顺序为：

| UTC 日期 | Workflow |
| --- | --- |
| 1 | `stress_test.yml` |
| 2 | `parallel_test.yml` |
| 3 | `recursive_test.yml` |
| 4 | `verify_simplified_bds.yml` |
| 5 | `profile_bds_bfo_small_s2mpj.yml` |
| 6 | `profile_bds_bfo_big_s2mpj.yml` |
| 7 | `profile_bds_nomad_small_s2mpj.yml` |
| 8 | `profile_bds_nomad_big_s2mpj.yml` |
| 9 | `profile_bds_newuoa_small_s2mpj.yml` |
| 10 | `profile_bds_newuoa_big_s2mpj.yml` |
| 11 | `profile_bds_bfgs_no_gradient_small_s2mpj.yml` |
| 12 | `profile_bds_bfgs_no_gradient_big_s2mpj.yml` |
| 13 | `benchmark_bds_acceleration_small.yml` |
| 14 | `benchmark_bds_acceleration_big.yml` |
| 15 | `benchmark_bds_termination_big.yml` |
| 16 | `invalid_function_evaluation_test.yml` |

八个 solver-comparison workflow 的顶层 `name:` 将 `s2mpj` 统一为 `S2MPJ`；
文件名和内部 solver/feature/artifact 标识不改，以保持现有链接和运行契约稳定。

## 验证要求

- 全部 workflow 能被 YAML parser 解析；
- 若本机已有 `actionlint`，对全部 workflow 运行并要求零诊断；
- 精确验证六个核心 workflow 均有 `push`；
- 精确验证其余十六个 workflow 的 cron 日期为 1--16 且没有重复；
- 精确验证所有按月运行的 workflow 仍有 `workflow_dispatch`；
- 确认八个 comparison workflow 顶层 `name:` 使用 `S2MPJ`；
- 确认 README 的链接、代码示例和调度说明与实际文件一致；
- 运行仓库现有的 workflow contract tests（若不依赖本机 MATLAB）；
- 若旧 contract 与新 schedule 冲突，更新 contract 并在服务器 MATLAB 的隔离
  副本中运行相关测试；
- `git diff --check` 通过，并人工审阅最终 diff 与文件范围。

## 执行清单

- [x] 1. 盘点工作区、README、22 个现有 workflow 及其触发条件。
- [x] 2. 固定 README 内容、六个 push checks 和 1--16 日月度接力表。
- [x] 3. 完善 README 的 issue、invalid evaluation、S2MPJ 和调度说明。
- [x] 4. 调整六个核心 workflow 的 push 触发。
- [x] 5. 调整其余十六个 workflow 的月度错峰调度。
- [x] 6. 统一八个 solver-comparison workflow 的 `S2MPJ` 显示名称。
- [x] 7. 完成 YAML、contract、README、diff 和工作区验证。

## 完成记录

- README 已改用 canonical issue URL，加入 `eval_fun.m` 的真实 invalid-
  evaluation 处理代码和说明，补充 S2MPJ 官方链接，并准确描述 push checks、月度
  workflow 与手动重跑之间的关系。
- 六个且仅六个核心 workflow 具有 active `push` trigger；Unit tests 的每日 cron
  已删除，TeX/Bib spelling 的 paths filter 已删除，MATLAB spelling 原有的 PR 与
  issue-comment 机制保持不变。
- 其余十六个 workflow 的 cron 精确覆盖 UTC 每月 1--16 日，每天一个且无重复；
  全部仍有 `workflow_dispatch`。
- 八个 competitor workflow 的顶层 `name:` 已统一使用 `S2MPJ`；文件名、内部
  solver labels、features、budgets 和 artifact 结构均未修改。
- 发现并修复了旧 MATLAB contract 对实验 workflow 使用
  `assert(~contains(..., 'schedule:'))` 的过时要求；新 contract 精确验证各 workflow
  的预定日期，避免 Production BDS regression 在下一次 push 时因旧断言失败。
- Ruby/Psych 成功解析全部 22 个 YAML；`actionlint` 对全部 workflow 零诊断；本地
  trigger contract 得到 `WORKFLOW_TRIGGER_CONTRACT_OK`，README contract 得到
  `README_CONTRACT_OK`，`git diff --check` 通过。
- 在服务器 MATLAB 的 `/tmp` 隔离副本中运行完整 `run_bds_regression_suite`，得到
  `BDS_BENCHMARK_WORKFLOWS_OK`、`PROFILE_WORKFLOW_MAPPINGS_OK`、全部梯度停机检查
  成功、加速全关/全开等价性成功，以及最终的 `BDS_REGRESSION_SUITE_OK`。
- 服务器隔离目录 `/tmp/bds-workflow-schedule.xpDKbb` 已在验证后删除；服务器原有
  `~/Work/bds` 未被修改。本轮没有 push、没有触发远端 GitHub Actions，也没有
  请求 reviewer。
