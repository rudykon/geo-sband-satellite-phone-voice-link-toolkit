# 可选 MATLAB/Simulink 校验

当本机已安装所需产品时，`matlab_step1/` 下的 MATLAB/Simulink 文件可重新生成论文中的参考 PHY（reference PHY）和 LMS 交叉校验结果。

推荐入口：

```matlab
cd("matlab_step1")
run_step1_phy_lms_upgrade
```

预期生成文件包括：

- `outputs/matlab_step1/voice_threshold_from_phy.csv`
- `outputs/matlab_step1/lms_channel_availability.csv`
- `outputs/matlab_step1/lms_simulink_channel_availability.csv`
- `outputs/matlab_step1/three_way_alignment.csv`

该校验是参考 coded-QPSK（reference coded-QPSK）与 LMS 的系统级一致性检查，不是专有手机终端解调器标定。
