# Step 1 开源复现包

该包用于复现 Step 1 稿件中的链路侧筛选产物，可直接作为公开 GitHub 仓库发布：

`Low-Tail Link-Closure Screening for Handheld GEO S-Band Direct-to-Cell Voice in Remote Areas`

其中包含用于 GEO S-band 链路预算、中断容量校验、投稿前敏感性检查的 Python 脚本，以及用于 Step 1 PHY/LMS 交叉校验的可选 MATLAB/Simulink 入口。

## 内容

- `src/`：用于重新生成 CSV 文件和图件的 Python 脚本。
- `matlab_step1/`：可选 MATLAB/Simulink 校验脚本和生成的模型文件。
- `expected_outputs/`：论文使用的 CSV 摘要和选定参考图。
- `run_reproduce.py`：一键 Python 复现入口。
- `PUBLIC_RELEASE.md`：公开发布范围和注意事项。

## Python 复现

安装依赖：

```bash
python -m pip install -r requirements.txt
```

运行：

```bash
python run_reproduce.py
```

脚本会把重新生成的产物写入该包内部的 `outputs/`。重点检查目标包括：

- `outputs/geo_satphone/screening_baseline_comparison.csv`
- `outputs/geo_satphone/screening_sensitivity_ranking.csv`
- `outputs/geo_satphone/dwell_time_sensitivity.csv`
- `outputs/plots/geo_satphone_c0p01_sensitivity_ranking.pdf`
- `outputs/plots/geo_satphone_dwell_time_sensitivity.pdf`

## 可选 MATLAB/Simulink 校验

MATLAB 路径是可选流程，需要已安装 MATLAB 和 Simulink。参考 PHY（reference PHY）门限校准还需要 Communications Toolbox。在 MATLAB 中运行：

```matlab
cd("matlab_step1")
run_step1_phy_lms_upgrade
```

如果所需产品已安装，该命令会在 `outputs/matlab_step1/` 下重新生成 PHY/LMS 校验摘要。

## 范围说明

该包用于系统级筛选复现，不是厂商终端实现，也不是现场测试数据。弱代理参数（proxy parameters）会在敏感性扫描中显式暴露，以便未来获得终端实测和地形轨迹数据后直接替换。
