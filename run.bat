@echo off
chcp 65001 >nul
title Windows Server 2022 优化 - 启动器

:: 若已携带 --elevated 参数，表示已通过权限重启，直接运行
if /i "%~1"=="--elevated" goto :run

:: 检测管理员权限
powershell -NoProfile -ExecutionPolicy Bypass -Command "if(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 0}else{exit 1}"
if %errorlevel% equ 0 goto :run

echo ============================================================
echo   需要管理员权限，正在以管理员身份重新启动...
echo   请在随后弹出的 UAC 对话框中点击"是"
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '--elevated' -Verb RunAs"
pause
exit /b

:run
set "PS1=%~dp0optimize.ps1"
if not exist "%PS1%" (
    echo [错误] 未找到 optimize.ps1，请确保它和本文件在同一目录。
    pause
    exit /b 1
)
echo 正在以管理员权限执行 optimize.ps1 ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
if %errorlevel% neq 0 (
    echo.
    echo [警告] PowerShell 脚本退出码: %errorlevel%
    echo 请查看 C:\optimize_log.txt 了解详情。
    pause
)
