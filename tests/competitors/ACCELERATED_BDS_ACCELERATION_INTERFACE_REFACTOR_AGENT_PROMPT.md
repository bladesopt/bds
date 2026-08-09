# Agent Prompt: Refine the Acceleration Helper Interfaces

你现在负责精炼 `accelerated_bds_options.m` 中两个 acceleration helper 的接口：

```matlab
run_productive_direction_memory_phase
run_post_poll_acceleration_phase
```

工作目录：

```text
/Users/lihaitian/Work/bds
```

## 背景

三类 acceleration mechanisms 已经从主 solver 的 iteration body 中抽取出来：

- pre-poll productive-direction memory；
- post-poll iteration pattern step；
- post-poll momentum extrapolation。

当前代码已经通过两个严格不变量检查，但两个 helper 仍采用较长的 positional interfaces。现有接口是为了第一次机械抽取时最大限度保持行为而形成的，不应默认视为最终设计。

本任务的目标不是机械地减少参数数量，而是让每个 helper 的接口：

- 只暴露真正需要的信息；
- 按职责和生命周期形成清楚层次；
- 明确区分只读配置、可变运行状态和 phase result；
- 让主 solver 中的数据交接容易阅读和审计；
- 达到类似 `inner_direct_search` 接口经过充分打磨后的简洁程度；
- 在任何情况下都不改变计算表现或可观察行为。

## 最高优先级：两个严格不变量

每个代码实施阶段都必须在本机 MATLAB 上运行：

```bash
cd /Users/lihaitian/Work/bds
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration"
```

该检查必须同时证明：

1. 所有 acceleration switches 打开时，`accelerated_bds_options.m` 与
   `lean_evolved_bds.m` 完全一致；
2. 所有 acceleration switches 关闭时，`accelerated_bds_options.m` 与
   `bds.m` 完全一致。

完全一致不仅指最终 `x` 和 `f`，还包括：

- 函数评估点序列和次数；
- stopping behavior 和 exitflag；
- histories 和 diagnostics；
- random behavior；
- 所有返回值和输出字段。

凡是涉及函数评估 bookkeeping、histories、termination state 或 diagnostics 的阶段，还必须运行：

```bash
matlab -batch "addpath(genpath(pwd)); verify_gradient_stop_no_extra_evaluations"
```

任何严格检查失败都必须停止当前阶段，先查明并修复，不能继续后面的重构。

## 绝对修改边界

允许修改：

- `tests/competitors/private/run_productive_direction_memory_phase.m`；
- `tests/competitors/private/run_post_poll_acceleration_phase.m`；
- `tests/competitors/accelerated_bds_options.m` 中这两个 helper 的构造、调用和状态回收代码；
- 与这次 interface refactor 直接相关的局部 acceleration comments；
- 本任务需要的接口契约或执行记录文档。

禁止修改：

- 函数头注释；
- solver iteration 开始前已经修订过的任何注释或代码；
- 普通 BDS polling 算法；
- `inner_direct_search`；
- objective-window、gradient estimation 和 gradient stopping；
- public options、默认值、输入验证和输出语义；
- 任何与 acceleration helper interface 无关的注释、变量名、格式或代码；
- `lean_evolved_bds.m` 和 `bds.m` 两个 reference implementations；
- 严格验证程序的判定标准。

不要为了“顺手清理”而扩大修改范围。发现无关问题时只记录，不要修复。

## 设计原则

### 1. 参数少不是唯一目标

不能为了让函数签名变短，把所有内容粗暴塞进一个含义不明的巨大结构体。最终接口必须同时满足：

- 字段具有共同职责；
- 输入依赖清晰；
- 可变字段和只读字段容易区分；
- helper 不会获得它不需要的 solver 状态；
- 调用者能够清楚看到 phase 前后哪些状态可能改变。

### 2. 不要直接传入完整公共 `options`

完整 `options` 包含大量与 acceleration 无关的设置。直接传入它虽然减少 positional arguments，却扩大了 helper 的隐式依赖。若采用配置结构体，必须是只包含相应 acceleration phase 真正需要字段的窄结构体。

### 3. 审计可推导数据

检查当前参数中是否存在可以在更合适层级得到的量。例如：

- post-poll helper 需要的是完整 `alpha_tol`，还是仅需要 `max(alpha_tol)`；
- `iteration_step_norm` 应当由 caller 传入，还是由 `iteration_step` 在 helper 内计算；
- `terminate`、`target_reached` 和 `exitflag` 是真正的 input/output state，还是某些 phase 只会产生而不会读取的 result；
- `iteration_improved` 是 pre-poll phase 的输入输出状态，还是可以更明确地表示为 phase result。

不能只凭“当前函数体没有读取”就删除变量。必须同时审计调用前的不变量、调用后的消费者、diagnostics 和 termination ordering。

### 4. 区分三个层次

重点评估是否应明确区分：

- phase configuration：只读配置和阈值；
- mutable solver/evaluation state：phase 可能更新的运行状态；
- phase result：例如当前 phase 是否接受了 improvement。

下面只是需要评估的候选结构，不是必须照抄的最终答案：

```matlab
[state, result] = run_productive_direction_memory_phase(fun, state, config);
[state, result] = run_post_poll_acceleration_phase(fun, state, config, iteration_step);
```

如果另一个更窄、更清晰的接口优于该形式，可以采用，但必须在契约文档中说明理由。

### 5. 结构体必须保持窄而稳定

若使用 `state` 或 `config`：

- 只放两个 acceleration phases 真正共享或逻辑相关的字段；
- 不要把整个 solver workspace 包装成 state；
- 不要让 helper 动态增加未声明字段；
- 在调用点明确构造和回收字段；
- 避免为了减少输出参数而隐藏 mutation ownership；
- 使用 MATLAB value semantics，不依赖未授权的 handle-state side effects。

### 6. 先稳定接口，再整理注释

本任务完成前不要扩写大量机制注释。先让接口、字段所有权和主 solver 调用结构稳定，最后只修正因接口变化而过时的局部 acceleration comments。

## 分阶段执行

### Stage 0：保护工作区并建立基线

1. 运行 `git status --short` 和相关 diff，识别并保护所有用户已有修改。
2. 阅读：
   - `accelerated_bds_options.m` 中两个 helper 的调用点和后续消费者；
   - 两个 helper 的完整函数体；
   - `inner_direct_search` 的接口组织，仅作为代码风格参照，不修改它；
   - 现有 acceleration refactor plan 和 contracts。
3. 运行：

   ```bash
   matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration"
   matlab -batch "addpath(genpath(pwd)); verify_gradient_stop_no_extra_evaluations"
   ```

4. 记录基线通过结果。

Acceptance gate：两个检查均通过，且现有用户修改范围已明确。

### Stage 1：逐字段读写和生命周期审计

在修改代码前，为两个 helper 的每一个当前 input/output 建立表格，至少包含：

- 字段或参数名；
- caller 中的来源；
- helper 中是否读取；
- helper 中是否写入；
- helper 调用后的消费者；
- 所属类别：configuration、mutable state 或 phase result；
- 是否可由其他输入严格推导；
- 是否必须保留；
- 建议放置层级及理由。

特别审计：

- `target_reached`；
- `terminate`；
- `exitflag`；
- `iteration_improved`；
- `pre_poll_memory_succeeded`；
- `post_poll_acceleration_succeeded`；
- `iteration_step_norm`；
- `alpha_tol`；
- `MaxFunctionEvaluations`；
- `ftarget`；
- `output_xhist`；
- `nf`、`fhist`、`xhist` 和 `invalid_points`；
- `momentum` 和 `productive_direction_memory`。

把审计和候选契约写入一个新的 Markdown 文件，例如：

```text
tests/competitors/ACCELERATED_BDS_ACCELERATION_INTERFACE_CONTRACTS.md
```

这一阶段不修改 solver 实现。

### Stage 2：确定最终接口契约

基于审计结果，明确：

- 两个 helper 的最终函数签名；
- 每个 config/state/result 字段的含义和所有权；
- 哪些量由 caller 预计算；
- 哪些量由 helper 内部计算；
- 哪些值是 input/output；
- 哪些值只是 phase result；
- 主 solver 调用前后如何显式打包和解包状态。

必须解释为什么最终接口比当前 positional interface 更简洁、更有层次，而不是只统计参数数量。

不要在同一步中实施两个 helper 的代码修改。

### Stage 3：只重构 pre-poll helper interface

只修改 `run_productive_direction_memory_phase` 及其调用点。保持以下行为逐项不变：

- memory list order；
- trial step `max(mean(alpha_all), stored_step)`；
- candidate evaluation order；
- acceptance comparison；
- target checks；
- 至多两次 extrapolation evaluations；
- memory reordering；
- `nf`、`fhist`、`xhist` 和 `invalid_points`；
- `iteration_improved` 和 diagnostics phase result；
- termination 和 exitflag precedence。

实施后立即运行：

```bash
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration"
matlab -batch "addpath(genpath(pwd)); verify_gradient_stop_no_extra_evaluations"
```

Acceptance gate：两个检查均通过，才可进入下一阶段。

### Stage 4：只重构 post-poll helper interface

只修改 `run_post_poll_acceleration_phase` 及其调用点。保持以下行为逐项不变：

- phase entry guard 的时机和位置；
- pattern direction 和 pattern step；
- momentum update、decay 和 normalization 的顺序；
- factors `[1, 2, 4]`；
- pattern search 在 momentum search 之前；
- pattern 成功时不执行 momentum search；
- failed pattern candidate 的重复评价抑制；
- target 和 evaluation-budget checks；
- histories 和 invalid-point recording；
- successful acceleration 后的 productive-memory update；
- `post_poll_acceleration_succeeded`；
- termination 和 exitflag precedence。

实施后立即运行两个 MATLAB 检查。任何失败都不得进入下一阶段。

### Stage 5：逐项删除真正冗余的数据

只有在两个新接口分别通过严格检查后，才审慎删除审计中确认冗余或可推导的数据。不要一次删除多类字段。

建议按小步骤处理，例如：

1. 仅把完整向量替换为 helper 真正需要的标量；
2. 仅移除某个严格可推导的量；
3. 仅把某个纯 phase result 从 mutable state 中分离；
4. 仅移除 caller 中被 helper 无条件覆盖的过早初始化。

每一个逻辑步骤之后都运行：

```bash
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration"
```

凡涉及 bookkeeping、termination 或 diagnostics，再运行
`verify_gradient_stop_no_extra_evaluations`。

### Stage 6：局部注释和调用点整理

接口稳定后：

- 更新两个 helper 的函数头，使其准确解释最终契约；
- 主 solver 只保留 phase ordering、打包/解包和必要状态边界注释；
- 删除描述旧 positional interface 的局部 acceleration comments；
- 不修改函数头公共 options 注释、普通 polling 注释或其他无关注释；
- 检查是否出现只有 `%` 的空注释行；
- 检查行宽和 `git diff --check`。

注释整理后再次运行严格检查。

### Stage 7：最终独立验收

运行：

```bash
cd /Users/lihaitian/Work/bds
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration"
matlab -batch "addpath(genpath(pwd)); verify_gradient_stop_no_extra_evaluations"
git diff --check
git status --short
```

最终报告必须包括：

- 旧接口和最终接口的对照；
- 最终 config/state/result 分层及每个字段的所有权；
- 删除或预计算的每个参数及其理由；
- 每个实施阶段的 MATLAB 验证结果；
- warning 是否只是既有测试问题产生；
- 是否完整保留所有用户已有修改；
- 是否存在未解决问题。

## MATLAB 长任务执行

严格套件运行时间较长，可以后台运行并写入日志，避免持续读取输出：

```bash
cd /Users/lihaitian/Work/bds
matlab -batch "addpath(genpath(pwd)); verify_bds_acceleration" \
  > /tmp/bds_acceleration_interface_verify.log 2>&1 &
echo $!
```

等待约 30–60 秒后再检查：

```bash
ps -p <PID> -o pid=,stat=,etime=,command=
tail -n 60 /tmp/bds_acceleration_interface_verify.log
```

不要持续轮询或实时读取全部 warning。进程结束后检查退出码和完整的最终摘要。测试失败时停在当前阶段。

## 完成标准

本任务只有在以下条件全部满足时才算完成：

- 两个 helper 的接口经过逐字段审计，而非机械包装；
- 最终接口比当前接口更窄、更有层次、更容易审计；
- helper 不获得无关 solver state 或完整公共 `options`；
- 主 solver 中的 phase 状态交接清楚；
- acceleration on 与 `lean_evolved_bds.m` 完全一致；
- acceleration off 与 `bds.m` 完全一致；
- gradient-stop bookkeeping regression 通过；
- 没有修改任何无关代码和注释。
