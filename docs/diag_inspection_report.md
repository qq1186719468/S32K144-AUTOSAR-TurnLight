# 当前转向灯工程诊断检查（只读审计）

## 当前工程证据
- `Config/ECUC/S32K144_Start_Dem_ecuc.arxml`: only event container `DTC_0x000002`, `DemEventId=1`, `DemEventKind=DEM_EVENT_KIND_SWC`, `DemEventAvailable=true`, `DemEventCreateInfoPort=true`; DTC class `DemUdsDTC=2` (DTC 0x000002), primary memory, priority 2, operation/aging cycle IgnitionCycle.
- Debounce is counter based: increment/decrement 1, JumpUp=true, behavior FREEZE, failed threshold 127, passed threshold -128, storage false, continuous false. A single `FAILED` report increments the FDC only and may not set UDS testFailed until threshold.
- `Config/ServiceComponents/Dem_swc.arxml` already provides service interface `/MICROSAR/Dem_swc/Interfaces/DiagnosticMonitor` with C/S operations `SetEventStatus(EventStatus)` and `ResetEventStatus`; `EventStatus` type `/MICROSAR/Dem_swc/DataTypes/Dem_EventStatusType`.
- `Config/Developer/ComponentTypes/TurnLight.arxml` has only P-port `TurnLampSwMode`, required inputs and TurnLightService C/S; no DiagnosticMonitor R-port. Thus current RTE has no `Rte_Call_TurnLight...SetEventStatus` for TurnLight.
- `Appl/Source/TurnLight.c` `TurnLightDiag` compares command/feedback (0 normal, 1 short, 2 open) and retries through `Rte_Call_TurnLightService_TurnLightControl_Operation`; it has no Dem call. It therefore cannot create DTC 0x000002.
- `Appl/GenData/Rte.c` Dcm DID 0x1000 callbacks are `RTE_E_UNCONNECTED` (LightOnOffCounter R/W), so DID 0x1000 is configured but not connected.

## 原始 StartApplication 参考证据
Path: `G:\BSW_study_comstack_0331\AUTOSAR_TOOLs\AUTOSAR_TOOLs\S32K144_SIP\MICROSAR\CBD1800257_D01_S32K1xx\Applications\SipAddon\StartApplication`
- `Config/ServiceComponents/StartApplication_swc.arxml` R-port `PpDiagnosticMonitor_DEM_EVENT_StartApplication` requires client-server interface `PiDiagnosticMonitor_DEM_EVENT_StartApplication`; it has `SetEventStatus(EventStatus)` and `ResetEventStatus()` and uses `Dem_EventStatusType`.
- Original source calls `(void)Rte_Call_PpDiagnosticMonitor_DEM_EVENT_StartApplication_SetEventStatus(DEM_EVENT_STATUS_FAILED/PASSED);` in `StartApplication_DIAG_OnDataRec_RxData`.
- Original Dem event `DEM_EVENT_StartApplication` has `DemEventId=56`, points to `DemDTCClass_StartApplication`, whose DTC is decimal 4729855 = hex `0x482BFF`.
- Original StartApplication CAN frames in `Config/System/Communication.arxml`: Rx frame `FT_msg_StartAppl_Rx_MyECU` identifier decimal 1281 = CAN ID `0x501`; Tx frame identifier decimal 1280 = `0x500`. Rx PDU has 8-byte DLC; `Signal_StartAppl_RxCtrl...` length 8, start position 0; `Signal_StartAppl_RxData...` length 8, start position 8 (second byte). Both mappings use `MOST-SIGNIFICANT-BYTE-LAST`, transfer property PENDING. `STARTAPPLICATION_ACTIVE_COMPONENT_DIAG` enum value = 2. In source, low two bits RxData: 0 passed, 1 failed, 2 reset counter.

## 将 TurnLightDiag 标准接入 Dem 的最小流程（不直接修改生成文件）
1. In DaVinci Developer, edit TurnLight component type: add required C/S port (e.g. `PpDiagnosticMonitor_DEM_EVENT_TurnLight`) whose required interface is `/MICROSAR/Dem_swc/Interfaces/DiagnosticMonitor`; map `SetEventStatus` and `ResetEventStatus` operations to TurnLight application.
2. In TurnLight SWC implementation/model, add an explicit diagnostic event output/request. For each lamp, aggregate faults or create four events. Current exercise simplest: reuse event ID 1/DTC 0x000002 for an aggregate TurnLight fault; report `DEM_EVENT_STATUS_FAILED` when any channel sees `feedback==1 (short)` or `==2 (open)` while command is ON; report `DEM_EVENT_STATUS_PASSED` after all channels normal. Do not call Dem directly from generated code; add RTE call in model's function-call subsystem or handwritten wrapper that is included as source (preserve generated-code workflow).
3. In DaVinci Configurator, map TurnLight's DiagnosticMonitor R-port to Dem event (event ID 1) and ensure `DemEventCreateInfoPort=true`, DemUseRte=true. If choosing separate channel DTCs, add DemEventParameter/DTCClass for each and map each port/event.
4. If keeping current counter debounce for demo, report FAILED every 10 ms while fault persists for 127 cycles (~1.27 s); or set failed/passed thresholds to 1/-1 in Configurator for quick bench demonstration (record this is a teaching setting). `DemEventMemoryEntryStorageTrigger=DEM_STORAGE_ON_TEST_FAILED` means DTC enters primary memory after threshold.
5. Generate RTE/BSW in Configurator and rebuild IAR; never hand-edit `Rte.c`, `Dem_Lcfg.c`, `Dcm_Lcfg.c`. Verify generated RTE has a TurnLight SetEventStatus call that returns not `RTE_E_UNCONNECTED` and inspect generated event id symbol.
6. TSMaster validation via existing diag IDs 0x610 request / 0x612 response: clear DTC first (`14 FF FF FF` request payload in ISO-TP); stimulate open/short feedback for >=127 cycles; read `19 01 01 00` (count should become 1), `19 02 01 00` (DTC 0x000002); read status byte with `19 06 01 00 00 00` or project-supported subfunction; restore normal and run passed threshold; check pending/testFailed transitions. Existing `19 01` and `19 02` already worked with 0 entries.
7. DID 0x1000 is independent; either connect its asynchronous C/S R-port to a real TurnLight data element (counter) via Developer/RTE, or leave it documented as configured-but-unconnected.

## 代码模型现状中的可疑连接（需在 Simulink 查证）
`Appl/Source/TurnLight.c` generated code around `TurnLightDiag`:
- RR branch at lines ~929-960 tests `tmpRead_6` (FL feedback) and `tmpRead_3` (FL command) instead of RR feedback/command.
- RL OPEN branch around line ~883 tests `tmpRead_3` (FL command) instead of RL command `tmpRead_5`.
These likely indicate Simulink signal-wire errors; fix the model and regenerate if channel-specific diagnostics are required.
