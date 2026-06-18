@echo off
setlocal
cd /d "%~dp0"

python -c "import streamlit, pandas" >nul 2>nul
if errorlevel 1 (
  echo Missing dashboard dependencies.
  echo Run this once:
  echo   python -m pip install -r requirements-dashboard.txt
  pause
  exit /b 1
)

python -m streamlit run app.py
