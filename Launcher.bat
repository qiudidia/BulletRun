@echo off
title Bullet Run Launcher

where python >nul 2>nul
if %errorlevel% equ 0 (
    python launcher.py
    pause
    exit /b
)

where python3 >nul 2>nul
if %errorlevel% equ 0 (
    python3 launcher.py
    pause
    exit /b
)

echo ERROR: Python not found. Please install Python 3.x first.
echo Download: https://www.python.org/downloads/
echo Make sure to check "Add Python to PATH" during installation.
pause