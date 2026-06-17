# 公开发布说明

该复现包按公开 GitHub 仓库使用场景整理，可用于共享 Step 1 的数值复现脚本、参考输出和可选 MATLAB/Simulink 校验入口。

- `expected_outputs/` 只包含 CSV 摘要和选定图件，不包含任何专有原始测量数据。
- `outputs/` 不随仓库提交，由 `python run_reproduce.py` 在本地重新生成。
- MATLAB/Simulink 是可选流程；没有对应工具箱时，Python 复现仍可独立运行。
- 论文 PDF 和投稿包仍由主项目的 `artifacts/releases/current/` 管理。

公开发布前，按目标仓库确认 README、许可证和引用信息即可。
