# 实验 1：Mcu + OS 的 10 ms Runnable 验证

## 实验目的

验证 Mcu 时钟、SysTick、OS Counter、OS Alarm/Event、RTE TimingEvent 和 Runnable 已经连通，并确认 `IoHwAbRunnable()` 的实际调用间隔约为 10 ms。

## 已加入的临时测试

文件：`Appl\Source\Cdd_IoHwAb.c`

Runnable：`IoHwAbRunnable()`

配置描述：`Config\Developer\ComponentTypes\Cdd_IoHwAb.arxml`

其中 TimingEvent 是每 10 ms 触发。临时代码每次调用翻转 PTD0：

```c
static uint8 testState = 0u;
testState = (uint8)!testState;
Dio_WriteChannel(DioConf_DioChannel_DioChannel_PTD0, testState);
```

备份文件：`Appl\Source\Cdd_IoHwAb.c.before_os10ms_test_20260915.bak`

## 一、编译前检查

1. 不要重新执行 Configurator Generate，避免重新生成 Cdd 模板。
2. 确认当前 IAR 工程是 `ASR_S32K144_Start.ewp`。
3. 确认 IAR 工程使用当前 G 盘目录，而不是 D 盘旧目录。
4. 检查 `Cdd_IoHwAb.c` 中存在 `TEMP_OS_10MS_TEST` 标记。

## 二、IAR 编译和下载

1. 打开 `ASR_S32K144_Start.ewp`。
2. 选择 `Project → Rebuild All`，确保 Cdd_IoHwAb.c 被重新编译。
3. 编译无错误后连接 S32K144 调试器。
4. 选择 `Project → Download and Debug`。
5. 运行程序，不发送 TSMaster CAN 报文。

如果编译报 `DioConf_DioChannel_DioChannel_PTD0` 未定义，说明 IAR 工程没有包含当前 `Appl\GenData` 或配置头文件路径，应先检查工程路径；不要改成硬编码的 112。

## 三、IAR 中确认 Runnable 被调用

1. 在 `IoHwAbRunnable()` 的 `testState = ...` 行设置断点。
2. 运行程序。
3. 如果断点不断命中，说明 OS 已经调度到该 Runnable。
4. 单步一次后继续运行，验证断点会再次命中。

断点只能证明“被调用”，不能精确证明 10 ms，因为 CPU 在断点处停止。精确周期要用 GPIO 波形或非侵入式计数观察。

## 四、逻辑分析仪测量

1. 找到开发板原理图中 PTD0 的测试点/排针，并连接逻辑分析仪通道。
2. 地线连接开发板 GND。
3. 输入量程选择 3.3 V 数字信号。
4. 运行程序，采样率建议至少 1 MHz。
5. 观察 PTD0 方波。

预期：

```text
上升沿到下降沿约 10 ms
下降沿到上升沿约 10 ms
完整周期约 20 ms
频率约 50 Hz
```

如果看到约 20 ms 的完整周期，说明 Runnable 是约 10 ms 调用一次。

## 五、为什么可能看不到干净波形

PTD0 同时是 FL 灯输出，`TurnLightAct`/`Cdd_IoHwAb` 的其他操作也可能写 PTD0。因此：

- 只做本实验时不要发送 CAN 转向控制报文；
- 如果波形被其他代码覆盖，优先在 IAR 中观察 `IoHwAbRunnable()` 是否命中；
- 需要更干净的波形时，可以临时把测试代码改到一个已配置但不参与应用输出的 GPIO，前提是先在 Port/Dio 中完成该引脚配置并重新生成。

## 六、结果判定

| 现象 | 结论 |
|---|---|
| 断点完全不命中 | Runnable 没有进入、RTE/OS 映射或启动流程有问题 |
| 断点命中但 PTD0 不变 | Port/Dio 初始化、引脚测点或其他代码覆盖问题 |
| PTD0 边沿约 10 ms | OS 10 ms 调度验证通过 |
| 周期约 1 ms | 测到的是 SysTick 或其他底层活动，不是该 Runnable |
| 周期约 20 ms 边沿间隔 | 可能把完整周期和边沿间隔混淆，需重新看测量游标 |

## 七、实验结束后的恢复

删除 `BEGIN TEMP_OS_10MS_TEST` 到 `END TEMP_OS_10MS_TEST` 之间的代码，或者用备份文件恢复：

```text
Appl\Source\Cdd_IoHwAb.c.before_os10ms_test_20260915.bak
```

恢复后重新编译并烧录，再继续 CAN/转向灯实验。

