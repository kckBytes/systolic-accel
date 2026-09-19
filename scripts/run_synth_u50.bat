@echo off
REM ===========================================================================
REM run_synth_u50.bat  --  OOC synth + place + route of `core` on the Alveo U50
REM
REM Usage (from anywhere):   scripts\run_synth_u50.bat [0|1] [period_ns]
REM   0 (default) : part2=0, the 4-bit x 4-bit configuration
REM   1           : part2=1, the 2x2-bit SIMD configuration
REM   period_ns   : clock period, default 4.000 (250 MHz); 3.106 = 322 MHz
REM
REM Outputs: _build\impl_u50_part<N>_<period>ns\  (reports + summary.txt + the
REM          generated .xdc + vivado.log / vivado.jou)
REM Wall time on this design: single-digit minutes.
REM ===========================================================================
setlocal EnableExtensions

SET "VIVADO_BIN=C:\AMDDesignTools\2025.2\Vivado\bin"
for %%I in ("%~dp0..") do SET "ROOT=%%~fI"
SET "P2=%~1"
IF "%P2%"=="" SET "P2=0"
SET "PER=%~2"
IF "%PER%"=="" SET "PER=4.000"
SET "OUT=%ROOT%\_build\impl_u50_part%P2%_%PER%ns"
if not exist "%OUT%" mkdir "%OUT%"
cd /d "%ROOT%"

echo ============================================
echo  core  ^>  xcu50-fsvh2104-2-e   part2=%P2%   period=%PER% ns
echo ============================================

REM -log / -journal must come BEFORE -tclargs; everything after -tclargs is $argv.
call "%VIVADO_BIN%\vivado.bat" -mode batch -notrace -log "%OUT%\vivado.log" -journal "%OUT%\vivado.jou" -source "scripts\synth_u50.tcl" -tclargs %P2% "%OUT%" %PER%
if errorlevel 1 goto :err

echo.
type "%OUT%\summary.txt"
goto :eof

:err
echo   [ERROR] vivado failed -- see %OUT%\vivado.log
exit /b 1
