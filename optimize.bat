@echo off
chcp 65001 >nul
title Windows Server 2022 一键极限精简优化 (Azure专用)

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
echo   Windows Server 2022 一键极限精简优化脚本
echo   Azure 2核1G 低配虚拟机专用  ^| 含Defender关闭
echo ============================================================
echo.

:: 将内嵌PowerShell脚本写入临时文件再执行，避免转义问题
set "PS1=%TEMP%\azure_optimize.ps1"

(
echo $ErrorActionPreference = 'SilentlyContinue'
echo $ProgressPreference    = 'SilentlyContinue'
echo.
echo # ── 1. 语言 / 时区 ─────────────────────────────────────────
echo Write-Host ''
echo Write-Host '【1/10】切换系统语言为简体中文 + 时区 UTC+8...' -ForegroundColor Cyan
echo Set-WinSystemLocale zh-CN
echo Set-WinUILanguageOverride -Language zh-CN
echo Set-Culture zh-CN
echo Set-WinUserLanguageList zh-CN -Force
echo Set-TimeZone -Id 'China Standard Time'
echo Write-Host '  完成' -ForegroundColor Green
echo.
echo # ── 2. 关闭 Windows Defender ────────────────────────────────
echo Write-Host '【2/10】关闭 Windows Defender...' -ForegroundColor Cyan
echo # 通过组策略注册表彻底禁用（优先级高于Tamper Protection）
echo $defPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
echo New-Item -Path $defPath -Force ^| Out-Null
echo Set-ItemProperty -Path $defPath -Name 'DisableAntiSpyware'      -Value 1 -Type DWord
echo Set-ItemProperty -Path $defPath -Name 'DisableAntiVirus'         -Value 1 -Type DWord
echo Set-ItemProperty -Path $defPath -Name 'DisableRealtimeMonitoring' -Value 1 -Type DWord
echo Set-ItemProperty -Path $defPath -Name 'DisableRoutinelyTakingAction' -Value 1 -Type DWord
echo New-Item -Path "$defPath\Real-Time Protection" -Force ^| Out-Null
echo Set-ItemProperty -Path "$defPath\Real-Time Protection" -Name 'DisableRealtimeMonitoring'  -Value 1 -Type DWord
echo Set-ItemProperty -Path "$defPath\Real-Time Protection" -Name 'DisableBehaviorMonitoring'  -Value 1 -Type DWord
echo Set-ItemProperty -Path "$defPath\Real-Time Protection" -Name 'DisableOnAccessProtection'  -Value 1 -Type DWord
echo Set-ItemProperty -Path "$defPath\Real-Time Protection" -Name 'DisableScanOnRealtimeEnable' -Value 1 -Type DWord
echo New-Item -Path "$defPath\Spynet" -Force ^| Out-Null
echo Set-ItemProperty -Path "$defPath\Spynet" -Name 'SpynetReporting'       -Value 0 -Type DWord
echo Set-ItemProperty -Path "$defPath\Spynet" -Name 'SubmitSamplesConsent'  -Value 2 -Type DWord
echo # 关闭Defender相关服务
echo $defSvcs = @('WinDefend','WdNisSvc','Sense','SecurityHealthService','wscsvc','WdNisDrv','MsMpSvc')
echo foreach ($s in $defSvcs) {
echo     Stop-Service -Name $s -Force
echo     Set-Service  -Name $s -StartupType Disabled
echo     Write-Host "  已禁用Defender服务: $s" -ForegroundColor Gray
echo }
echo # 关闭Defender计划任务
echo Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName 'Windows Defender Cache Maintenance' ^| Out-Null
echo Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName 'Windows Defender Cleanup'           ^| Out-Null
echo Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName 'Windows Defender Scheduled Scan'   ^| Out-Null
echo Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName 'Windows Defender Verification'     ^| Out-Null
echo Write-Host '  Defender已关闭（重启后完全生效）' -ForegroundColor Green
echo.
echo # ── 3. 极限精简服务（仅保留Azure必要项） ───────────────────
echo Write-Host '【3/10】禁用非必要服务（保留Azure/RDP/网络核心）...' -ForegroundColor Cyan
echo # 以下服务在Azure VM上可安全禁用
echo $services = @(
echo     # UI / 主题
echo     'Themes','TabletInputService','UxSms',
echo     # 打印 / 传真
echo     'Spooler','Fax',
echo     # 搜索 / 内存压缩
echo     'WSearch','SysMain',
echo     # 遥测 / 诊断
echo     'DiagTrack','dmwappushservice','WerSvc','PcaSvc','DPS','WdiServiceHost','WdiSystemHost',
echo     # Windows Update（手动维护）
echo     'wuauserv','UsoSvc','DoSvc','WaaSMedicSvc',
echo     # Xbox
echo     'XboxGipSvc','XblAuthManager','XblGameSave','XboxNetApiSvc',
echo     # 地理位置 / 传感器
echo     'lfsvc','SensorDataService','SensrSvc','SensorService',
echo     # 蓝牙 / 红外 / 手机
echo     'bthserv','BthHFSrv','PhoneSvc','RmSvc','icssvc',
echo     # 媒体 / 零售
echo     'WMPNetworkSvc','RetailDemo',
echo     # 地图 / Cortana
echo     'MapsBroker',
echo     # 网络共享 / ICS
echo     'SharedAccess',
echo     # 智能卡
echo     'SCardSvr','SCPolicySvc','CertPropSvc',
echo     # BitLocker / EFS（Azure托管盘不需要）
echo     'BDESVC','EFS',
echo     # 链接追踪 / 备份
echo     'TrkWks','SDRSVC','swprv','wbengine',
echo     # 内部人计划
echo     'wisvc',
echo     # 无线（VM无WiFi）
echo     'WlanSvc','WwanSvc','dot3svc',
echo     # 连接设备平台
echo     'CDPSvc','CDPUserSvc',
echo     # 剪贴板同步 / 安装
echo     'cbdhsvc','InstallService',
echo     # 碎片整理
echo     'defragsvc',
echo     # 辅助功能
echo     'hidserv','stisvc',
echo     # 远程注册表（安全考虑关闭）
echo     'RemoteRegistry',
echo     # 网络连接代理
echo     'NcbService',
echo     # 对等网络
echo     'p2pimsvc','p2psvc','PNRPsvc','PNRPAutoReg',
echo     # IKE/VPN（不用VPN则关闭）
echo     'IKEEXT',
echo     # Shell硬件检测
echo     'ShellHWDetection',
echo     # 预取 / 应用体验
echo     'AeLookupSvc',
echo     # 辅助登录
echo     'seclogon',
echo     # 家庭组
echo     'HomeGroupListener','HomeGroupProvider'
echo )
echo foreach ($svc in $services) {
echo     $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
echo     if ($s) {
echo         Stop-Service -Name $svc -Force
echo         Set-Service  -Name $svc -StartupType Disabled
echo         Write-Host "  已禁用: $svc" -ForegroundColor Gray
echo     }
echo }
echo Write-Host '  服务精简完成' -ForegroundColor Green
echo.
echo # ── 4. 关闭 Windows 功能 ────────────────────────────────────
echo Write-Host '【4/10】关闭不必要的 Windows 功能...' -ForegroundColor Cyan
echo $features = @(
echo     'Internet-Explorer-Optional-amd64',
echo     'MediaPlayback','WindowsMediaPlayer',
echo     'Printing-PrintToPDFServices-Features',
echo     'Printing-XPSServices-Features',
echo     'WorkFolders-Client','FaxServicesClientPackage',
echo     'SMB1Protocol','MicrosoftWindowsPowerShellV2Root'
echo )
echo foreach ($f in $features) {
echo     Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart ^| Out-Null
echo     Write-Host "  已关闭: $f" -ForegroundColor Gray
echo }
echo Write-Host '  功能关闭完成' -ForegroundColor Green
echo.
echo # ── 5. 视觉效果最佳性能 ─────────────────────────────────────
echo Write-Host '【5/10】视觉效果调整为最佳性能...' -ForegroundColor Cyan
echo $regVis = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
echo if (-not (Test-Path $regVis)) { New-Item -Path $regVis -Force ^| Out-Null }
echo Set-ItemProperty -Path $regVis -Name 'VisualFXSetting' -Value 2
echo Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0'
echo Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'DragFullWindows' -Value '0'
echo Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 0
echo # 关闭透明效果
echo Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0
echo Write-Host '  完成' -ForegroundColor Green
echo.
echo # ── 6. 页面文件固定 2048MB ──────────────────────────────────
echo Write-Host '【6/10】设置虚拟内存页面文件 2048MB...' -ForegroundColor Cyan
echo $cs = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
echo $cs.AutomaticManagedPagefile = $false
echo $cs.Put() ^| Out-Null
echo Get-WmiObject -Class Win32_PageFileSetting ^| ForEach-Object { $_.Delete() }
echo Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name='C:\pagefile.sys';InitialSize=2048;MaximumSize=2048} ^| Out-Null
echo Write-Host '  页面文件已固定为 2048MB' -ForegroundColor Green
echo.
echo # ── 7. 高性能电源计划 ────────────────────────────────────────
echo Write-Host '【7/10】切换电源计划为高性能...' -ForegroundColor Cyan
echo powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
echo powercfg /change standby-timeout-ac 0
echo powercfg /change hibernate-timeout-ac 0
echo Write-Host '  完成' -ForegroundColor Green
echo.
echo # ── 8. 禁用计划任务 ─────────────────────────────────────────
echo Write-Host '【8/10】禁用遥测/诊断/更新计划任务...' -ForegroundColor Cyan
echo $tasks = @(
echo     @{P='\Microsoft\Windows\Application Experience\';    N='Microsoft Compatibility Appraiser'},
echo     @{P='\Microsoft\Windows\Application Experience\';    N='ProgramDataUpdater'},
echo     @{P='\Microsoft\Windows\Application Experience\';    N='StartupAppTask'},
echo     @{P='\Microsoft\Windows\Customer Experience Improvement Program\'; N='Consolidator'},
echo     @{P='\Microsoft\Windows\Customer Experience Improvement Program\'; N='UsbCeip'},
echo     @{P='\Microsoft\Windows\Windows Error Reporting\';   N='QueueReporting'},
echo     @{P='\Microsoft\Windows\UpdateOrchestrator\';        N='Schedule Scan'},
echo     @{P='\Microsoft\Windows\UpdateOrchestrator\';        N='USO_UxBroker'},
echo     @{P='\Microsoft\Windows\UpdateOrchestrator\';        N='Report policies'},
echo     @{P='\Microsoft\Windows\Diagnosis\';                 N='Scheduled'},
echo     @{P='\Microsoft\Windows\DiskDiagnostic\';            N='Microsoft-Windows-DiskDiagnosticDataCollector'},
echo     @{P='\Microsoft\Windows\Maintenance\';               N='WinSAT'},
echo     @{P='\Microsoft\Windows\Maps\';                      N='MapsUpdateTask'},
echo     @{P='\Microsoft\Windows\Maps\';                      N='MapsToastTask'},
echo     @{P='\Microsoft\Windows\Power Efficiency Diagnostics\'; N='AnalyzeSystem'},
echo     @{P='\Microsoft\Windows\Shell\';                     N='FamilySafetyMonitor'},
echo     @{P='\Microsoft\Windows\Shell\';                     N='FamilySafetyRefreshTask'}
echo )
echo foreach ($t in $tasks) {
echo     Disable-ScheduledTask -TaskPath $t.P -TaskName $t.N ^| Out-Null
echo     Write-Host "  已禁用任务: $($t.N)" -ForegroundColor Gray
echo }
echo Write-Host '  计划任务禁用完成' -ForegroundColor Green
echo.
echo # ── 9. 注册表 + 网络优化 ────────────────────────────────────
echo Write-Host '【9/10】注册表 + 网络优化...' -ForegroundColor Cyan
echo # 禁用Cortana
echo New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force ^| Out-Null
echo Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0
echo # 遥测归零
echo New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force ^| Out-Null
echo Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0
echo # 禁用错误报告弹窗
echo New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Force ^| Out-Null
echo Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1
echo # 加快关机速度
echo Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'WaitToKillServiceTimeout' -Value '2000'
echo # 禁用IPv6（Azure内部走IPv4）
echo Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -Value 0xFF -Type DWord
echo # TCP优化
echo netsh int tcp set global autotuninglevel=normal ^| Out-Null
echo netsh int tcp set global chimney=disabled ^| Out-Null
echo netsh int tcp set global rss=enabled ^| Out-Null
echo netsh int tcp set global timestamps=disabled ^| Out-Null
echo # 禁用LLMNR
echo New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Force ^| Out-Null
echo Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -Value 0
echo Write-Host '  完成' -ForegroundColor Green
echo.
echo # ── 10. 清理临时文件 ────────────────────────────────────────
echo Write-Host '【10/10】清理临时文件和系统垃圾...' -ForegroundColor Cyan
echo Remove-Item -Path "$env:TEMP\*"         -Recurse -Force
echo Remove-Item -Path 'C:\Windows\Temp\*'   -Recurse -Force
echo Remove-Item -Path 'C:\Windows\Prefetch\*' -Recurse -Force
echo Remove-Item -Path 'C:\Windows\SoftwareDistribution\Download\*' -Recurse -Force
echo # 清理WER报告
echo Remove-Item -Path 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*' -Recurse -Force
echo Remove-Item -Path 'C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*' -Recurse -Force
echo Write-Host '  清理完成' -ForegroundColor Green
echo.
echo Write-Host '============================================================' -ForegroundColor Yellow
echo Write-Host '  全部优化完成！请重启系统以完全生效。' -ForegroundColor Yellow
echo Write-Host '  保留的必要服务: RDP(TermService) / WMI / DHCP / DNS' -ForegroundColor Yellow
echo Write-Host '  保留的必要服务: Azure Agent / RPC / EventLog / Netlogon' -ForegroundColor Yellow
echo Write-Host '  Windows Defender 将在重启后完全关闭。' -ForegroundColor Yellow
echo Write-Host '============================================================' -ForegroundColor Yellow
) > "%PS1%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
del /f /q "%PS1%" >nul 2>&1

echo.
echo 优化完成！按任意键重启系统（语言/Defender设置需重启后生效）...
echo 如不想立即重启，请直接关闭此窗口。
pause >nul
shutdown /r /t 10 /c "Azure VM优化完成，10秒后重启..."
