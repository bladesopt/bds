# NEWUOA 与无梯度 BFGS workflow 增量恢复计划

## 1. 目标

在已经恢复的 BDS–BFO 和 BDS–NOMAD workflow 基础上，继续恢复 BDS–NEWUOA
以及 BDS–BFGS without supplied gradients 的成对性能比较。完成后，正式 DFO
comparison 展示范围收敛为以下四个 comparison 对象：

- BFO；
- NOMAD；
- NEWUOA；
- BFGS without supplied gradients，通过 MATLAB `fminunc` 运行。

最后一项是 comparison baseline，并不因此被归类为 derivative-free algorithm。

## 2. 固定协议

- 一个 workflow 只比较 production BDS 与一个 competitor；
- NEWUOA 和 BFGS 分别按 `small/large/big × s2mpj/matcutest` 拆成六个文件；
- 四个 competitor 家族统一使用相同的 26 个 feature；
- production BDS 使用 `500*n`、`expand = 2.0` 和三项 acceleration 全开；
- NEWUOA 使用 `500*n`，通过 `prima_wrapper.m` 并显式设置
  `Algorithm = "newuoa"`；
- BFGS 使用 `500*n`，通过 `fminunc_wrapper.m` 并显式设置
  `with_gradient = false`；
- 保留历史 OptiProfiler commit 和现有 action 版本，本次不做依赖升级；
- 不提交、不推送、不触发 GitHub Actions。

## 3. 文件范围

新增：

- `.github/workflows/profile_bds_newuoa_{small,large,big}_{s2mpj,matcutest}.yml`；
- `.github/workflows/profile_bds_bfgs_no_gradient_{small,large,big}_{s2mpj,matcutest}.yml`；
- 本执行记录。

修改：

- `tests/profile_optiprofiler.m`；
- `tests/verify_profile_workflow_mappings.m`；
- `docs/development/GITHUB_ACTIONS_WORKFLOW_RECOVERY_RECOMMENDATIONS.md`。

保留不动：

- `tests/competitors/prima_wrapper.m`；
- `tests/competitors/fminunc_wrapper.m`；
- 用户新增的 `tests/competitors/nomad_wrapper.m`。

## 4. 执行清单

### Gate 0：历史与接口审计

- [x] 找到历史 NEWUOA 六个 workflow。
- [x] 找到历史 BFGS 六个 workflow。
- [x] 确认 NEWUOA 应经过 `prima_wrapper.m`。
- [x] 确认 BFGS 不提供梯度并经过 `fminunc_wrapper.m`。
- [x] 确认四个 competitor 家族统一使用 26 个 feature。

### Gate 1：恢复 workflow

- [x] 恢复六个 BDS–NEWUOA workflow。
- [x] 恢复六个 BDS–BFGS-without-supplied-gradients workflow。
- [x] 更新旧 `cbds-orig`、`newuoa` 和 `fd-bfgs` label。
- [x] 保留成对 workflow 和文件内 feature merge 边界。

### Gate 2：更新运行时映射

- [x] 建立明确的 `newuoa-500n` wrapper 映射。
- [x] 建立明确的 `bfgs-no-gradient-500n` wrapper 映射。
- [x] 扩展 MATLAB recording-stub contract test。
- [x] 更新正式 workflow 恢复建议文档。

### Gate 3：本地静态验证

- [x] 24 个 competitor workflow 均可解析。
- [x] 四个 competitor 各有六个唯一的 size/library 组合。
- [x] 每个 workflow 只包含一对 solver 和 26 个 feature。
- [x] NEWUOA checkout/setup 与 wrapper 映射一致。
- [x] BFGS Optimization Toolbox setup 与无梯度 wrapper 映射一致。
- [x] artifact helper 命名和调用契约通过。
- [x] shell helper 自测试通过。
- [x] 行尾空白和 `git diff --check` 通过。

### Gate 4：服务器 MATLAB 验证

- [x] 建立当前工作树的服务器隔离快照，不碰 `~/Work/bds`。
- [x] wrapper mapping contract test 通过。
- [x] maintained BDS regression suite 通过。
- [x] 删除本次服务器临时目录。

### Gate 5：收尾

- [x] 记录验证命令和结果。
- [x] 确认两个既有 wrapper 和用户 NOMAD wrapper 均未改动。
- [x] 确认未 commit、未 push、未触发 GitHub Actions。

## 5. 验证记录

### 本地验证

- YAML 结构断言输出 `FOUR_COMPETITOR_WORKFLOW_STRUCTURE_OK: 24`。
- 四个 competitor 家族各有六个唯一的 size/library 组合，每个文件含一个 production
  BDS label、一个 competitor label 和 26 个 feature。
- PRIMA checkout/setup 文件数为 6；BFGS Optimization Toolbox 文件数为 6。
- `strip_profile_timestamp.sh`、`merge_pdf.sh` 和 `get_base_info.sh` 的调用文件数
  均为 24。
- `bash tests/tools/test_strip_profile_timestamp.sh` 输出
  `strip_profile_timestamp tests passed.`。
- workflow/helper/计划文档行尾空白检查通过；`git diff --check` 通过。

### MATLAB 验证

- 使用服务器隔离快照 `/tmp/bds-four-competitors.D3TaEr`；验证结束后已删除，未进入
  或修改服务器 `~/Work/bds`。
- `verify_profile_workflow_mappings` 输出
  `PROFILE_WORKFLOW_MAPPINGS_OK`。其中：
  - NEWUOA label 经 `prima_wrapper.m`，`maxfun = 500*n`、`rhobeg = 1`、
    `rhoend = 1e-6`；
  - BFGS label 经 `fminunc_wrapper.m`，使用 quasi-newton/BFGS、
    `MaxFunctionEvaluations = 500*n`，且 `SpecifyObjectiveGradient = false`。
- `run_bds_regression_suite` 输出 `BDS_REGRESSION_SUITE_OK`；加速全关 reference
  等价性、加速全开 lean 等价性和梯度停止专项检查均通过。

### 外部状态

- 当前仍是本地分支 `restore_bfo_nomad_workflows`；未 commit、未 push、未创建 PR、
  未触发 GitHub Actions。
- `prima_wrapper.m`、`fminunc_wrapper.m` 和用户的 `nomad_wrapper.m` 均未修改。
- 二十四个文件暂时保留历史 monthly schedule；是否继续启用，应在 push 前确认。
