# BDS 核心特性 benchmark workflow 实施计划

## 目标

为当前 production BDS 的三类核心特性建立可手动触发、可复现并自动合并
artifact 的 GitHub Actions 实验：

1. 三项 acceleration mechanism 全关与全开；
2. function-value stopping、estimated-gradient stopping 及二者组合；
3. production BDS 与 simplified BDS 在随机 NaN 函数评价下的比较。

这三类实验全部使用 S2MPJ。不会创建 large workflow，也不会删除
`profile_optiprofiler.m` 对 large 的既有支持。

## 固定实验协议

### 问题维数

- small：`mindim = 1`，`maxdim = 5`；
- big：`mindim = 6`，`maxdim = 50`；
- workflow 直接传入 `mindim` 和 `maxdim`，不依赖
  `profile_optiprofiler.m` 中现有的 `dim = "big"` 映射（该映射仍保持 6–20）。

### 公共 BDS 参数

所有新增 production-profile configurations 显式共享：

- `Algorithm = "cbds"`；
- `MaxFunctionEvaluations = 500*n`；
- `StepTolerance = 1e-6`；
- `ftarget = -Inf`；
- `alpha_init = 1`；
- `expand = 2.0`；
- `shrink = 0.5`；
- `is_noisy = false`；
- `forcing_function = @(alpha) alpha^2`；
- `reduction_factor = [0, eps, eps]`；
- opportunistic inner polling 和单次 inner cycling。

Termination 使用当前 production 默认参数：

- `func_window_size = 20`，`func_tol = 1e-6`；
- `grad_window_size = 1`，`grad_tol = 1e-2`；
- `lipschitz_constant = 1e3`；
- gradient-reference consistency 打开；
- `grad_reference_finite_difference_error_tol = 1/30`。

### Features

Acceleration 和 termination 使用且仅使用：

1. `plain`；
2. `noisy_1e-1`；
3. `noisy_1e-2`；
4. `noisy_1e-3`；
5. `noisy_1e-4`；
6. `permuted`；
7. `linearly_transformed`；
8. `rotation_noisy_1e-1`；
9. `rotation_noisy_1e-2`；
10. `rotation_noisy_1e-3`；
11. `rotation_noisy_1e-4`。

Invalid-function-evaluation 实验使用且仅使用：

1. `random_nan_5`；
2. `random_nan_10`；
3. `random_nan_20`。

## Workflow 与比较对象

### `benchmark_bds_acceleration_small.yml`

- S2MPJ，维数 1–5；
- `bds-acceleration-off-500n`：三项 acceleration 全关；
- `bds-acceleration-on-500n`：三项 acceleration 全开；
- optional function-value/gradient stopping 在两组中均关闭。

### `benchmark_bds_acceleration_big.yml`

- S2MPJ，维数 6–50；
- 比较对象与 small workflow 完全相同。

### `benchmark_bds_termination_big.yml`

- S2MPJ，维数 6–50；
- 三项 acceleration 在三组中均打开；
- `bds-function-value-stop-500n`：只打开 function-value stopping；
- `bds-estimated-gradient-stop-500n`：只打开 estimated-gradient stopping；
- `bds-combined-stop-500n`：同时打开两项 stopping。

### `invalid_function_evaluation_test.yml`

- S2MPJ，维数 6–50；
- `bds-invalid-aware-500n`：production BDS，三项 acceleration 和两项
  optional stopping 全关；
- `bds-simplified-500n`：现有 `bds_simplified.m`；
- production BDS 的预算、步长参数和 polling configuration 与 simplified
  BDS 对齐，使比较集中在无效函数评价处理，而不是 acceleration。

## Artifact 协议

每个 workflow：

1. 以 feature 为 matrix 维度，每个 feature 独立运行一次完整 solver comparison；
2. 每个 feature 上传独立、名称唯一的原始 artifact；
3. downstream `merge_artifacts` job 下载当前 run 的全部 artifacts；
4. 按既有 BFO workflow 的顺序合并 feature summary PDFs；
5. 上传完整 merged profiles 和单独的 summary bundle；
6. 初始版本仅支持 `workflow_dispatch`，避免意外消耗 GitHub Actions 配额。

## 执行清单

- [x] A. 固定问题库、维数范围、feature 清单和比较对象。
- [x] B. 在 `profile_optiprofiler.m` 中加入稳定、可读的 solver labels。
- [x] C. 统一 production-profile 公共参数，避免复用 `expand = 1.8` 的旧 helper。
- [x] D. 创建 acceleration small/big 两个 workflow。
- [x] E. 创建 termination big workflow。
- [x] F. 创建 invalid-function-evaluation big workflow。
- [x] G. 扩展 profile mapping contract test，验证每个 label 的精确选项。
- [x] H. 静态验证 4 个 YAML 的 S2MPJ、维数、feature、solver 和 artifact 合并约定。
- [x] I. 在 MATLAB 服务器运行 profile mapping test 和完整 regression suite。
- [x] J. 更新本计划和 workflow recovery 文档中的最终状态。

## 完成记录

- 本地 4 个 workflow 均通过 YAML 解析；artifact shell helpers 通过语法和行为测试；
- `verify_bds_benchmark_workflows` 输出 `BDS_BENCHMARK_WORKFLOWS_OK`；
- `verify_profile_workflow_mappings` 输出 `PROFILE_WORKFLOW_MAPPINGS_OK`；
- 服务器隔离副本的 `run_bds_regression_suite` 输出
  `BDS_REGRESSION_SUITE_OK`；
- regression suite 包含 acceleration 全关与 frozen reference 的 270-case 检查、
  acceleration 全开与 lean reference 的两组 630-case 检查，以及 function-value 和
  gradient stopping tests；
- 完整 S2MPJ profiles 尚未运行，等待 workflow commit/push 后由 GitHub Actions
  手动触发。

## 不在本轮范围内

- 不运行完整 S2MPJ benchmark；完整实验由 GitHub Actions 手动触发；
- 不创建 MatCUTEst 版本；
- 不创建 large workflow；
- 不改变 `profile_optiprofiler.m` 已有 small/big/large 通用映射；
- 不提交、不 push，也不触发 GitHub Actions。
