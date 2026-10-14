@echo off
setlocal

set "PROJECT=%~dp0S32K144_Start.dpa"
set "CONFIGURATOR=G:\BSW_study_comstack_0331\AUTOSAR_TOOLs\AUTOSAR_TOOLs\S32K144_SIP\MICROSAR\CBD1800257_D01_S32K1xx\DaVinciConfigurator\Core\DaVinciCFG.exe"

if not exist "%PROJECT%" (
  echo Project file not found:
  echo %PROJECT%
  pause
  exit /b 1
)

if not exist "%CONFIGURATOR%" (
  echo DaVinci Configurator not found:
  echo %CONFIGURATOR%
  pause
  exit /b 1
)

start "DaVinci Configurator" "%CONFIGURATOR%" "%PROJECT%"
exit /b 0
