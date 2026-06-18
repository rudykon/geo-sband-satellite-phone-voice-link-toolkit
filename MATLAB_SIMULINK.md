# MATLAB/Simulink 参考联合仿真

`matlab_voice_link/` 下的 MATLAB/Simulink 文件用于生成语音链路参考可用性结果。Python 负责写入 input manifest、调用 MATLAB batch、校验 staging 输出并提升 canonical CSV/JSON。

推荐从仓库根目录运行：

```bash
python run_all.py
```

该流程需要 MATLAB、Simulink 和 Communications Toolbox。MATLAB 检测顺序为 `MATLAB_EXE`、`matlab` on `PATH`、`D:\matlab\bin\matlab.exe`。

MATLAB 严格入口为：

```matlab
cd("matlab_voice_link")
run_voice_link_reference_cosim("../outputs/matlab_voice_link/voice_link_cosim_manifest.json")
```

预期生成文件包括：

- `outputs/matlab_voice_link/voice_threshold_from_phy.csv`
- `outputs/matlab_voice_link/simulink_voice_availability.csv`
- `outputs/matlab_voice_link/voice_link_cosim_status.json`
- `outputs/geo_satphone/voice_availability.csv`
- `outputs/geo_satphone/voice_link_reference_baseline.json`
- `outputs/geo_satphone/voice_availability_provenance.json`

`run_phy_lms_alignment` 和 LMS 相关脚本仍可用于附加信道验证，但不能替代 strict co-simulation 主路径。`--skip-reference-cosim` 仅用于 Python-only 开发调试，不会生成完整参考结果。
