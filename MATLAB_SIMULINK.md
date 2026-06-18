# MATLAB/Simulink 参考联合仿真

`matlab_step1/` 下的 MATLAB/Simulink 文件用于生成 Step 1 参考主可用性结果。Python 负责写入 input manifest、调用 MATLAB batch、校验 staging 输出并提升 canonical CSV/JSON。

推荐从仓库根目录运行：

```bash
python run_all.py
```

该流程需要 MATLAB、Simulink 和 Communications Toolbox。MATLAB 检测顺序为 `MATLAB_EXE`、`matlab` on `PATH`、`D:\matlab\bin\matlab.exe`。

MATLAB 严格入口为：

```matlab
cd("matlab_step1")
run_step1_cosim_strict("../outputs/matlab_step1/step1_cosim_input_manifest.json")
```

预期生成文件包括：

- `outputs/matlab_step1/voice_threshold_from_phy.csv`
- `outputs/matlab_step1/simulink_voice_availability.csv`
- `outputs/matlab_step1/step1_cosim_status.json`
- `outputs/geo_satphone/voice_availability.csv`
- `outputs/geo_satphone/step1_service_baseline.json`
- `outputs/geo_satphone/voice_availability_provenance.json`

`run_step1_phy_lms_upgrade` 和 LMS 相关脚本仍可用于附加信道验证，但不能替代 strict co-simulation 主路径。`--skip-matlab-step1` 仅用于 Python-only 开发调试，不会生成完整参考结果。
