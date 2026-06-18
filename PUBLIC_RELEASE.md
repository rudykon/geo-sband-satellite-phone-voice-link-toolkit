# 开源项目说明

本仓库按公开 GitHub 开源项目使用场景整理，项目名称采用 `GEO S-Band Satellite Phone Voice Link Toolkit`，目标是把 GEO S-band 卫星手机语音链路筛选工具、参考输出和 MATLAB/Simulink 参考联合仿真入口提供给其他研究者和工程用户直接使用。

- `README.md` 提供英文说明，`README.zh-CN.md` 提供中文说明。
- `expected_outputs/` 只包含 CSV 摘要和选定图件，不包含任何专有原始测量数据。
- `outputs/` 不随仓库提交，由 `python run_all.py` 在本地重新生成。
- 完整参考流程需要 MATLAB、Simulink 和 Communications Toolbox；`--skip-reference-cosim` 仅用于 Python-only 开发调试，不生成完整参考结果。
- 论文 PDF 和投稿包仍由主项目的 `artifacts/releases/current/` 管理。

公开发布前，按目标仓库确认 README、许可证和引用信息即可。
