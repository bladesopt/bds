# GitHub Actions 历史实验 Workflow 分类与正式恢复清单

## 文档状态与范围

本文档用于决定：生产版 BDS 合并到 `main` 后，原有的 111 个
`profile_*.yml` 实验 workflow 中哪些科学问题仍应由 GitHub Actions
支持，以及应新增哪些面向当前生产版 BDS 的 workflow。

本文档既确定正式候选范围，也记录当前分支中的恢复结果。本地恢复不等于启用：在
文件被 commit 并 push 前，不会触发 GitHub Actions。以下范围已经确认：

1. 保留当前 `main` 上的 10 个 correctness/maintenance workflow。
2. 生产版 BDS 的正式 comparison set 收敛为 BFO、NOMAD、NEWUOA 和不提供
   梯度的 BFGS；每组 workflow 只比较一个 competitor。
3. 为 acceleration、termination、NaN/函数评价失败分别保留清晰可见的
   workflow。
4. 不恢复历史 block 数量、随机方向、RBDS 参数扫描等 workflow。
5. 不加入 BOBYQA。
6. `fminunc` 比较必须通过 `tests/competitors/fminunc_wrapper.m` 完成；不能
   用历史 `fd-bfgs` workflow 或 `fminunc_budgeted_wrapper.m` 替代。

历史 YAML 没有丢失。它们仍完整保存在旧 `main` 提交
`81c3ef7bbb90faa3947160cbeabfaa080422bbba` 中。例如，可以只读查看：

```bash
git show 81c3ef7bbb90faa3947160cbeabfaa080422bbba:.github/workflows/profile_orig_cbds_newuoa_small_s2mpj.yml
```

未来如果确实需要，也可以在新分支逐文件恢复：

```bash
git restore \
  --source=81c3ef7bbb90faa3947160cbeabfaa080422bbba \
  -- .github/workflows/profile_orig_cbds_newuoa_small_s2mpj.yml
```

恢复 YAML 并不能恢复已经过期的 GitHub Actions artifact；两者是不同问题。

## 最终建议概览

新的 GitHub Actions 表面应由两部分组成。

第一部分是当前已经存在的 10 个 correctness/maintenance workflow，继续负责
每次代码变动后的正确性检查。

第二部分由用途清晰、彼此隔离的 workflow 家族组成：

1. 成对 competitor workflow：一个文件只比较 production BDS 与一个 competitor；
2. `benchmark_bds_acceleration_small.yml` 和
   `benchmark_bds_acceleration_big.yml`；
3. `benchmark_bds_termination_big.yml`；
4. `invalid_function_evaluation_test.yml`。

不存在也不应新增 `benchmark_bds_competitors.yml` 这种把所有 competitor 塞在一起
的总 workflow。当前恢复上述四个 comparison 对象，各自按照
`small/large/big × s2mpj/matcutest` 拆成六个文件，共二十四个文件。每个文件内部可以
用 feature matrix 并行比较不同问题特征，但 merge job 只能汇总这一对 solver、这一
规模和这一问题库的 feature 图。

因此，111 个旧 workflow 不应原样恢复。需要保留的科学问题由少量参数化的
新 workflow 重新表达；其余文件继续保留在 Git 历史中即可。

## 当前 Workflow Baseline

当前 `main` 上的 10 个 workflow 不属于恢复对象。它们构成现有正确性和维护
基线，建议全部保留：

| 当前 workflow | 作用 | 正式建议 |
| --- | --- | --- |
| `bds_regression_test.yml` | 生产版 acceleration、reference behavior 和 stopping regression | 保留，作为核心 correctness workflow |
| `gradient_test.yml` | 梯度估计正确性 | 保留 |
| `unit_test.yml` | MATLAB unit tests | 保留 |
| `stress_test.yml` | Stress tests | 保留 |
| `parallel_test.yml` | 并行执行行为 | 保留 |
| `recursive_test.yml` | 递归调用行为 | 保留 |
| `verify_simplified_bds.yml` | Simplified-BDS 等价性 | 保留 |
| `verify_norma.yml` | NORMA 验证 | 保留；除非未来明确停止维护 NORMA |
| `spelling.yml` | 通用拼写检查 | 保留 |
| `spell_check.yml` | TeX/Bib 拼写检查 | 保留 |

这些 workflow 负责 correctness。新 benchmark workflow 负责生成科学实验结果和
artifact，不能取代 correctness gate，也不应全部成为每个 pull request 的必跑项。

## 正式比较对象

正式 competitor 集合以 `tests/competitors/` 中当前明确维护的文件为边界。
workflow 不能因为历史 label 仍能运行，就自行增加新的比较对象。

| 显示名称 | 唯一实现来源 | 在新 benchmark 中的定位 |
| --- | --- | --- |
| Production BDS | `src/bds.m` | 被比较的生产求解器 |
| BFO | `tests/competitors/bfo_wrapper.m` | 外部 derivative-free solver |
| NOMAD | `tests/competitors/nomad_wrapper.m` | 外部 derivative-free solver |
| NEWUOA | `tests/competitors/prima_wrapper.m`，显式设置 `Algorithm = "newuoa"` | PRIMA 中选定的 derivative-free solver |
| BFGS without supplied gradients | `tests/competitors/fminunc_wrapper.m`，显式设置 `with_gradient = false` | MATLAB comparison baseline；不将其称为 DFO 方法 |

这里的“比较对象”与“算法分类”是两回事。BFGS 被纳入是因为它是明确选定的
comparison baseline，而不是因为它属于 DFO。

以下对象明确不进入新的正式 competitor workflow：

- BOBYQA：根据已经完成的外部讨论，不需要加入。
- 历史 `fd-bfgs`/`fd-bfgs-500n` label：不恢复；正式对象是
  `fminunc_wrapper.m`。
- `fminunc_budgeted_wrapper.m`：可保留在仓库供其他实验使用，但不替代本次
  指定的 `fminunc_wrapper.m`。
- Nelder--Mead、LAM 和 PDS：当前 comparison set 已收敛为上述四项，不再为
  它们建立公开 workflow。
- 历史 PADS、PBDS、RBDS、随机方向和 block/batch 参数变体：不进入公开
  competitor benchmark。

`bds_simplified.m`、`bds_without_acceleration_reference.m`、
`lean_evolved_bds.m` 及其快照属于 correctness/reference 实现，可以服务于
acceleration 或 termination 验证，但不作为知名外部 solver 展示。

## 111 个旧 Workflow 的规模

旧 `main` 一共有 120 个 workflow，当前有 10 个。差异中包含 111 个被删除的
`profile_*.yml` 文件，以及新加入或调整的 correctness workflow。

111 个旧 profiling workflow 的机械统计如下：

| 项目 | 数量 |
| --- | ---: |
| 被删除的 profiling workflow | 111 |
| S2MPJ workflow | 72 |
| MatCUTEst workflow | 39 |
| 包含 `workflow_dispatch` | 111 |
| 包含每月 `schedule` | 111 |
| 所有 schedule 展开后的 MATLAB matrix test jobs | 2310 |
| Artifact 合并 jobs | 106 |
| 每月定时 jobs 合计 | 2416 |
| `actions/upload-artifact@v4` steps | 328 |

2310 个 MATLAB jobs 来自 6 套不一致的 feature matrix：

| Workflow 数量 | 每个 workflow 的 features 数量 | Matrix jobs |
| ---: | ---: | ---: |
| 3 | 9 | 27 |
| 15 | 10 | 150 |
| 27 | 15 | 405 |
| 3 | 22 | 66 |
| 51 | 26 | 1326 |
| 12 | 28 | 336 |
| **111** |  | **2310** |

所以，原样恢复并不是简单地在 Actions 页面增加 111 个入口，而是重新启用每月
超过两千个 MATLAB job。这与当前希望保持清晰、可维护的 public repository
不一致。

## 111 个旧 Workflow 的完整分类与正式处置

### BDS 功能和历史 CBDS 研究：48 个

| 历史文件家族 | 数量 | 原实验问题 | 正式处置 |
| --- | ---: | --- | --- |
| `profile_cbds_block_number_{small,large,big}_s2mpj.yml` | 3 | Block 数量影响 | 不恢复 |
| `profile_cbds_func_20_tol_06_{size}_{library}.yml` | 6 | 函数值停机 | 不恢复旧 YAML；由新 termination workflow 取代 |
| `profile_cbds_grad_01_tol_06_{size}_{library}.yml` | 6 | 梯度停机 | 不恢复旧 YAML；由新 termination workflow 取代 |
| `profile_cbds_func_20_tol_06_grad_01_tol_06_{size}_{library}.yml` | 6 | 组合停机 | 不恢复旧 YAML；由新 termination workflow 取代 |
| `profile_cbds_func_20_tol_06_grad_01_tol_06_500n_{size}_{library}.yml` | 6 | `500*n` 下的组合停机 | 不恢复旧 YAML；保留科学问题并迁移到新 termination workflow |
| `profile_cbds_orig_cbds_simplified_{size}_{library}.yml` | 6 | Original CBDS 与 simplified CBDS | 不恢复；correctness 已由 baseline workflow 覆盖 |
| `profile_cbds_orig_cbds_smart_alpha_init_{small,large,big}_s2mpj.yml` | 3 | 单位初始步长与自动初始步长 | 不恢复独立 workflow；由 unit/BDS regression 覆盖正确性 |
| `profile_cbds_orig_termination_cbds_simplified_{size}_{library}.yml` | 6 | 停机机制与 simplified CBDS | 不恢复旧 YAML；由新 termination workflow 取代 |
| `profile_cbds_randomized_gaussian_{small,large,big}_s2mpj.yml` | 3 | 随机 Gaussian directions | 不恢复 |
| `profile_cbds_randomized_orthogonal_{small,large,big}_s2mpj.yml` | 3 | 随机 orthogonal directions | 不恢复 |
| **合计** | **48** |  |  |

其中 `{size}` 表示 `small`、`large` 或 `big`，`{library}` 表示
`s2mpj` 或 `matcutest`。

自动初始步长仍是生产版 BDS 应在 README 中介绍的能力，但它不需要独立的公开
workflow。README 是否介绍某项能力，与该能力是否需要独立 GitHub Actions 入口
不是同一件事。

### 历史 competitor comparisons：51 个

| 历史文件家族 | 数量 | 原比较对象 | 正式处置 |
| --- | ---: | --- | --- |
| `profile_orig_cbds_bfo_{size}_{library}.yml` | 6 | BFO | 恢复为 `profile_bds_bfo_{size}_{library}.yml`，并调用 `bfo_wrapper.m` |
| `profile_orig_cbds_simplex_{size}_{library}.yml` | 6 | Nelder--Mead | 不恢复 |
| `profile_orig_cbds_newuoa_{size}_{library}.yml` | 6 | NEWUOA | 恢复为 `profile_bds_newuoa_{size}_{library}.yml`，并调用 `prima_wrapper.m` |
| `profile_orig_cbds_bfgs_{size}_{library}.yml` | 6 | 历史 FD-BFGS 配置 | 恢复为 `profile_bds_bfgs_no_gradient_{size}_{library}.yml`；改用明确的无梯度 label，并调用 `fminunc_wrapper.m` |
| `profile_orig_cbds_nomad_{size}_{library}.yml` | 6 | NOMAD | 恢复为 `profile_bds_nomad_{size}_{library}.yml`，并调用 `nomad_wrapper.m` |
| `profile_orig_cbds_orig_ds_{size}_{library}.yml` | 6 | Original direct search | 不恢复 |
| `profile_orig_cbds_pds_{size}_{library}.yml` | 6 | PDS | 不恢复 |
| `profile_orig_cbds_orig_pads_{small,large,big}_s2mpj.yml` | 3 | Original PADS | 不恢复 |
| `profile_orig_cbds_orig_pbds_{small,large,big}_s2mpj.yml` | 3 | Original PBDS | 不恢复 |
| `profile_orig_cbds_orig_rbds_{small,large,big}_s2mpj.yml` | 3 | Original RBDS | 不恢复 |
| **合计** | **51** |  |  |

历史 BFGS YAML 的 `fd-bfgs` label 不再沿用，因为该 label 还会根据 feature 切换
梯度估计路径。新的 `bfgs-no-gradient-500n` label 对所有 feature 都明确设置
`with_gradient = false`，由 `fminunc` 自己处理未提供梯度的情形。

### RBDS 参数研究：12 个

| 历史文件家族 | 数量 | 原实验问题 | 正式处置 |
| --- | ---: | --- | --- |
| `profile_rbds_batch_size_{small,large,big}_s2mpj.yml` | 3 | RBDS batch size | 不恢复 |
| `profile_rbds_replacement_delay_{small,large,big}_s2mpj.yml` | 3 | RBDS replacement delay | 不恢复 |
| `profile_rbds_batch_size_1_ds_orig_{small,large,big}_s2mpj.yml` | 3 | Batch-size-one RBDS 与 original DS | 不恢复 |
| `profile_rbds_batch_size_1_pds_{small,large,big}_s2mpj.yml` | 3 | Batch-size-one RBDS 与 PDS | 不恢复 |
| **合计** | **12** |  |  |

以上三类相加为 `48 + 51 + 12 = 111`。所有标记为“不恢复”的文件继续保存在
Git 历史中，不需要为了“归档”重新复制到当前工作树。

## 为什么不能原样恢复旧 YAML

### 公共 helper 需要和选中的 workflow 一起恢复

旧 workflow 依赖以下已经删除的文件：

- 111 个 workflow 使用 `tests/tools/strip_profile_timestamp.sh`；
- 106 个 workflow 使用 `tests/tools/merge_pdf.sh`；
- 72 个 workflow 使用 `tests/tools/get_base_info.sh`。

本轮四个 competitor 家族的恢复已经把这三个 helper 以及对应的 timestamp stripping 自测试一并
找回。它们先保证历史 artifact 汇总链条可以运行；以后升级为 manifest-driven artifact
时，应把 helper 与二十四个 workflow 作为一个整体迁移，不能只改其中一边。

### 历史 solver label 已经发生语义漂移

当前 `tests/profile_optiprofiler.m` 仍识别许多旧 label，但 label 能运行并不
表示科学含义仍然正确。例如：

- `cbds-orig` 现在调用生产版 `bds`，没有显式关闭三项 acceleration；
- `cbds-orig-termination` 调用生产版 `bds` 并打开 optional stopping，但仍继承
  当前 acceleration 默认值；
- `cbds-orig-smart-alpha-init` 调用生产版 `bds` 并设置
  `alpha_init = "auto"`；
- 历史 `fd-bfgs-500n` 走的是 `fminunc_budgeted_wrapper.m`，不符合本次明确
  指定的 `fminunc_wrapper.m` 比较对象。

因此，旧 workflow 即使运行成功，也可能生成标签错误或比较协议不一致的结果。

### 旧 schedule 的规模不再合理

111 个 workflow 全部同时带有 `workflow_dispatch` 和月度 `schedule`。原样恢复会
每月启动 2416 个 jobs。新的 large/big、MatCUTEst、full-feature benchmark 必须
首先保持手动触发；是否保留一个小型月度 flagship benchmark，应在测得实际运行
时间和 artifact 体积后再决定。

## 正式候选 Workflow 家族

### 1. 成对 competitor workflow

目的：生成生产版 BDS 与正式 comparison set 的可下载、可复现实验结果，同时让每次
运行的资源边界、失败范围和 artifact 含义保持清楚。

正式 comparison set：

- production BDS；
- BFO，通过 `bfo_wrapper.m`；
- NOMAD，通过 `nomad_wrapper.m`；
- NEWUOA，通过 `prima_wrapper.m` 且显式设置 `Algorithm = "newuoa"`；
- BFGS without supplied gradients，通过 `fminunc_wrapper.m` 且显式设置
  `with_gradient = false`。

每一个 competitor 都有自己的 BDS–competitor workflow 家族。当前正式恢复的是：

- `profile_bds_bfo_{small,large,big}_{s2mpj,matcutest}.yml`；
- `profile_bds_nomad_{small,large,big}_{s2mpj,matcutest}.yml`；
- `profile_bds_newuoa_{small,large,big}_{s2mpj,matcutest}.yml`；
- `profile_bds_bfgs_no_gradient_{small,large,big}_{s2mpj,matcutest}.yml`。

一个文件只对应一个 competitor、一个规模和一个问题库。不同 feature 可以在该文件的
matrix 中展开，随后只把这一比较内部的 feature 图合并起来。

基本实验协议：

- 所有可统一的预算均显式设置为 `500*n`；
- BDS 的 `expand` 显式设置为 `2.0`；
- BDS 的三项 acceleration 显式设置，而不是依赖未来可能变化的默认值；
- `StepTolerance`、`ftarget`、初始点、problem list 和随机种子写入 manifest；
- `fminunc` 明确使用 `fminunc_wrapper.m` 的配置和计数口径；
- NEWUOA 明确记录 PRIMA revision 和实际解析到的函数路径；
- 每个 solver 先通过一个小问题和预算计数 preflight，再进入完整矩阵。

当前恢复的触发方式：

- 二十四个文件都支持 `workflow_dispatch`；
- 为保持历史恢复的完整性，暂时保留原月度 schedule：BFGS、BFO、NEWUOA、NOMAD
  分别在每月 4、5、6、7 日触发；
- 在 push 前应单独确认是否继续启用这些 schedule；第一次实际运行仍建议从每个
  competitor 的 small S2MPJ workflow 开始。

### 2. Acceleration benchmark

目的：为 README 中介绍的三项 acceleration mechanism 提供可复现的性能证据，
同时继续验证 production/reference 等价性。

正式 configurations：

- 三项 acceleration 全关；
- 三项 acceleration 全开；

所有配置应共享相同的 `500*n` 预算、`expand = 2.0`、初始步长、停机开关和问题
集合。性能 profile 与等价性检查必须分开报告，避免将“结果相同”和“表现更好”混为
一件事。

当前实现拆为 `benchmark_bds_acceleration_small.yml`（S2MPJ，维数 1–5）和
`benchmark_bds_acceleration_big.yml`（S2MPJ，维数 6–50）。两个 workflow 都只手动
触发并自动合并 11 个已批准 feature 的 artifacts。当前 `bds_regression_test.yml`
继续负责 pull request 上的等价性 gate。

### 3. `benchmark_bds_termination_big.yml`

目的：为 optional function-value stopping 和 estimated-gradient stopping 提供
可复现的性能、节省评价次数和 termination-code 证据。

正式 configurations：

- 只打开 function-value stopping；
- 只打开 estimated-gradient stopping；
- 两项组合打开。

三组均打开三项 acceleration，并共享 production 推荐参数、`500*n` 预算和
`expand = 2.0`。当前实现只使用 S2MPJ 维数 6–50 和批准的 11 个 feature，默认仅
手动触发并自动合并 artifacts。

每个 artifact 至少记录：

- 最终点和函数值；
- `exitflag` 与 message；
- `funcCount`；
- 触发停机准则的 iteration/gradient estimate；
- 与固定 `500*n` horizon 下 reference result 的差异；
- abnormal termination 和 output fallback。

建议默认只手动触发。当前 `bds_regression_test.yml` 和 gradient-related baseline
workflow 继续负责 pull request 上的小型 correctness gate。

### 4. `invalid_function_evaluation_test.yml`

目的：比较 production BDS 和 simplified BDS 在随机 NaN 函数评价下的表现。

当前实现只使用 S2MPJ 维数 6–50，并分别运行 `random_nan_5`、`random_nan_10` 和
`random_nan_20`。两组使用相同的 `500*n`、`expand = 2.0`、`shrink = 0.5` 和单位
初始步长；production BDS 关闭 acceleration 和 optional stopping，使比较集中在
无效函数评价处理。workflow 默认只手动触发，并自动合并三个 feature artifacts。

抛出 exception、初始点评价失败、`invalid_points`、预算计数和 exitflag 等确定性行为
继续由 regression/correctness tests 覆盖，不混入本 performance-profile workflow。

## 自动初始步长的定位

`alpha_init = "auto"` 仍应在 README 中与 acceleration、termination 和无效评价
处理一起介绍。但是按照当前收敛范围，不为它建立独立 workflow。

它的正确性应由以下位置覆盖：

- `unit_test.yml`；
- `bds_regression_test.yml`；
- benchmark configuration 的 preflight；
- 必要时 competitor benchmark 中一个明确命名的 production-BDS configuration。

如果将来需要回答“自动初始步长是否在某类问题上更快”这一独立科学问题，再新增
手动 experiment mode，而不是现在恢复旧的 3 个 smart-alpha workflow。

## Artifact 正式约定

三类 benchmark 的四个 YAML workflow 生成的 artifact 应是自描述的。每个
result bundle 至少包含：

1. 原始 `.mat` 结果；
2. 机器可读和纯文本 run manifest；
3. 每个 comparison implementation 的来源和版本；
4. solver options、预算、种子、problem names 和 dimensions；
5. 无需 MATLAB 即可阅读的 score/termination summary；
6. performance/data/log-ratio profiles；
7. abnormal termination、output fallback 和失败 solver call 的诊断信息。

Artifact 名称必须来自 manifest 字段，不能继续依赖带时间戳的目录名和 shell 字符串
推断。GitHub artifact 的 retention period 需要显式设置；用于论文、报告或发布的关键
结果还应进入 repository release 或独立研究归档，不能无限期依赖 Actions storage。

## 后续仍需决定的参数

比较对象和本轮 feature 已经确定，不再讨论新增 BOBYQA 或其他 solver。当前只剩以下
发布策略参数：

1. 是否保留一个小型月度 flagship benchmark；
2. artifact retention period；
3. README 是只给 correctness workflow 显示 badge，还是同时显示 flagship benchmark
   badge。

## 批准后的推荐实施顺序

1. 恢复四个 competitor 家族的二十四个独立 workflow 以及共同依赖的 helper。
2. 修改 `tests/profile_optiprofiler.m`，用明确的 production BDS 和四个 wrapper
   mapping 取代历史含糊 label。
3. 为每个 comparison configuration 增加小型 MATLAB contract test，验证实际调用的
   wrapper、预算和 options。
4. 分别运行四个 competitor 的 small S2MPJ 手动 preflight，再逐个检查其他规模和
   问题库。
5. comparison set 保持上述四项，不建立统一 competitor workflow，也不继续扩张。
6. 实现 acceleration 和 termination benchmark，并先验证其 correctness job。
7. 实现 NaN/failure workflow，并先以手动触发方式检查完整 artifact。
8. 下载并人工检查第一批 artifact 的内容、命名和可复现信息。
9. 测量运行时间和 artifact 大小后，再决定 monthly schedule 和 MatCUTEst/full-feature
   扩展。
10. 最后更新 README 中的 workflow 链接、badge 和四类 production capability 说明。

这套范围保留了当前 correctness baseline、重要 solver comparison、acceleration、
termination 以及 NaN/函数评价失败处理，同时不重新引入 111 个重复且语义已经漂移的
历史 workflow。
