@echo off
setlocal
cd /d "%~dp0"

python -c "import numpy" >nul 2>nul
if errorlevel 1 (
  echo Missing lightweight dependency: numpy
  echo Run this once:
  echo   python -m pip install -r requirements-lite.txt
  pause
  exit /b 1
)

python quick_run.py
pause
