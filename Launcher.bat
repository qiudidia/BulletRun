@echo off
chcp 65001 >nul
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

echo 错误: 未找到 Python，请先安装 Python 3.x
echo 下载地址: https://www.python.org/downloads/
echo 安装时请勾选 "Add Python to PATH"
pause