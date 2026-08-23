# 会前 Workflow 与 README 发布计划

## 目标

在会议展示前，把 production BDS 的测试与可复现实验入口发布到 GitHub `main`
分支，并确保 README 中展示的 workflow 在真实 GitHub Actions 环境中取得绿色状态。

本计划区分三种不同证据：

1. 本地静态检查证明 YAML、shell 和实验协议没有明显错误；
2. MATLAB 服务器检查证明 BDS、termination、acceleration 和 profile label 行为正确；
3. GitHub Actions 实际运行证明 checkout、外部 solver、MATLAB Actions、LaTeX、artifact
   上传和合并在 Ubuntu runner 上可以工作。

只有第三项通过后，README badge 才能作为绿色发布状态展示。

## 最终 Workflow 清单

### Competitor profiles：8 个

全部只使用 S2MPJ，不保留 MatCUTEst 和 large：

- BFO：small（1–5）和 big（6–50）；
- NOMAD：small（1–5）和 big（6–50）；
- NEWUOA：small（1–5）和 big（6–50）；
- 不提供梯度的 BFGS：small（1–5）和 big（6–50）。

每个 workflow 继续保持一对一比较，不把四个 competitors 放入同一个 benchmark。
每个 feature 独立运行，并由 downstream job 自动合并 artifacts。

### BDS capabilities：4 个

- acceleration small：三项 acceleration 全关与全开；
- acceleration big：三项 acceleration 全关与全开；
- termination big：function-only、gradient-only 和 combined；
- invalid-function-evaluation big：production BDS 与 simplified BDS。

前三个 workflow 的正式 feature 清单为：

`plain`、`noisy_1e-1`、`noisy_1e-2`、`noisy_1e-3`、`noisy_1e-4`、
`permuted`、`linearly_transformed`、`rotation_noisy_1e-1`、
`rotation_noisy_1e-2`、`rotation_noisy_1e-3`、`rotation_noisy_1e-4`。

Invalid-function-evaluation 使用：

`random_nan_5`、`random_nan_10`、`random_nan_20`。

## 清理范围

- 删除全部 `profile_bds_*_matcutest.yml`；
- 删除全部 `profile_bds_*_large_s2mpj.yml`；
- 不删除 `profile_optiprofiler.m` 中通用的 large 支持；
- 保留当前 production correctness/maintenance workflows；
- 12 个实验 workflow 正式版本默认只允许手动触发，不保留月度 schedule。

## 统一实验协议

- small workflow 显式传入 `mindim = 1`、`maxdim = 5`；
- big workflow 显式传入 `mindim = 6`、`maxdim = 50`；
- 不通过现有 `options.dim = "big"` 间接获得 6–20；
- 问题库显式为 `s2mpj`；
- production BDS 使用 `500*n`、`expand = 2.0`；
- competitor workflow 保持既定的 26-feature comparison matrix；
- capability workflow 保持已经批准的 11/3-feature matrix；
- artifact 名称必须包含 comparison、size、feature 和 problem library；
- 每个 workflow 必须有独立 merge job，并上传 merged profiles 和 summary bundle。

## README 发布结构

README 按以下顺序整理：

1. `What is BDS?`；
2. `How to install BDS?`；
3. production capabilities：acceleration、termination、automatic initial step size、
   invalid-function-evaluation handling；
4. `Tests and reproducible benchmarks`。

Tests 部分包含：

- GitHub Actions 总入口；
- production regression 等核心 correctness workflow；
- 8 个 competitor profiles；
- 4 个 capability workflows；
- 每个重要 workflow 使用唯一名称和指向 `main` 的状态 badge，不能全部用无法区分的
  `Tests` 名称。

在写入 badge 前必须核实 repository canonical URL。用户指定的公开入口是
`https://github.com/bladesopt/bds`；本地旧 remote 仍显示
`blockwise-direct-search/bds`，需先确认是否为重定向或组织迁移。

## 本地 Git remote 配置

`.git/config` 是本地配置，不会被 commit。发布前必须使 `origin` 明确指向公开的
canonical repository：

`git@github.com:bladesopt/bds.git`

用户给出的参考配置在同一个 `origin` 中重复写入多个 `url`。这种写法不能清楚表达
“从哪里 fetch”和“向哪里 push”，也可能让一次普通 push 产生不易察觉的目标选择。
正式配置采用以下结构：

- `origin` 只负责 `bladesopt/bds` 的 fetch/push；
- 其余 GitHub/Gitee repositories 分别建立有意义的独立 remote；
- 逐个用 `git ls-remote` 验证 repository 存在和 SSH/HTTPS 访问；
- 不为 `origin` 配置一组自动 multi-push `pushurl`，避免一个普通
  `git push origin` 同时修改多个组织；
- 如确实需要镜像，同步命令必须显式指定目标 remote。

候选 mirrors 来自用户给出的列表：

- `blockwise-direct-search/bds`；
- `0thopt/bds`；
- `opt-lab/bds`；
- `derivative-free-optimization/bds`；
- `dfopt/bds`；
- `gradient-free-opt/bds`；
- `gradient-free-optimization/bds`；
- `libblades/bds`；
- `optimlib/bds`；
- `zeroth-order-optimization/bds`；
- `https://gitee.com/Lht97/bds.git`。

只把验证可访问的 repository 写入独立 remote。修改前保存当前 local config 内容；
修改后核对 `git remote -v`、`git remote get-url origin`、fetch refspec 和当前分支的
upstream，确保 `main` 最终跟踪 `origin/main`。

## 验证与发布 Gates

### Gate A：本地协议与语法

- YAML parser 检查全部保留 workflow；
- `actionlint` 检查全部 GitHub Actions 文件；
- shell `bash -n` 和 artifact helper tests；
- workflow contract 检查精确文件清单、S2MPJ、维数、features、solver labels、
  trigger 和 merge/upload 结构；
- `git diff --check` 和无意外文件检查。

### Gate R：Repository 与认证

- 确认 `bladesopt/bds` 是 README 和 badge 使用的 canonical repository；
- 按“一个 repository 一个 remote”的结构更新 `.git/config`；
- 验证 `origin` fetch/push URL、`main` upstream 和 SSH push 权限；
- 修复失效的 GitHub CLI 登录，或使用已有 GitHub browser session 完成 PR 操作；
- 在任何外部写入前打印并复核精确 repository、branch 和 commit。

### Gate B：MATLAB 服务器

- `verify_bds_benchmark_workflows`；
- `verify_profile_workflow_mappings`；
- `run_bds_regression_suite`；
- BFO、NOMAD、NEWUOA 和不提供梯度的 BFGS 使用真实 wrapper 的小问题 smoke test；
- 验证使用隔离工作树，不覆盖服务器已有实验改动。

### Gate C：GitHub branch smoke

- 从当前 `main` 创建专用发布分支；
- 临时给 12 个 workflow 加仅匹配验证分支的 `push` trigger；
- competitor/capability workflow 各运行一个代表性 feature；
- big smoke 临时收敛到最小 big 维数，invalid smoke 使用 `random_nan_5`；
- 监控真实 Actions，逐项修复 checkout、编译、MATLAB、LaTeX 和 artifact 问题；
- 12 个 branch smoke 全绿后才进入 Gate D。

### Gate D：正式版本与 PR

- 删除临时 push trigger 和 smoke-only matrix；
- 恢复完整正式 feature/dimension matrix；
- 重新执行 Gate A 和 Gate B；
- 提交、push 并创建 PR，请求 `zaikun zhang` review；
- 等待现有 PR correctness checks 全绿；
- 合并前核对 README links、badge filenames 和 workflow 文件清单。

### Gate E：`main` 正式运行

- 合并后从 `main` 手动触发 12 个正式实验 workflow；
- 持续监控至全部结束；
- 失败时读取 logs、在发布分支修复、重新验证并合并；
- 所有 README 对应 badge 绿色后记录 run URLs 和完成时间；
- 下载并抽查每类至少一个 merged artifact 和 summary artifact。

## 执行清单

- [x] 1. 固定最终 workflow 范围和发布原则。
- [ ] 2. 核验 GitHub canonical repository、推送权限和认证方式，并更新 `.git/config`。
- [ ] 3. 删除 MatCUTEst 与 large workflow。
- [ ] 4. 统一 8 个 competitor workflow 的 S2MPJ small/big 协议。
- [ ] 5. 复核 4 个 capability workflow。
- [ ] 6. 扩展并通过本地 workflow contract、YAML、actionlint 和 shell tests。
- [ ] 7. 重构 README 并加入正式 Actions 入口与 badges。
- [ ] 8. 通过隔离服务器 MATLAB regression 和真实 wrapper smoke。
- [ ] 9. 创建并推送 GitHub validation branch。
- [ ] 10. 运行并修复 12 个 branch smoke，直到全部绿色。
- [ ] 11. 恢复正式矩阵并重新通过本地与服务器 Gates。
- [ ] 12. 创建 PR、等待 correctness checks 并完成合并。
- [ ] 13. 从 `main` 触发 12 个正式 workflows 并监控到绿色。
- [ ] 14. 抽查 artifacts、更新完成记录并确认 README 最终展示。

## 边界

- 不直接向 `main` 做未经 Actions smoke 的提交；
- 不覆盖服务器 `~/Work/bds` 中已有的脏工作树；
- 不将 branch smoke 的缩小问题集冒充正式 benchmark；
- 不在 README 中把“workflow 文件存在”等同于“完整实验已经通过”；
- 不恢复 MatCUTEst、large 或未批准的 competitor workflows。
