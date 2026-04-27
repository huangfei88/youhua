@echo off
chcp 65001 >nul
title Windows Server 2022 一键精简优化

:: ============================================================
:: 自动请求管理员权限
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 正在请求管理员权限，请在弹出窗口中点击"是"...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo ============================================================
echo   Windows Server 2022 一键精简优化脚本
echo   Azure 2核1G 低配虚拟机专用
echo ============================================================
echo.

:: 调用内嵌 PowerShell 脚本
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"& { ^
$ErrorActionPreference = 'SilentlyContinue'; ^
^
Write-Host ''; ^
Write-Host '【1/9】正在切换系统语言为简体中文...' -ForegroundColor Cyan; ^
Set-WinSystemLocale zh-CN; ^
Set-WinUILanguageOverride -Language zh-CN; ^
Set-Culture zh-CN; ^
Set-WinUserLanguageList zh-CN -Force; ^
Set-TimeZone -Id 'China Standard Time'; ^
Write-Host '  语言已设置为简体中文，时区已设置为中国标准时间（UTC+8）' -ForegroundColor Green; ^
^
Write-Host ''; ^
Write-Host '【2/9】正在禁用不必要的服务...' -ForegroundColor Cyan; ^
$services = @( ^
    'Themes','TabletInputService','Fax','PrintSpooler', ^
    'WSearch','SysMain','DiagTrack','dmwappushservice', ^
    'RetailDemo','MapsBroker','lfsvc','SharedAccess', ^
    'RemoteRegistry','XboxGipSvc','XblAuthManager', ^
    'XblGameSave','XboxNetApiSvc','wuauserv','UsoSvc', ^
    'DoSvc','WerSvc','PcaSvc','BDESVC','EFS','TrkWks', ^
    'CertPropSvc','SCPolicySvc','SCardSvr','wisvc', ^
    'WMPNetworkSvc','icssvc','PhoneSvc','RmSvc', ^
    'SensorDataService','SensrSvc','SensorService' ^
); ^
foreach ($svc in $services) { ^
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue; ^
    if ($s) { ^
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue; ^
        Set-Service  -Name $svc -StartupType Disabled; ^
        Write-Host \"  已禁用服务: $svc\" -ForegroundColor Gray; ^
    } ^
}; ^
^
Write-Host ''; ^
Write-Host '【3/9】正在关闭不必要的 Windows 功能...' -ForegroundColor Cyan; ^
$features = @( ^
    'Internet-Explorer-Optional-amd64', ^
    'MediaPlayback','WindowsMediaPlayer', ^
    'Printing-PrintToPDFServices-Features', ^
    'Printing-XPSServices-Features', ^
    'WorkFolders-Client','FaxServicesClientPackage' ^
); ^
foreach ($f in $features) { ^
    Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null; ^
    Write-Host \"  已关闭功能: $f\" -ForegroundColor Gray; ^
}; ^
^
Write-Host ''; ^
Write-Host '【4/9】正在调整视觉效果为最佳性能...' -ForegroundColor Cyan; ^
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 -ErrorAction SilentlyContinue; ^
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0' -ErrorAction SilentlyContinue; ^
Write-Host '  视觉效果已设置为最佳性能' -ForegroundColor Green; ^
^
Write-Host ''; ^
Write-Host '【5/9】正在设置页面文件（虚拟内存 2048MB）...' -ForegroundColor Cyan; ^
$cs = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges; ^
$cs.AutomaticManagedPagefile = $false; ^
$cs.Put() | Out-Null; ^
Get-WmiObject -Class Win32_PageFileSetting -ErrorAction SilentlyContinue | ForEach-Object { $_.Delete() }; ^
Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{ Name='C:\pagefile.sys'; InitialSize=2048; MaximumSize=2048 } | Out-Null; ^
Write-Host '  页面文件已固定为 2048MB' -ForegroundColor Green; ^
^
Write-Host ''; ^
Write-Host '【6/9】正在切换电源计划为高性能...' -ForegroundColor Cyan; ^
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c; ^
Write-Host '  电源计划已切换为高性能' -ForegroundColor Green; ^
^
Write-Host ''; ^
Write-Host '【7/9】正在禁用遥测和诊断计划任务...' -ForegroundColor Cyan; ^
$tasks = @( ^
    @{Path='\Microsoft\Windows\Application Experience\'; Name='Microsoft Compatibility Appraiser'}, ^
    @{Path='\Microsoft\Windows\Application Experience\'; Name='ProgramDataUpdater'}, ^
    @{Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='Consolidator'}, ^
    @{Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='UsbCeip'}, ^
    @{Path='\Microsoft\Windows\Windows Error Reporting\'; Name='QueueReporting'}, ^
    @{Path='\Microsoft\Windows\UpdateOrchestrator\'; Name='Schedule Scan'} ^
); ^
foreach ($t in $tasks) { ^
    Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction SilentlyContinue | Out-Null; ^
    Write-Host \"  已禁用任务: $($t.Name)\" -ForegroundColor Gray; ^
}; ^
^
Write-Host ''; ^
Write-Host '【8/9】正在优化注册表和网络设置...' -ForegroundColor Cyan; ^
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force | Out-Null; ^
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0 -ErrorAction SilentlyContinue; ^
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null; ^
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -ErrorAction SilentlyContinue; ^
netsh int tcp set global autotuninglevel=disabled | Out-Null; ^
netsh int tcp set global chimney=disabled | Out-Null; ^
Write-Host '  注册表和网络已优化' -ForegroundColor Green; ^
^
Write-Host ''; ^
Write-Host '【9/9】正在清理临时文件...' -ForegroundColor Cyan; ^
Remove-Item -Path \"\$env:TEMP\*\" -Recurse -Force -ErrorAction SilentlyContinue; ^
Remove-Item -Path 'C:\Windows\Temp\*' -Recurse -Force -ErrorAction SilentlyContinue; ^
Remove-Item -Path 'C:\Windows\Prefetch\*' -Recurse -Force -ErrorAction SilentlyContinue; ^
Write-Host '  临时文件清理完成' -ForegroundColor Green; ^
^
Write-Host ''; ^
Write-Host '============================================================' -ForegroundColor Yellow; ^
Write-Host '  全部优化完成！' -ForegroundColor Yellow; ^
Write-Host '  语言/时区更改需要重启后完全生效' -ForegroundColor Yellow; ^
Write-Host '============================================================' -ForegroundColor Yellow; ^
}"

echo.
echo 优化完成！按任意键重启系统（语言设置需重启后生效）...
echo 如不想立即重启，请直接关闭此窗口。
pause >nul
shutdown /r /t 10 /c "系统优化完成，10秒后重启..."
