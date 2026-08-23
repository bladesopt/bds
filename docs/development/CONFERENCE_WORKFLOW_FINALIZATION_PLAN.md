# 会前 GitHub Actions 最终整理与发布计划

## 目标

在会议展示前，把 BDS 仓库的公开 GitHub Actions 页面和 README 整理成一个
清晰、可验证的入口：保留现有 correctness/maintenance baseline；公开四组
competitor comparisons；公开 acceleration、termination 和 invalid-function-
evaluation experiments；删除本轮恢复范围内的 MatCUTEst 和 large benchmark
workflow；并让 README 中出现的 workflow 在 GitHub Actions 上取得真实运行状态。

本文档是本轮执行的唯一 checklist，并取代尚未完成的
`CONFERENCE_WORKFLOW_RELEASE_PLAN.md` 中与本轮范围或 remote 配置冲突的安排。

## 最终保留范围

### Correctness/maintenance baseline

保留当前 `main` 已有的十个 workflow：

- `bds_regression_test.yml`；
- `gradient_test.yml`；
- `parallel_test.yml`；
- `recursive_test.yml`；
- `spell_check.yml`；
- `spelling.yml`；
- `stress_test.yml`；
- `unit_test.yml`；
- `verify_norma.yml`；
- `verify_simplified_bds.yml`。

这里的“只保留 S2MPJ”针对本轮恢复或新建的 profile/benchmark workflow，
不是删除已经在 `main` 上承担 correctness 职责的 baseline workflow。

### Competitor comparisons

每个 workflow 只比较 production BDS 与一个 comparison solver，不建立把所有
solver 塞到同一运行中的总 workflow：

- BFO：small 和 big；
- NOMAD：small 和 big；
- NEWUOA：small 和 big；
- BFGS without supplied gradients：small 和 big，必须调用
  `tests/competitors/fminunc_wrapper.m`。

以上八个 workflow 只使用 S2MPJ：small 为维数 1--5，big 为维数 6--50。
不保留对应的 MatCUTEst 或 large YAML。每个 feature 独立生成 artifact，同一
comparison 内由 downstream job 自动合并。

### BDS capability experiments

- acceleration small：比较三项 acceleration 全关与全开；
- acceleration big：比较三项 acceleration 全关与全开；
- termination big：比较 function-only、gradient-only 和 combined；
- invalid-function-evaluation big：比较 production BDS 与 simplified BDS。

Acceleration 和 termination 使用且仅使用：

`plain`、`noisy_1e-1`、`noisy_1e-2`、`noisy_1e-3`、`noisy_1e-4`、
`permuted`、`linearly_transformed`、`rotation_noisy_1e-1`、
`rotation_noisy_1e-2`、`rotation_noisy_1e-3`、`rotation_noisy_1e-4`。

Invalid-function-evaluation 使用且仅使用：

`random_nan_5`、`random_nan_10`、`random_nan_20`。

Production BDS 的公共实验设置包括 `MaxFunctionEvaluations = 500*n` 和
`expand = 2.0`。

## 本地 Git 配置

`.git/config` 不会进入 Git commit，但必须在本机正确配置。用户提供的仓库列表
全部纳入 `origin` 的多目标配置：

- GitHub：`blockwise-direct-search`、`0thopt`、`bladesopt`、`opt-lab`、
  `derivative-free-optimization`、`dfopt`、`gradient-free-opt`、
  `gradient-free-optimization`、`libblades`、`optimlib`、
  `zeroth-order-optimization` 下的 `bds`；
- Gitee：`Lht97/bds`。

实现时必须先用本地临时仓库确认 Git 对多个 `url` 与多个 `pushurl` 的行为，再采用
语义明确且能满足多仓库使用需求的配置。Canonical fetch URL 保持唯一；各目标的
push 行为必须可以用 `git remote get-url --all --push origin` 明确审计。修改前保存
当前值，修改后验证 fetch refspec、当前分支及 `main` 的 tracking 配置。任何真实
push 前都再次打印精确目标，避免误推。

## README 发布要求

README 的顺序保持为：

1. `What is BDS?`；
2. `How to install BDS?`；
3. production capabilities：acceleration、termination、automatic initial step
   size、invalid-function-evaluation handling；
4. tests and reproducible benchmarks。

README 必须为 baseline、八个 competitor workflow 和四个 capability workflow
给出可辨识的名称、准确文件链接和指向 `main` 的 status badge。README 中不得把
“本地检查通过”表述成“GitHub Actions 已绿色通过”。

## 验证 Gates

### Gate A：文件范围与静态检查

- 精确核对 10 + 8 + 4 个最终 workflow 文件；
- 确认不存在本轮 profile/benchmark 的 MatCUTEst 或 large YAML；
- YAML parser 验证全部 workflow；
- `actionlint` 验证全部 workflow；
- `bash -n` 与 artifact helper behavior tests；
- contract tests 验证 problem library、维数、features、solver labels、预算、
  `expand`、trigger 及 merge/upload 结构；
- README badge 文件名与实际 YAML 一一对应；
- `git diff --check`。

### Gate B：MATLAB 服务器

使用服务器上的隔离副本，不覆盖 `~/Work/bds` 可能存在的工作：

- `verify_bds_benchmark_workflows`；
- `verify_profile_workflow_mappings`；
- `run_bds_regression_suite`；
- BFO、NOMAD、NEWUOA 和 BFGS wrapper 的可用性/smoke 检查；
- acceleration 全关与 reference、全开与 lean implementation 的等价性，以及
  gradient stopping tests，必须由 regression suite 的输出明确证明。

### Gate C：GitHub Actions smoke

- 在专用 validation branch 上为十二个新 workflow 使用受控的临时 smoke 输入；
- competitor 和 capability 的每一种 workflow 结构都必须在真实 GitHub runner
  上覆盖；
- 检查外部 solver 安装、MATLAB Actions、S2MPJ、LaTeX/PDF、artifact upload 和
  merge；
- 失败必须依据日志修复并重跑，不能只在 README 中隐藏 badge。

### Gate D：正式发布

- 恢复十二个 workflow 的完整正式 feature/dimension matrix；
- 重新通过 Gate A 和 Gate B；
- 创建 PR 并请求 `zaikun zhang` review；
- 合并后从 `main` 手动触发十二个正式 workflow；
- 监控到全部结束，记录 run URL，抽查 merged artifacts；
- 只有真实成功的 workflow 才记为绿色完成。

## 执行清单

- [x] 1. 盘点当前分支、工作区、现有 workflow、README 和 local Git remote。
- [x] 2. 固定本轮最终范围、验证层次和发布原则。
- [x] 3. 清理 MatCUTEst/large benchmark YAML，核对最终 10 + 8 + 4 文件清单。
- [x] 4. 审核并完善八个 S2MPJ competitor workflows。
- [x] 5. 审核并完善四个 BDS capability workflows。
- [x] 6. 审核 `profile_optiprofiler.m`、wrappers、artifact helpers 和 contract tests。
- [x] 7. 按照已确认结构完善 README 及全部 badge。
- [x] 8. 更新 `.git/config` 的多仓库配置并只读验证本地生效配置。
- [x] 9. 通过 Gate A 的全部本地检查。
- [x] 10. 通过 Gate B 的服务器 MATLAB 检查。
- [ ] 11. 创建受控 GitHub validation branch，执行并修复 Gate C smoke。
- [ ] 12. 恢复正式矩阵，重新通过 Gate A/Gate B，创建并合并 PR。
- [ ] 13. 在 `main` 运行十二个正式 workflow，监控至绿色并抽查 artifacts。
- [ ] 14. 回填 run URL、完成时间和最终状态，归档阶段性计划。

## 完成记录

### Gate A

- 最终 workflow 文件集合精确为 10 个 baseline、8 个 competitor 和 4 个
  capability，共 22 个；八个 competitor 文件全部是 S2MPJ small/big，不存在
  MatCUTEst 或 large profile YAML。
- Ruby/Psych 成功解析全部 22 个 YAML；`actionlint 1.7.12` 对全部文件零诊断。
- artifact helpers 通过 `bash -n`、ShellCheck 0.11.0 和
  `test_strip_profile_timestamp.sh`。
- README 中 22 个 workflow 各有且仅有一组 badge URL 和 workflow link；不存在
  漏项或悬空文件名。
- `git diff --check` 通过。

### Local Git configuration

- 用两个本地 bare repositories 实测：同一 remote 的多个 `url` 会成为多个有效
  push targets；一次 push 会依次更新全部目标。
- `.git/config` 已按用户清单配置 12 个唯一 URL；重复的
  `blockwise-direct-search/bds` 没有重复写入。
- 默认 fetch URL 为 `git@github.com:blockwise-direct-search/bds.git`；
  `git remote get-url --all --push origin` 显示全部 11 个 GitHub 目标和 1 个 Gitee
  目标。
- 修改前的本地配置备份为
  `/private/tmp/bds-git-config-before-multi-url-20260823`。

### Gate B

- 服务器 MATLAB R2026a 的隔离副本输出
  `BDS_BENCHMARK_WORKFLOWS_OK`、`PROFILE_WORKFLOW_MAPPINGS_OK` 和
  `BDS_REGRESSION_SUITE_OK`。
- regression suite 明确通过 function-value/gradient stopping tests、acceleration
  全关的 270-case frozen-reference 等价检查，以及 acceleration 全开的两组
  630-case lean-reference 等价检查。
- 使用真实 Optimization Toolbox 的 `fminunc_wrapper.m` 无梯度 BFGS smoke 通过。
- 服务器没有预装 BFO、NOMAD 或 NEWUOA，因此三者的真实安装/运行必须由 Gate C
  的 GitHub runner smoke 覆盖；mapping contract 已通过，但不把 stub test 记作
  真实 solver smoke。
- 隔离目录 `/tmp/bds-conference-workflows.vz0Im6` 已在验证后删除。

### Canonical public repository

- GitHub API 确认 README 指定的 `bladesopt/bds` 是公开 fork，默认分支为 `main`。
- 验证时 `bladesopt/main` 仍为 `81c3ef7b`，而上游、本地 `main` 和本地工作分支的
  基线为 production commit `988b2629`；本轮 PR 必须把 production 基线与新
  workflows 一并带到 `bladesopt/main`，否则 README badges 不会对应当前代码。

后续仍需逐项完成 Gate C、正式 PR/main runs 和 artifacts 抽查；不得预先勾选。
