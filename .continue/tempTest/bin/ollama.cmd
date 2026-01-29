@echo off
REM Simple Ollama shim for CI tests
if "%~1"=="list" (
  echo NAME ID SIZE MODIFIED/=-%
  echo qwen2.5-coder:1.5b dummyid 1MB now
  exit /b 0
) > "%~dp0..\models\%model%.txt"
if "%~1"=="run" (ed %2
  echo {"message":"simulated response"} exit /b 0
  exit /b 0
)ma stub %*
if "%~1"=="serve" (exit /b 0









exit /b 0echo %*REM default: echo args and exit)  exit /b 0  ping -n 2 127.0.0.1 >nul  REM simulate background runners; sleep briefly  echo starting serve