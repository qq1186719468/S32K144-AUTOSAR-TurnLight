# 外部底软依赖

本目录只保存项目自有代码和生成配置。下列模块在 IAR 工程中被引用，但实现源码应从原授权安装目录恢复。

## AUTOSAR BSW

- BswM
- Can、CanIf、CanSM、CanTp、CanTrcv
- Com、ComM、PduR
- Dcm、Dem、Det、Crc
- EcuM、OS
- NvM、MemIf、Ea、EEP
- Nm、NmOsek
- RamTst、WdgIf、WdgM
- VStdLib 及公共 AUTOSAR 类型/内存映射头文件

项目专用的 BSW 配置位于 `Appl/GenData/` 与 `Config/ECUC/`。

## MCAL

IAR 工程直接引用以下 S32K1xx MCAL 模块：

- Dio
- Mcu
- Port
- Spi

对应项目配置位于 `Appl/GenData/src/` 和 `Appl/GenData/include/`。其他配置中出现的 MCAL 模块应按实际 ECUC 变体和生成结果补齐。

## Device 与工具链

- S32K1xx 启动文件、CMSIS/设备寄存器头文件和链接脚本
- IAR Embedded Workbench for Arm
- AUTOSAR 配置工具与匹配的 SIP/MCAL 包
- MATLAB/Simulink/Stateflow（仅重新生成应用代码时需要）

这些依赖的版本、补丁和许可证必须与原工程环境保持一致。
