# BFO 与 NOMAD workflow 恢复执行计划

## 1. 目标

从历史提交 `81c3ef7bbb90faa3947160cbeabfaa080422bbba` 中找回 BDS 与 BFO、NOMAD 的成对性能比较 workflow，并在当前代码结构下恢复为可维护的正式候选版本。

恢复后的组织原则固定如下：

- 一个 workflow 只比较当前生产版 BDS 与一个 competitor；
- BFO 和 NOMAD 彼此独立，不能塞进同一个总 workflow；
- 每个 competitor 按问题规模 `small`、`large`、`big` 和问题库 `s2mpj`、`matcutest` 拆成六个 workflow；
- 每个 workflow 内通过 feature matrix 运行同一对 solver 在不同问题特征下的比较；
- merge job 只合并同一个 competitor、同一个问题规模、同一个问题库下各 feature 的图；
- 当前阶段保留历史 OptiProfiler commit `5a19e88c`，NOMAD 版本与构建方式另行专项升级，不在本次恢复中顺带改动。

## 2. 变更边界

本次需要恢复或修改：

- `.github/workflows/profile_bds_bfo_{small,large,big}_{s2mpj,matcutest}.yml`；
- `.github/workflows/profile_bds_nomad_{small,large,big}_{s2mpj,matcutest}.yml`；
- `tests/tools/strip_profile_timestamp.sh`；
- `tests/tools/get_base_info.sh`；
- `tests/tools/merge_pdf.sh`；
- `tests/tools/test_strip_profile_timestamp.sh`；
- `tests/profile_optiprofiler.m` 中生产版 BDS、BFO 和 NOMAD 的正式 profile 映射；
- `tests/verify_profile_workflow_mappings.m` 中无需外部 solver 的映射 contract test；
- `docs/development/GITHUB_ACTIONS_WORKFLOW_RECOVERY_RECOMMENDATIONS.md` 中与正式候选清单不一致的表述。

本次不做：

- 不把所有 competitor 合并到单个 workflow；
- 不引入 BOBYQA；
- 不把有限差分 BFGS 描述成 DFO solver；
- 不升级 OptiProfiler、NOMAD 或 GitHub Action 版本；
- 不提交、不推送、不创建 PR，也不触发 GitHub Actions；
- 不改动服务器现有的脏工作树；
- 不主动改写用户新增的 `tests/competitors/nomad_wrapper.m`。

## 3. 执行清单

### Gate 0：建立可追踪的执行现场

- [x] 确认分支、远端基线和现有未提交文件归属。
- [x] 创建本计划，并记录明确的恢复边界。
- [x] 从 `main` 创建本地工作分支 `restore_bfo_nomad_workflows`，避免后续修改直接堆在 `main` 上。

### Gate 1：恢复公共 artifact 工具

- [x] 从历史提交恢复四个公共脚本。
- [x] 执行 `bash -n` 静态语法检查。
- [x] 执行 timestamp stripping 自测试。
- [x] 检查脚本权限及 workflow 调用契约。

### Gate 2：恢复十二个成对比较 workflow

- [x] 恢复六个 BDS–BFO workflow。
- [x] 恢复六个 BDS–NOMAD workflow。
- [x] 将历史 `orig_cbds` 命名更新为当前生产版 BDS 的明确命名。
- [x] 保留 `small/large/big × s2mpj/matcutest` 的拆分边界。
- [x] 保留每个 workflow 内 26 个 feature，以及只合并该 workflow feature 图的 merge job。

### Gate 3：更新 solver 映射与文档

- [x] 在 `tests/profile_optiprofiler.m` 中建立显式的生产版 BDS profile 配置，固定 `500*n` 与 `expand = 2.0`。
- [x] 让 BFO profile 通过 `tests/competitors/bfo_wrapper.m` 调用。
- [x] 让 NOMAD profile 通过 `tests/competitors/nomad_wrapper.m` 调用。
- [x] 更新 workflow 恢复建议文档，使其反映“一个 competitor 一组 workflow”的正式架构。

### Gate 4：本地静态与结构验证

- [x] YAML 可解析。
- [x] workflow 数量、命名、规模和问题库组合完整且无重复。
- [x] 每个 workflow 只包含一对 solver。
- [x] 每个 workflow 含 26 个 feature。
- [x] merge job 只依赖本 workflow 的 profile job，并按 feature 合并 artifact。
- [x] BFO/NOMAD 安装步骤、MATLAB path 和 wrapper 映射一致。
- [x] 执行 shell helper 自测试。
- [x] 执行 `git diff --check`。

### Gate 5：服务器 MATLAB 验证

- [x] 在服务器临时目录建立当前本地工作树的隔离快照，不碰 `~/Work/bds`。
- [x] 对 profile driver 和 competitor wrapper 执行 MATLAB 语法/接口预检。
- [x] 执行当前生产版 BDS 的核心回归检查。
- [x] 执行加速全关与 reference BDS 的等价性检查。
- [x] 执行加速全开与 `lean_evolved_bds.m` 的等价性检查。
- [x] 执行梯度停止相关测试。
- [x] 删除本次创建的服务器临时目录。

### Gate 6：收尾审计

- [x] 汇总所有新增、修改和保留未动的文件。
- [x] 在本计划中记录验证命令和结果。
- [x] 确认没有提交、推送或触发远端 workflow。

## 4. 验证记录

### 本地结构验证

- 基线：本地分支 `restore_bfo_nomad_workflows` 从 `988b2629` 建立，与
  `origin/main` 指向同一提交；分支上没有新 commit。
- Ruby YAML 解析与结构断言：通过。共识别 12 个 workflow 和 12 个唯一的
  `competitor × size × library` 组合。
- 每个 workflow 的 solver 数量为 1、competitor 数量为 1、feature 数量为 26，
  `merge_artifacts.needs` 为当前文件中的 `test` job：通过。
- BFO checkout 文件数为 6；NOMAD checkout 和 MATLAB interface build 文件数均为
  6；三个 artifact helper 的 workflow 调用文件数均为 12。
- `bash -n tests/tools/*.sh`：通过。
- `bash tests/tools/test_strip_profile_timestamp.sh`：输出
  `strip_profile_timestamp tests passed.`。
- `git diff --check`：通过。

### 服务器 MATLAB 验证

- MATLAB：R2026a (`26.1.0.3203278`)。
- 隔离快照：`/tmp/bds-workflow-restore.Nppwep`，验证结束后已删除；没有进入或修改
  服务器 `~/Work/bds`。
- `verify_profile_workflow_mappings`：输出
  `PROFILE_WORKFLOW_MAPPINGS_OK`。运行时确认：
  - production BDS 使用 `500*n`、`expand = 2.0`、三项 acceleration 全开；
  - optional function-value/gradient stopping 全关；
  - BFO label 经过 `bfo_wrapper.m`，预算为 `500*n`；
  - NOMAD label 经过 `nomad_wrapper.m`，`MAX_BB_EVAL` 和 `max_eval` 均为
    `500*n`。
- `run_bds_regression_suite`：输出 `BDS_REGRESSION_SUITE_OK`。其中：
  - source unit tests 和 focused verifiers 全部通过；
  - 梯度 reference、无额外评价和 stopping threshold 三项检查通过；
  - acceleration 全关时，`bds.m` 与
    `bds_without_acceleration_reference.m` 在 CBDS/PBDS/RBDS/PADS/DS 上一致；
  - acceleration 全开时，`bds.m` 与 `lean_evolved_bds.m` 在默认配置和显式
    CBDS 配置上均一致。

### 外部状态

- 未 commit、未 push、未创建 PR、未触发 GitHub Actions。
- 用户新增的 `tests/competitors/nomad_wrapper.m` 保持原样；本次只让 profile 映射
  调用它。
