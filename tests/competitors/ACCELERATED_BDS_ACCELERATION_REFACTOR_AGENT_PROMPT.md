# Agent Prompt: Accelerated BDS Acceleration Refactor

你现在负责执行：

```text
/Users/lihaitian/Work/bds/tests/competitors/ACCELERATED_BDS_ACCELERATION_REFACTOR_PLAN.md
```

请按照该计划完成 `accelerated_bds_options.m` 的加速机制重构，并自主完成实现、测试和阶段性检查。

## 总体目标

将 iteration body 中的三类加速机制独立成 private helper，同时保持所有数值行为和可观察行为完全不变：

1. `productive_direction_memory` 独立为 pre-poll phase helper。
2. `use_iteration_pattern_step` 和 `use_momentum_extrapolation` 作为一个统一的 post-poll acceleration phase helper。必须保留 pattern search 失败后才尝试 momentum 的现有控制逻辑。

主 solver 最终应主要保留 iteration-level orchestration、普通 BDS polling、共享状态整理和共同 termination 检查。

## 绝对修改边界

只允许修改：

- iteration body 中属于三类加速机制的代码；
- 为承载这些机制而新增或修改的 `tests/competitors/private/` helper；
- 加速代码抽取后必须同步移动的、仅解释这些加速机制的局部注释；
- 加速 helper 的必要调用点和状态传递代码；
- 与上述改动直接相关的测试或计划记录。

禁止修改：

- solver iteration 开始之前的任何注释。该区域的注释已经由开发者修订，必须原样保留；
- 函数头注释，包括 options、termination 和 output 的已有修订；
- 任何不涉及加速机制的注释；
- 普通 BDS polling 算法及其相关代码；
- 梯度估计、梯度停机和 objective-window 逻辑；
- 输入验证、options 默认值、legacy option 兼容层和公共接口；
- 输出字段及其语义；
- 与本次加速 helper 抽取无关的变量命名、格式化或代码清理。

不要为了“顺便整理”而修改其他区域。前面已经完成的函数头注释和其他非加速注释修改必须保留。

## 严格不变量

严格不变量是最高优先级。每个实现阶段都必须在本机 MATLAB 上检查，不能只比较最终点或目标函数值。

### 加速开关打开

```matlab
use_productive_direction_memory = true
use_iteration_pattern_step = true
use_momentum_extrapolation = true
```

此时 `accelerated_bds_options.m` 必须与 `lean_evolved_bds.m` 完全一致。

### 加速开关关闭

```matlab
use_productive_direction_memory = false
use_iteration_pattern_step = false
use_momentum_extrapolation = false
```

此时 `accelerated_bds_options.m` 必须与 `bds.m` 在相同显式 solver options 下完全一致。

完全一致包括函数评估点序列、函数评估次数、返回点和目标函数值、stopping behavior、exitflag、histories 和 random behavior。

## MATLAB 执行方式

必须使用本机 MATLAB 验证，不要用 Python 模拟或只做静态检查。

严格检查：

```bash
cd /Users/lihaitian/Work/bds
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration"
```

如果涉及函数评估 bookkeeping 或 gradient stopping，再运行：

```bash
matlab -batch "addpath(genpath(pwd)); verify_gradient_stop_no_extra_evaluations"
```

长时间测试可以后台运行并写日志，不要持续占用交互输出：

```bash
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration" > /tmp/bds_verify_acceleration.log 2>&1 &
echo $!
```

之后每隔约 30–60 秒检查一次：

```bash
ps -p <PID> -o pid=,stat=,etime=,command=
tail -n 40 /tmp/bds_verify_acceleration.log
```

测试失败时必须停在当前阶段，先分析原因，不能继续下一阶段。

## 分阶段执行

### Stage 0：基线和工作区检查

1. 检查 `git status` 和现有 diff，保护所有用户已有修改。
2. 阅读当前 iteration body 以及所有 acceleration private helpers。
3. 运行并记录 `verify_bds_acceleration` 基线结果。
4. 运行 `verify_gradient_stop_no_extra_evaluations`。
5. 列出三个加速阶段读取和写入的全部状态。

只有基线严格检查通过，才能继续。

### Stage 1：定义 helper 契约，不改变行为

明确两个 helper 的输入和输出：

```text
run_productive_direction_memory_phase
run_post_poll_acceleration_phase
```

必须覆盖 `xbase`、`fbase`、`nf`、`fhist`、`xhist`、`invalid_points`、`target_reached`、`terminate`、`exitflag`、`iteration_improved`、阶段成功标志、`productive_direction_memory`、`momentum`、函数评估预算和相关 options。此阶段不得改变算法行为。

### Stage 2：抽取 pre-poll memory phase

只移动 productive-direction memory 代码，不同时移动 pattern/momentum。必须保留 memory list order、duplicate-direction handling、`max(mean(alpha_all), stored_step)`、candidate acceptance、target checks、成功方向后的至多两次 extrapolation evaluations、历史记录、函数评估预算、termination 和 exitflag 行为。

抽取后立即运行 `verify_bds_acceleration`。只有两个严格不变量都通过，才能进入 Stage 3。

### Stage 3：抽取 post-poll acceleration phase

把完整 pattern/momentum protocol 一起移动到一个 private helper 中。必须保留 iteration 改进和 `norm(iteration_step) > max(alpha_tol)` 的进入条件、pattern step/direction、momentum update order 和 normalization threshold、因素 `[1, 2, 4]`、pattern 先于 momentum、pattern 成功时不执行 momentum、pattern 未成功时才执行 momentum、失败 pattern candidate 的重复评价抑制、accepted acceleration 后的 memory update、target、budget、histories、terminate 和 exitflag 行为。

抽取后运行：

```bash
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration"
matlab -batch "addpath(genpath(pwd)); verify_gradient_stop_no_extra_evaluations"
```

### Stage 4：简化主 iteration body

确认两个 helper 分别通过严格检查后，让主循环清晰呈现：

```text
iteration initialization
pre-poll acceleration
regular BDS polling
post-poll acceleration
common stopping checks
```

不要把共同 termination checks 移入 helper，除非能够证明原有执行顺序完全不变。每次逻辑性修改后都重新运行严格检查。

### Stage 5：整理加速局部注释

行为稳定后，只整理与加速 helper 直接相关的局部注释。机制说明放到对应 private helper，主 solver 只保留 phase ordering 和 shared state 说明。不得修改 iteration 开始前的注释、函数头注释或任何非加速注释。注释整理后仍需运行严格检查。

### Stage 6：最终验收

运行：

```bash
cd /Users/lihaitian/Work/bds
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration"
matlab -batch "addpath(genpath(pwd)); verify_gradient_stop_no_extra_evaluations"
git diff --check
git status --short
```

最终报告必须说明新增或修改的 helper、每个 helper 的状态契约、每阶段 MATLAB 命令及两个严格不变量结果、测试警告、用户修改是否保留以及未解决问题。

除非测试失败需要停下分析，否则不要等待用户确认每个中间步骤。可以按上述阶段自主执行，但任何严格检查失败都必须停止并报告。
