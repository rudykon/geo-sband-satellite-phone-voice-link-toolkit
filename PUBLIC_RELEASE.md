# 开源项目说明

本仓库按公开 GitHub 开源项目使用场景整理，项目名称采用 `GEO S-Band Satellite Phone Voice Link Toolkit`，目标是把 Step 1 的 GEO S-band 卫星手机语音链路工具、参考输出和可选 MATLAB/Simulink 校验入口提供给其他研究者和工程用户直接使用。

- `README.md` 提供英文说明，`README.zh-CN.md` 提供中文说明。
- `expected_outputs/` 只包含 CSV 摘要和选定图件，不包含任何专有原始测量数据。
- `outputs/` 不随仓库提交，由 `python run_all.py` 在本地重新生成。
- MATLAB/Simulink 是可选流程；没有对应工具箱时，Python 主流程仍可独立运行。
- 论文 PDF 和投稿包仍由主项目的 `artifacts/releases/current/` 管理。

公开发布前，按目标仓库确认 README、许可证和引用信息即可。
