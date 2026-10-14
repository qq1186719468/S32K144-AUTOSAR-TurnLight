# 实验 1：在 DaVinci Configurator 中检查/配置 Mcu 时钟

## 目标

当前 S32K144 工程的目标时钟为：

```text
SOSC 输入       8 MHz
SPLL 内部       160 MHz
RUN Core        80 MHz
RUN Bus         40 MHz
RUN Flash       20 MHz
LPSPI1          40 MHz
```

## 打开工程

双击：

```text
G:\S32K144_Start_TurnLight_IAR_20260912\S32K144_Start_new_IAR\OpenConfigurator.bat
```

窗口标题应为 `DaVinci Configurator Pro.RTE`。选择左侧 **Configuration Editors**，展开 Mcu 模块。

## 配置顺序

```text
Mcu
└─ McuModuleConfiguration
   └─ McuClockSettingConfig_0
      ├─ McuSystemOSCClockConfig
      ├─ McuSystemPll
      ├─ McuRunClockConfig
      ├─ McuFIRCClockConfig
      ├─ McuSIRCClockConfig
      └─ McuPeripheralClockConfig
```

每修改一项就保存并 Validate。频率结果字段若为灰色，由输入源、倍频或分频自动计算，不要直接编辑结果。

## 1. McuGeneralConfiguration

| 参数 | 设置 |
|---|---|
| McuInitClock | true |
| McuNoPll | false |
| McuDevErrorDetect | false（当前基线） |
| McuTimeout | 50000 |
| McuEnterLowPowerMode | true（当前基线） |

`McuInitClock=true` 表示启动时执行时钟初始化；`McuNoPll=false` 表示允许使用 SPLL。

## 2. McuSystemOSCClockConfig

| 参数 | 设置 |
|---|---:|
| McuSOSCEnable | true |
| McuSOSCFrequency | 8000000 |
| McuSOSCExternalReferenceSelect | false |
| McuSOSCHighGainOscillatorSelect | false |
| McuSOSCRangeSelect | HIGH_FREQ_RANGE |
| McuSOSCUnderMcuControl | true |
| McuSOSCDiv1 | 1 |
| McuSOSCDiv2 | 2 |

这里的 `false` 表示使用晶振振荡器模式，不是外部旁路时钟模式。若原理图实际没有 8 MHz 晶振，必须按原理图修改，不能照抄本表。

## 3. McuSystemPll

| 参数 | 设置 |
|---|---:|
| McuSPLLEnable | true |
| McuSPLLInputClkPreDivider | 1 |
| McuSPLLInputFrequency | 8000000 |
| McuSPLLMultiplier | 40 |
| McuSPLLFrequency | 160000000（自动计算） |
| McuSPLLDiv1 | 4 |
| McuSPLLDiv1Frequency | 40000000（自动计算） |
| McuSPLLDiv2 | 4 |
| McuSPLLDiv2Frequency | 40000000（自动计算） |
| McuSystemPllUnderMcuControl | true |
| McuSPLLClockMonitorEnable | false（当前基线） |

计算关系：

```text
8 MHz × 40 = 320 MHz VCO
SPLL 输出 = 320 MHz / 2 = 160 MHz
SPLL DIV1/DIV2 = 160 MHz / 4 = 40 MHz
```

Configurator 可能把 VCO 的内部除 2 隐藏在 PLL 参数中，所以以界面显示的合法组合和频率结果为准。

## 4. McuRunClockConfig

这是正常 RUN 模式，也是当前工程实际使用的模式。

| 参数 | 设置 |
|---|---:|
| McuSystemClockSwitch | SPLL |
| McuPreDivSystemClockFrequency | 160000000 |
| McuSystemClockFrequency | 80000000（自动计算） |
| McuCoreClockDivider | 2 |
| McuCoreClockFrequency | 80000000 |
| McuBusClockDivider | 2 |
| McuBusClockFrequency | 40000000 |
| McuFlashClockFrequency | 20000000 |
| McuSlowClockDivider | 4 |
| McuScgClkOutFrequency | 20000000 |

计算关系：

```text
Core  = 160 MHz / 2 = 80 MHz
Bus   = 160 MHz / 4 = 40 MHz
Flash = 160 MHz / 8 = 20 MHz
```

## 5. 其他时钟模式

当前 ARXML 还保存了两个模式的参数：

- `McuHsrunClockConfig`：48 MHz Core、48 MHz Bus，当前没有作为启动模式使用。
- `McuVlprClockConfig`：4 MHz 低功耗模式，当前不用于转向灯实验。

`McuNumberOfMcuModes=1` 表示工程只建立一个实际 MCU 模式；这些子容器是供应商配置模型的一部分，不要因为看到 HSRUN/VLPR 就切换当前 RUN 配置。

## 6. McuPeripheralClockConfig

只关注工程实际用到的外设：

| 外设 | Enable | Clock Select | Divider | 结果 |
|---|---|---|---:|---:|
| LPSPI1 | true | SPLL | 1 | 40 MHz |

FlexCAN0 的 CAN 位时序在 Can 模块中使用 SystemClock 配置；Mcu 中其它未使用外设保持供应商默认值即可，不要为了“全部打开”而修改。

## 7. 保存、校验、生成

本次第一次学习建议：

1. 只核对上述值，不改变值。
2. `Ctrl+S` 保存。
3. 点击 **Validate**，确认没有红色错误。
4. 暂不点击 **Generate**，先截图记录 Mcu 页面。

如果确实修改了参数，才执行 **Generate**，然后重新编译 IAR。生成后查看：

```text
Appl\GenData\Mcu_PBcfg.c
Appl\GenData\Mcu_Cfg.h
```

## 8. IAR 验证点

在 IAR 设置断点：

```text
Mcu_Init()
Mcu_InitClock(0)
Mcu_DistributePllClock()
```

确认程序能依次执行，不进入 Mcu 错误处理。随后再验证 SysTick/OS 的 1 ms 节拍。

当前 ARXML 备份：

```text
Config\ECUC\S32K144_Start_Mcu_ecuc.arxml.before_mcu_clock_walkthrough_20260915.bak
```
