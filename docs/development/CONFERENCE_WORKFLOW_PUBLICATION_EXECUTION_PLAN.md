# 会前 Workflow 最终发布执行清单

## 目标

在 2026-08-23 至 2026-08-24 完成会议展示前的最终发布：把已经通过 GitHub runner smoke 的
S2MPJ workflows、README 说明和 badges 发布到 `main`，再从 `main` 运行完整正式
矩阵并监控结果。整个过程由当前代码负责人完成，不请求 Zaikun Zhang 或其他人
review；合作者明天只需查看最终公开版本。

本文档是本轮发布的唯一执行 checklist。早期恢复、实现和 smoke 过程仍保留在其他
development 文档中作为历史记录，但其中“请求 reviewer”的安排全部作废。

## 最终文件范围

公开的 `.github/workflows` 必须恰好包含以下三类共 22 个文件。

### Correctness/maintenance baseline：10 个

- `bds_regression_test.yml`
- `gradient_test.yml`
- `parallel_test.yml`
- `recursive_test.yml`
- `spell_check.yml`
- `spelling.yml`
- `stress_test.yml`
- `unit_test.yml`
- `verify_norma.yml`
- `verify_simplified_bds.yml`

### S2MPJ competitor comparisons：8 个

- BFO small/big
- NOMAD small/big
- NEWUOA small/big
- BFGS without supplied gradients small/big

Small 使用维数 1--5，big 使用维数 6--50。一个 workflow 只比较 production BDS
与一个 competitor；不恢复 MatCUTEst 或 large YAML。同一 comparison 的不同
features 生成独立 artifacts，并由该 workflow 的 merge job 自动汇总。

### BDS capability experiments：4 个

- acceleration small
- acceleration big
- termination big
- invalid-function-evaluation big

Acceleration 比较三项 acceleration 全关与全开。Termination 比较
function-only、gradient-only 和 combined。Invalid-function-evaluation 比较
production BDS 与 simplified BDS。公共 production 设置包含
`MaxFunctionEvaluations = 500*n` 和 `expand = 2.0`。

## 本机多仓库 Git 配置

`.git/config` 是必须完成但不会进入 commit 的本地发布配置。`origin` 保持唯一的
canonical fetch URL：

`git@github.com:blockwise-direct-search/bds.git`

一次 `git push origin` 使用下列 12 个 push targets：

- `blockwise-direct-search/bds`
- `0thopt/bds`
- `bladesopt/bds`
- `opt-lab/bds`
- `derivative-free-optimization/bds`
- `dfopt/bds`
- `gradient-free-opt/bds`
- `gradient-free-optimization/bds`
- `libblades/bds`
- `optimlib/bds`
- `zeroth-order-optimization/bds`
- `https://gitee.com/Lht97/bds.git`

执行真实 push 前必须再次打印 fetch URL、全部 push URLs、当前 branch、待发布
commit 和工作树状态。若某个镜像失败，应记录已经成功和失败的精确目标，不能在
状态不明时盲目重推。

## 发布原则

- 不请求 Zaikun Zhang review，也不请求其他 reviewer。
- 不恢复 MatCUTEst、large 或未批准的 competitor workflows。
- 不把 branch smoke 的缩减矩阵作为正式实验结果。
- README badge 只链接 `bladesopt/bds` 的 `main` workflow。
- 不声称手动触发的完整矩阵已经绿色，直到对应 `main` run 真实成功。
- 正式 run 失败时读取日志、修复、复验和重跑；不通过删除 badge 掩盖失败。

## 执行 Gates

### Gate A：本地文件与静态验证

- 核对 10 + 8 + 4 个 workflow 文件，确认不存在 profile/benchmark 的 MatCUTEst
  或 large YAML。
- 使用 YAML parser 和 `actionlint` 检查全部 workflows。
- 对 artifact shell helpers 执行 `bash -n`、ShellCheck 和 behavior test。
- 核对 problem library、维数、features、solver labels、`500*n`、`expand=2.0`、
  manual trigger、upload 和 merge contracts。
- 核对 README 的结构、workflow links、badge 文件名和实际 YAML 一一对应。
- 执行 `git diff --check`。

### Gate B：服务器 MATLAB 验证

在服务器临时隔离副本中执行：

- `verify_bds_benchmark_workflows`
- `verify_profile_workflow_mappings`
- `run_bds_regression_suite`
- Optimization Toolbox 的真实无梯度 BFGS wrapper smoke

Regression suite 必须明确通过 acceleration 全关与 frozen BDS reference 的
等价性、全开与 lean reference 的等价性，以及 gradient stopping tests。不得
覆盖服务器 `~/Work/bds` 的现有工作树。

### Gate C：发布 `main`

- 在当前完整正式矩阵上完成 Gate A 和 Gate B。
- 将最终计划与代码提交到当前发布 branch。
- 让本地 `main` fast-forward 到已验证 commit。
- 显式确认 12 个 push targets 后发布 `main`；不创建 reviewer request。
- 核对 `bladesopt/bds` 的公开 `main` commit、README 和 22 个 workflow 文件。

### Gate D：正式 GitHub Actions

- 从 `bladesopt/bds` 的 `main` 手动触发 12 个 competitor/capability workflows。
- 持续监控到所有 runs 结束。
- 确认每个成功 run 都生成 feature artifacts、merged profiles 和 summary bundle。
- 每类至少抽查一个 merged artifact 和 summary artifact。
- 在本文档回填 run URL、结果、artifact 数量和完成时间。

## 执行清单

- [x] 1. 建立本轮独立最终发布计划，废止 reviewer 请求。
- [x] 2. 核对并验证 `.git/config` 的 canonical fetch 与 12 个 push targets。
- [x] 3. 核对最终 22 个 workflow 与 README 展示范围。
- [x] 4. 完成 Gate A 全部本地检查。
- [x] 5. 完成 Gate B 隔离服务器 MATLAB 检查。
- [x] 6. 提交最终计划并再次确认待发布 commit 和所有 push targets。
- [x] 7. fast-forward 并发布 `main`，不请求 reviewer。
- [x] 8. 核对公开 `main` 的 README、workflows 和 commit。
- [x] 9. 从公开 `main` 触发 12 个正式 workflows。
- [x] 10. 监控全部正式 runs，修复任何失败并重跑。
- [x] 11. 抽查正式 artifacts，回填最终证据并完成本计划。

## 已有前置证据

- 临时 validation branch 的 12 个缩减矩阵 smoke runs 已全部成功。
- 每个 smoke run 均产生一个 feature artifact、一个 merged-profiles artifact 和
  一个 summary-files artifact，共 36 个未过期 artifacts。
- smoke 后已经逐文件恢复完整正式 feature/dimension matrices，并再次通过先前的
  Gate A 和 Gate B；本计划仍会在发布前复跑关键检查，防止状态漂移。

## 完成记录

### Local Git configuration

- Canonical fetch URL 为
  `git@github.com:blockwise-direct-search/bds.git`，fetch refspec 为
  `+refs/heads/*:refs/remotes/origin/*`。
- `git remote get-url --all --push origin` 返回计划中的 12 个唯一目标；本地
  `main` 跟踪 `origin/main`。
- 配置已经存在于 `.git/config` 并按上述语义生效；本轮没有把本地配置误加入
  Git commit。

### Gate A

- `.github/workflows` 精确包含 22 个 YAML：10 个 baseline、8 个 S2MPJ
  competitor 和 4 个 capability；不存在 MatCUTEst 或 large profile/benchmark
  YAML。
- 本机 Ruby/Psych 成功解析全部 22 个 YAML；`actionlint` 对全部文件零诊断。
- 四个 artifact shell helpers 全部通过 `bash -n` 和 ShellCheck；
  `test_strip_profile_timestamp.sh` behavior test 通过。
- README 的四个主要部分顺序正确，22 个 workflow 各有且仅有一组 workflow link
  与 `main` badge，不存在漏项或悬空文件名。
- 12 个实验 workflow 全部保留 S2MPJ、manual dispatch、artifact download、三个
  artifact uploads 和独立 merge job；正式维数与 features 的文本检查通过。
- `git diff --check` 通过。

### Gate B

- 在 MATLAB 服务器的隔离目录
  `/tmp/bds-conference-publication.JQiN7f` 中验证，没有修改服务器现有
  `~/Work/bds`。
- `verify_bds_benchmark_workflows` 输出 `BDS_BENCHMARK_WORKFLOWS_OK`；
  `verify_profile_workflow_mappings` 输出 `PROFILE_WORKFLOW_MAPPINGS_OK`。
- Function-value reference 与全部 gradient stopping 专项通过，包括
  `GRADIENT_ESTIMATE_VALIDITY_OK`、`GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK` 和
  `GRADIENT_STOPPING_THRESHOLD_OK`。
- Acceleration 全关与 frozen reference 的 270-case suite 通过；acceleration 全开
  与 `lean_evolved_bds.m` 的 default 和显式 `Algorithm=cbds` 两组 630-case suites
  通过。
- 完整回归输出 `BDS_REGRESSION_SUITE_OK`；真实 Optimization Toolbox 的
  no-gradient `fminunc_wrapper.m` smoke 输出 `BFGS_WRAPPER_SMOKE_OK`。
- 验证完成后已经删除上述隔离临时目录。

### Gate C

- 最终发布计划首先提交为 `96eb4f61`；发布前重新 fetch canonical
  `origin/main`，确认其 commit `988b2629` 是发布 commit 的祖先，允许纯
  fast-forward。
- 本地 `main` 已 fast-forward 到 `96eb4f61`。一次明确的
  `git push origin main:main` 成功更新 `.git/config` 中的全部 12 个目标；没有
  创建 PR，没有请求 Zaikun Zhang 或任何其他 reviewer。
- 随后逐个使用 `git ls-remote` 核对 12 个仓库，所有 `refs/heads/main` 均精确
  指向 `96eb4f61dfc41ba9df7af72f9fd315380c0ba3dc`。
- 从公开 URL 下载的 `bladesopt/bds` README 与本地文件逐字节一致；GitHub API
  显示公开 `main` 精确包含计划中的 22 个 workflow 文件。
- 上述首次公开核对于 2026-08-23 19:32 CST 完成。回填本记录后还会产生一个只改
  计划文档的最终记录 commit；正式 workflows 必须从该最终 `main` commit 触发。

### Gate D

12 个正式 competitor/capability runs 已全部成功：

| Experiment | Run ID | Artifacts |
| --- | ---: | ---: |
| Acceleration big | `32637077450` | 13 |
| Acceleration small | `32637077428` | 13 |
| BFGS without supplied gradients big | `32637077394` | 28 |
| BFGS without supplied gradients small | `32637077427` | 28 |
| BFO big | `32637077422` | 28 |
| BFO small | `32637077412` | 28 |
| NEWUOA big | `32637077400` | 28 |
| NEWUOA small | `32637077415` | 28 |
| Invalid function evaluation big | `32637077409` | 5 |
| Termination big | `32660505584` | 13 |
| NOMAD small | `32662227623` | 28 |
| NOMAD big | `32673673644` | 28 |

- 原始 NOMAD runs 暴露 `libMatlabEngine.so` 无法解析。最终修复在 NOMAD 构建完成
  后加入 MATLAB 的 `bin/glnxa64`、`extern/bin/glnxa64` 和 `sys/os/glnxa64`，预加载
  系统 `libstdc++`，并由 `ldd` guard 验证所有依赖。修复后的 small run 完整成功。
- NOMAD big 在默认两次重复下有 9 个 feature jobs 到达 GitHub 的 6 小时上限；完整
  日志证明它们一直在继续求解 S2MPJ problems，而不是卡在绘图。因而仅对 NOMAD big
  设置 `n_runs = 1`，保留维数 6--50、全部 problems、26 个 features、两个 solvers、
  `500*n` 和 `expand=2.0`。第一次 bounded run 的一个 runner 收到平台 shutdown
  signal；相同配置的完整重跑 `32673673644` 以 27/27 jobs 成功。
- 原始 termination run 的 `noisy_1e-3` job 在求解完成后、默认逐题 history plot
  导出期间达到 6 小时上限。设置 `draw_hist_plots = 'none'` 后，最终 run 保留默认
  两次随机运行、全部 problems/features 和正式 profile 输出，并以 12/12 jobs 成功。
- 每个正式 run 都同时包含逐 feature artifacts、merged profiles 和 summary bundle。
  已实际下载并使用 `unzip -tq` 校验 acceleration big、BFO small、
  invalid-function-evaluation big、termination big、NOMAD small 和 NOMAD big 的
  summary ZIP，分别包含 23、53、7、23、53 和 53 个条目。NOMAD 的 merged artifacts
  分别约 237 MB 和 822 MB，已核对 API 元数据与 SHA-256 digest；全部本机临时下载
  均已清理。

### 公开 badge 补充审计

- 22 个 README badge 的 SVG 实查中，12 个正式实验和 3 个已持续运行的 baseline
  显示 `passing`；其余 7 个旧 baseline 显示 `no status`。
- GitHub API 证明这 7 个 workflow 均为历史遗留的 `disabled_manually`，不是测试失败。
  已由当前代码负责人重新启用；没有创建 PR 或 reviewer request。
- `spell_check.yml` 原本只有 path-filtered push，现已增加 `workflow_dispatch`；其 push
  run `32688374702` 成功。Check Spelling push run `32688374694` 也已成功。
- Parallel/Recursive 首次恢复运行发现它们复用了仅含 Optimization Toolbox 的 MATLAB
  缓存，实际缺少 Parallel Computing Toolbox。两个 workflow 现使用独立的
  `optimization-parallel` cache key。Recursive 还修复了未向 solver options 传入矩阵
  `Algorithm`、保留已不支持的 `scbds` 和 crash helper 路径错误三个旧问题。最终
  Parallel run `32688568221` 和 Recursive run `32690013044` 均完整成功；后者使用
  固定 `seed=42`、`dimension=2`、`depth=1`，一次真实递归已经覆盖目标函数内部再次
  调用 BDS，最终矩阵覆盖五个受支持算法、两个 OS 和两个 MATLAB 版本。
- NORMA 首次恢复运行发现测试目标仍把默认开启加速的新 BDS 与 pre-acceleration
  NORMA 直接比较。最终契约比较三项加速全关、普通有限函数值、关闭 target stop 的
  production BDS 与 NORMA，并显式对齐 NORMA legacy 默认 `expand=1.8`；termination、
  invalid-evaluation 和 production 默认 `expand=2.0` 由各自专门 workflow 覆盖。
  最终 NORMA run `32689595009` 以 16/16 jobs 成功。服务器 MATLAB `checkcode` 已确认
  修改文件无语法问题。
- Stress 的定时大矩阵仍保留普通问题 `n=500`、tough 问题 `n=1000` 和 `500*n` 预算；
  手动入口新增可选 dimension/budget。本次恢复 run `32689883726` 用 `n=20`、预算
  2000 执行完整 40-job OS/MATLAB/solver/tough 矩阵并全部成功。
- Unit run `32688374670` 以 12/12 jobs 成功。两个 verification workflows 均确认只
  使用 S2MPJ、不再安装 MatCUTEst；最终 Simplified BDS run `32689595018` 以 4/4 jobs
  成功。
- 完成时直接下载 README 中 22 个唯一 `badge.svg?branch=main`；SVG `<title>` 的状态
  逐个解析为 `passing`，计数为 22/22，没有 `no status`、`failing`、`cancelled` 或
  `unknown`。最终公开 badge 审计于 2026-08-24 13:13 CST 完成。

### 最终本地审计

- 发布代码 HEAD `71c49cf5` 之后，`.github/workflows` 仍精确包含 22 个 YAML；全部
  通过 `actionlint` 和 Ruby/Psych 解析，`git diff --check` 通过。
- README 的 workflow 文件集合与目录中的 22 个 YAML 精确相等，每个文件名恰好出现
  两次（badge image 和 workflow link）；12 个 competitor/capability workflow 均为
  manual-only，不含临时 push trigger。
- 不存在 MatCUTEst 或 large workflow 文件；两个 baseline verification workflows 也
  已设置 `install_matcutest=false`。四个 artifact shell helpers 通过 `bash -n` 和
  ShellCheck，timestamp behavior test 再次通过。
- `.git/config` 的 fetch URL、12 个 push URLs、`main` branch 和 `origin/main` tracking
  再次逐项打印核对，均与本计划一致。最终完成记录使用 `[skip ci]`，以免镜像同步时
  重复启动刚刚完成的 workflows。
