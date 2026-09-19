@echo off
REM ===========================================================================
REM run_sim_core.bat  --  compile + run core_tb under Xilinx xsim (Vivado 2025.2)
REM
REM Usage (from anywhere):   scripts\run_sim_core.bat [part1|part2]
REM   part1 (default) : part2=0, 4-bit weight x 4-bit activation
REM   part2           : part2=1, 2x2-bit activation SIMD
REM Both have a golden out.txt from tb\gen\ref_model.py and self-check 16 maps.
REM
REM The testbench opens activation.txt / weight_k*.txt / out.txt / acc_scan.txt
REM by bare name, so the vectors are copied into the build dir and everything
REM runs from there. The project root is derived from this script's location.
REM
REM Outputs:  _build\sim_<cfg>\log_xvlog.txt, log_xelab.txt, log_xsim.txt, core_tb.vcd
REM ===========================================================================
setlocal EnableExtensions

SET "VIVADO_BIN=C:\AMDDesignTools\2025.2\Vivado\bin"
for %%I in ("%~dp0..") do SET "ROOT=%%~fI"
SET "CFG=%~1"
IF "%CFG%"=="" SET "CFG=part1"
IF /I "%CFG%"=="part1" ( SET "P2=0" ) ELSE IF /I "%CFG%"=="part2" ( SET "P2=1" ) ELSE ( echo usage: %~nx0 [part1^|part2] & exit /b 2 )

SET "BUILD=%ROOT%\_build\sim_%CFG%"
if not exist "%BUILD%" mkdir "%BUILD%"
cd /d "%BUILD%"

echo ============================================
echo  core_tb   config=%CFG%  (part2=%P2%)
echo ============================================

copy /Y "%ROOT%\tb\vectors\%CFG%\*.txt" "%BUILD%\" > nul

REM absolute filelist for this machine, generated from the relative one
(for /f "usebackq eol=# tokens=*" %%L in ("%ROOT%\scripts\filelist_core.f") do @echo %ROOT%\%%L) > "filelist_abs.f"

call "%VIVADO_BIN%\xvlog.bat" --work work_sa -f "filelist_abs.f" > "log_xvlog.txt" 2>&1
if errorlevel 1 goto :err

call "%VIVADO_BIN%\xelab.bat" --debug typical --timescale 1ns/1ps --generic_top "part2=%P2%" --snapshot core_tb_%CFG% work_sa.core_tb > "log_xelab.txt" 2>&1
if errorlevel 1 goto :err

call "%VIVADO_BIN%\xsim.bat" core_tb_%CFG% --runall --nolog > "log_xsim.txt" 2>&1
if errorlevel 1 goto :err

echo ---- verdict lines ----
C:\Windows\System32\findstr.exe /C:"matched" /C:"ERROR" /C:"No error" /C:"Project Completed" /C:"Error" "log_xsim.txt"
echo ---- full log: %BUILD%\log_xsim.txt
goto :eof

:err
echo   [ERROR] compile/elaborate/run failed -- see %BUILD%\log_*.txt
exit /b 1
