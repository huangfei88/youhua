@echo off
chcp 65001 >nul
title Windows Server 2022 一键极限精简优化 (Azure专用)

:: ============================================================
:: 自动请求管理员权限
:: ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command "exit [int](-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))"
if %errorlevel% neq 0 (
    echo 正在请求管理员权限，请在弹出窗口中点击"是"...
    :: 使用 /k 而不是 /c，确保提权后的新窗口在脚本执行完毕后保持打开
    powershell -Command "Start-Process -FilePath cmd.exe -ArgumentList '/k \"%~f0\"' -Verb RunAs"
    echo 已在新窗口请求管理员权限，请在弹出的管理员命令行窗口中查看进度。
    :: 使用 timeout 而不是 pause，防止 UAC 确认时的回车键意外关闭本窗口
    timeout /t 3 /nobreak >nul
    exit /b
)

echo.
echo ============================================================
echo   Windows Server 2022 一键极限精简优化脚本
echo   Azure 2核1G 低配虚拟机专用  ^| 含Defender关闭
echo ============================================================
echo.

:: 从本文件提取并执行内嵌的 PowerShell 脚本
set "BAT_PATH=%~f0"
set "PS1_TMP=%TEMP%\azure_optimize_%RANDOM%.ps1"
if exist "C:\optimize_log.txt" del /f /q "C:\optimize_log.txt"

:: 写入 bat 级启动日志，确认脚本已以管理员权限运行
echo [BAT] 脚本启动，准备提取并执行内嵌 PowerShell... >> "C:\optimize_log.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "('[BAT] 启动时间: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) | Add-Content -Path 'C:\optimize_log.txt' -Encoding UTF8"

echo [BAT] 正在提取内嵌 PowerShell 脚本到临时文件...
echo [BAT] 临时文件路径: %PS1_TMP%

powershell -NoProfile -ExecutionPolicy Bypass -Command "$batPath='%BAT_PATH:\=\\%'; $ps1Tmp='%PS1_TMP:\=\\%'; try { $content=Get-Content -Raw -Path $batPath -Encoding UTF8; $startMarker='::==PSSTART=='; $endMarker='::==PSEND=='; $si=$content.IndexOf($startMarker); $ei=$content.IndexOf($endMarker); if($si -lt 0 -or $ei -lt 0){throw '标记未找到，请检查文件完整性'}; $ps=$content.Substring($si+$startMarker.Length,$ei-$si-$startMarker.Length).Trim(); Set-Content -Path $ps1Tmp -Value $ps -Encoding UTF8; Write-Host ('[BAT] 脚本提取成功，行数: '+$ps.Split([char]10).Count) } catch { Write-Host ('[BAT] 提取异常: '+$_.Exception.Message); exit 1 }"

if %errorlevel% neq 0 (
    echo.
    echo [错误] PowerShell脚本提取失败！
    echo 请确保文件以 UTF-8 编码保存并完整下载。
    echo [BAT-ERROR] PowerShell脚本提取失败 >> "C:\optimize_log.txt"
    pause
    exit /b 1
)

if not exist "%PS1_TMP%" (
    echo.
    echo [错误] 临时脚本文件未生成：%PS1_TMP%
    echo 请检查 %%TEMP%% 目录写入权限。
    echo [BAT-ERROR] 临时脚本文件未生成 >> "C:\optimize_log.txt"
    pause
    exit /b 1
)

echo [BAT] 临时脚本已生成，开始执行主优化流程...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1_TMP%"
set "PS_EXIT=%errorlevel%"
del /f /q "%PS1_TMP%" >nul 2>&1

if %PS_EXIT% neq 0 (
    echo.
    echo [警告] PowerShell 脚本执行结束，退出码: %PS_EXIT%
    echo 请查看日志文件 C:\optimize_log.txt 了解详情。
    echo [BAT-WARN] PowerShell 退出码: %PS_EXIT% >> "C:\optimize_log.txt"
)

echo.
echo 优化完成！日志已保存至 C:\optimize_log.txt
echo.
echo 按任意键重启系统（语言/Defender设置需重启后生效）
echo 如不想立即重启，请直接关闭此窗口。
pause
shutdown /r /t 10 /c "Azure VM优化完成，10秒后重启..."
goto :eof

::==PSSTART==
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'
$LogFile      = 'C:\optimize_log.txt'
$successCount = 0
$skipCount    = 0
$failCount    = 0
$completedSteps = 0
$totalSteps     = 10

# ── 日志辅助函数 ──────────────────────────────────────────
function Write-Log {
    param([string]$Msg, [string]$Color = 'White')
    Write-Host $Msg -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $Msg -Encoding UTF8
}

# 写入日志头部（追加模式，保留BAT层已写入的启动记录）
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Add-Content -Path $LogFile -Value "Windows Server 2022 优化脚本日志 - 执行时间: $ts" -Encoding UTF8
Add-Content -Path $LogFile -Value "============================================================" -Encoding UTF8

# ── 1. 语言 / 时区 ─────────────────────────────────────────
Write-Log ''
Write-Log '【1/10】切换系统语言为简体中文 + 时区 UTC+8...' 'Cyan'
try {
    Set-WinSystemLocale zh-CN -ErrorAction Stop
    Set-WinUILanguageOverride -Language zh-CN -ErrorAction Stop
    Set-Culture zh-CN -ErrorAction Stop
    Set-WinUserLanguageList zh-CN -Force -ErrorAction Stop
    Set-TimeZone -Id 'China Standard Time' -ErrorAction Stop
    $successCount++
    Write-Log '  [成功] 语言/时区设置完成' 'Green'
} catch {
    $failCount++
    Write-Log '  [失败] 语言/时区设置' 'Red'
}
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 2. 关闭 Windows Defender ────────────────────────────────
Write-Log ''
Write-Log '【2/10】关闭 Windows Defender...' 'Cyan'
# 通过组策略注册表彻底禁用
try {
    $defPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
    New-Item -Path $defPath -Force | Out-Null
    Set-ItemProperty -Path $defPath -Name 'DisableAntiSpyware'           -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $defPath -Name 'DisableAntiVirus'             -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $defPath -Name 'DisableRealtimeMonitoring'    -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $defPath -Name 'DisableRoutinelyTakingAction' -Value 1 -Type DWord -ErrorAction Stop
    New-Item -Path "$defPath\Real-Time Protection" -Force | Out-Null
    Set-ItemProperty -Path "$defPath\Real-Time Protection" -Name 'DisableRealtimeMonitoring'   -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path "$defPath\Real-Time Protection" -Name 'DisableBehaviorMonitoring'   -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path "$defPath\Real-Time Protection" -Name 'DisableOnAccessProtection'   -Value 1 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path "$defPath\Real-Time Protection" -Name 'DisableScanOnRealtimeEnable' -Value 1 -Type DWord -ErrorAction Stop
    New-Item -Path "$defPath\Spynet" -Force | Out-Null
    Set-ItemProperty -Path "$defPath\Spynet" -Name 'SpynetReporting'      -Value 0 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path "$defPath\Spynet" -Name 'SubmitSamplesConsent' -Value 2 -Type DWord -ErrorAction Stop
    $successCount++
    Write-Log '  [成功] Defender注册表策略设置完成' 'Gray'
} catch {
    $failCount++
    Write-Log '  [失败] Defender注册表策略设置' 'Red'
}
# 关闭Defender相关服务
$defSvcs = @('WinDefend','WdNisSvc','Sense','SecurityHealthService','wscsvc','WdNisDrv')
foreach ($defSvc in $defSvcs) {
    $s = Get-Service -Name $defSvc -ErrorAction SilentlyContinue
    if ($null -eq $s) {
        $skipCount++
        Write-Log "  [跳过] Defender服务 $defSvc - 不存在" 'DarkGray'
    } else {
        try {
            Stop-Service -Name $defSvc -Force
            Set-Service  -Name $defSvc -StartupType Disabled -ErrorAction Stop
            $successCount++
            Write-Log "  [成功] 已禁用Defender服务: $defSvc" 'Gray'
        } catch {
            $failCount++
            Write-Log "  [失败] Defender服务: $defSvc" 'Red'
        }
    }
}
# 关闭Defender计划任务
$defTasks = @('Windows Defender Cache Maintenance','Windows Defender Cleanup','Windows Defender Scheduled Scan','Windows Defender Verification')
foreach ($tn in $defTasks) {
    $dt = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName $tn -ErrorAction SilentlyContinue
    if ($null -eq $dt) {
        $skipCount++
        Write-Log "  [跳过] Defender任务: $tn - 不存在" 'DarkGray'
    } else {
        try {
            Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -TaskName $tn -ErrorAction Stop | Out-Null
            $successCount++
            Write-Log "  [成功] 已禁用Defender任务: $tn" 'Gray'
        } catch {
            $failCount++
            Write-Log "  [失败] Defender任务: $tn" 'Red'
        }
    }
}
Write-Log '  Defender已关闭（重启后完全生效）' 'Green'
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 3. 极限精简服务（仅保留Azure必要项） ───────────────────
Write-Log ''
Write-Log '【3/10】禁用非必要服务（保留Azure/RDP/网络核心）...' 'Cyan'
$services = @(
    'Themes','TabletInputService','UxSms',
    'Spooler','Fax',
    'WSearch','SysMain',
    'DiagTrack','dmwappushservice','WerSvc','PcaSvc','DPS','WdiServiceHost','WdiSystemHost',
    'wuauserv','UsoSvc','DoSvc','WaaSMedicSvc',
    'XboxGipSvc','XblAuthManager','XblGameSave','XboxNetApiSvc',
    'lfsvc','SensorDataService','SensrSvc','SensorService',
    'bthserv','BthHFSrv','PhoneSvc','RmSvc','icssvc',
    'WMPNetworkSvc','RetailDemo',
    'MapsBroker',
    'SharedAccess',
    'SCardSvr','SCPolicySvc','CertPropSvc',
    'BDESVC','EFS',
    'TrkWks','SDRSVC','swprv','wbengine',
    'wisvc',
    'WlanSvc','WwanSvc','dot3svc',
    'CDPSvc','CDPUserSvc',
    'cbdhsvc','InstallService',
    'defragsvc',
    'hidserv','stisvc',
    'RemoteRegistry',
    'NcbService',
    'p2pimsvc','p2psvc','PNRPsvc','PNRPAutoReg',
    'IKEEXT',
    'ShellHWDetection',
    'AeLookupSvc',
    'seclogon',
    'HomeGroupListener','HomeGroupProvider'
)
foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($null -eq $s) {
        $skipCount++
        Write-Log "  [跳过] $svc - 服务不存在，无需优化" 'DarkGray'
    } else {
        try {
            Stop-Service -Name $svc -Force
            Set-Service  -Name $svc -StartupType Disabled -ErrorAction Stop
            $successCount++
            Write-Log "  [成功] 已禁用: $svc" 'Gray'
        } catch {
            $failCount++
            Write-Log "  [失败] $svc" 'Red'
        }
    }
}
Write-Log '  服务精简完成' 'Green'
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 4. 关闭 Windows 功能 ────────────────────────────────────
Write-Log ''
Write-Log '【4/10】关闭不必要的 Windows 功能...' 'Cyan'
$features = @(
    'Internet-Explorer-Optional-amd64',
    'MediaPlayback','WindowsMediaPlayer',
    'Printing-PrintToPDFServices-Features',
    'Printing-XPSServices-Features',
    'WorkFolders-Client','FaxServicesClientPackage',
    'SMB1Protocol','MicrosoftWindowsPowerShellV2Root'
)
foreach ($feat in $features) {
    $featureObj = Get-WindowsOptionalFeature -Online -FeatureName $feat -ErrorAction SilentlyContinue
    if ($null -eq $featureObj) {
        $skipCount++
        Write-Log "  [跳过] $feat - 功能不存在" 'DarkGray'
    } elseif ($featureObj.State -eq 'Disabled') {
        $skipCount++
        Write-Log "  [跳过] $feat - 已是禁用状态" 'DarkGray'
    } else {
        try {
            Disable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart -ErrorAction Stop | Out-Null
            $successCount++
            Write-Log "  [成功] 已关闭: $feat" 'Gray'
        } catch {
            $failCount++
            Write-Log "  [失败] $feat" 'Red'
        }
    }
}
Write-Log '  功能关闭完成' 'Green'
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 5. 视觉效果最佳性能 ─────────────────────────────────────
Write-Log ''
Write-Log '【5/10】视觉效果调整为最佳性能...' 'Cyan'
try {
    $regVis = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    if (-not (Test-Path $regVis)) { New-Item -Path $regVis -Force | Out-Null }
    Set-ItemProperty -Path $regVis -Name 'VisualFXSetting' -Value 2 -ErrorAction Stop
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0' -ErrorAction Stop
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'DragFullWindows' -Value '0' -ErrorAction Stop
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 0 -ErrorAction Stop
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -ErrorAction Stop
    $successCount++
    Write-Log '  [成功] 视觉效果设置完成' 'Green'
} catch {
    $failCount++
    Write-Log '  [失败] 视觉效果设置' 'Red'
}
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 6. 页面文件固定 2048MB ──────────────────────────────────
Write-Log ''
Write-Log '【6/10】设置虚拟内存页面文件 2048MB...' 'Cyan'
try {
    $cs = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges -ErrorAction Stop
    $cs.AutomaticManagedPagefile = $false
    $cs.Put() | Out-Null
    Get-WmiObject -Class Win32_PageFileSetting | ForEach-Object { $_.Delete() }
    Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name='C:\pagefile.sys';InitialSize=2048;MaximumSize=2048} | Out-Null
    $successCount++
    Write-Log '  [成功] 页面文件已固定为 2048MB' 'Green'
} catch {
    $failCount++
    Write-Log '  [失败] 页面文件设置' 'Red'
}
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 7. 高性能电源计划 ────────────────────────────────────────
Write-Log ''
Write-Log '【7/10】切换电源计划为高性能...' 'Cyan'
try {
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
    $successCount++
    Write-Log '  [成功] 电源计划已切换为高性能' 'Green'
} catch {
    $failCount++
    Write-Log '  [失败] 电源计划设置' 'Red'
}
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 8. 禁用计划任务 ─────────────────────────────────────────
Write-Log ''
Write-Log '【8/10】禁用遥测/诊断/更新计划任务...' 'Cyan'
$tasks = @(
    @{P='\Microsoft\Windows\Application Experience\';    N='Microsoft Compatibility Appraiser'},
    @{P='\Microsoft\Windows\Application Experience\';    N='ProgramDataUpdater'},
    @{P='\Microsoft\Windows\Application Experience\';    N='StartupAppTask'},
    @{P='\Microsoft\Windows\Customer Experience Improvement Program\'; N='Consolidator'},
    @{P='\Microsoft\Windows\Customer Experience Improvement Program\'; N='UsbCeip'},
    @{P='\Microsoft\Windows\Windows Error Reporting\';   N='QueueReporting'},
    @{P='\Microsoft\Windows\UpdateOrchestrator\';        N='Schedule Scan'},
    @{P='\Microsoft\Windows\UpdateOrchestrator\';        N='USO_UxBroker'},
    @{P='\Microsoft\Windows\UpdateOrchestrator\';        N='Report policies'},
    @{P='\Microsoft\Windows\Diagnosis\';                 N='Scheduled'},
    @{P='\Microsoft\Windows\DiskDiagnostic\';            N='Microsoft-Windows-DiskDiagnosticDataCollector'},
    @{P='\Microsoft\Windows\Maintenance\';               N='WinSAT'},
    @{P='\Microsoft\Windows\Maps\';                      N='MapsUpdateTask'},
    @{P='\Microsoft\Windows\Maps\';                      N='MapsToastTask'},
    @{P='\Microsoft\Windows\Power Efficiency Diagnostics\'; N='AnalyzeSystem'},
    @{P='\Microsoft\Windows\Shell\';                     N='FamilySafetyMonitor'},
    @{P='\Microsoft\Windows\Shell\';                     N='FamilySafetyRefreshTask'}
)
foreach ($t in $tasks) {
    $task = Get-ScheduledTask -TaskPath $t.P -TaskName $t.N -ErrorAction SilentlyContinue
    if ($null -eq $task) {
        $skipCount++
        Write-Log "  [跳过] $($t.N) - 任务不存在" 'DarkGray'
    } elseif ($task.State -eq 'Disabled') {
        $skipCount++
        Write-Log "  [跳过] $($t.N) - 已是禁用状态" 'DarkGray'
    } else {
        try {
            Disable-ScheduledTask -TaskPath $t.P -TaskName $t.N -ErrorAction Stop | Out-Null
            $successCount++
            Write-Log "  [成功] 已禁用任务: $($t.N)" 'Gray'
        } catch {
            $failCount++
            Write-Log "  [失败] $($t.N)" 'Red'
        }
    }
}
Write-Log '  计划任务禁用完成' 'Green'
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 9. 注册表 + 网络优化 ────────────────────────────────────
Write-Log ''
Write-Log '【9/10】注册表 + 网络优化...' 'Cyan'
try {
    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force | Out-Null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0 -ErrorAction Stop
    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -ErrorAction Stop
    New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Force | Out-Null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1 -ErrorAction Stop
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'WaitToKillServiceTimeout' -Value '2000' -ErrorAction Stop
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -Value 0xFF -Type DWord -ErrorAction Stop
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh int tcp set global chimney=disabled | Out-Null
    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global timestamps=disabled | Out-Null
    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Force | Out-Null
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -Value 0 -ErrorAction Stop
    $successCount++
    Write-Log '  [成功] 注册表/网络优化完成' 'Green'
} catch {
    $failCount++
    Write-Log '  [失败] 注册表/网络优化部分设置失败' 'Red'
}
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 10. 清理临时文件 ────────────────────────────────────────
Write-Log ''
Write-Log '【10/10】清理临时文件和系统垃圾...' 'Cyan'
$cleanPaths = @(
    "$env:TEMP\*",
    'C:\Windows\Temp\*',
    'C:\Windows\Prefetch\*',
    'C:\Windows\SoftwareDistribution\Download\*',
    'C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*',
    'C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*'
)
foreach ($p in $cleanPaths) {
    try {
        Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
        $successCount++
        Write-Log "  [成功] 已清理: $p" 'Gray'
    } catch {
        $skipCount++
        Write-Log "  [跳过] $p - 路径不存在或无内容" 'DarkGray'
    }
}
Write-Log '  清理完成' 'Green'
$completedSteps++
Write-Log "  步骤完成度: $completedSteps / $totalSteps" 'Green'

# ── 汇总报告 ────────────────────────────────────────────────
$totalItems = $successCount + $skipCount + $failCount
if ($totalItems -gt 0) {
    $itemRate = [math]::Round(($successCount + $skipCount) / $totalItems * 100, 1)
} else { $itemRate = 0 }
$stepRate = [math]::Round($completedSteps / $totalSteps * 100, 1)
Write-Log ''
Write-Log '============================================================' 'Yellow'
Write-Log '  优化结果汇总' 'Yellow'
Write-Log '------------------------------------------------------------' 'Yellow'
Write-Log "  [成功] 优化完成: $successCount 项" 'Green'
Write-Log "  [跳过] 无需优化: $skipCount 项" 'DarkGray'
Write-Log "  [失败] 优化失败: $failCount 项" 'Red'
Write-Log '------------------------------------------------------------' 'Yellow'
Write-Log "  脚本步骤完成度: $completedSteps / $totalSteps ($stepRate%)" 'Cyan'
Write-Log "  优化项完成率:   $($successCount + $skipCount) / $totalItems ($itemRate%)" 'Cyan'
Write-Log '------------------------------------------------------------' 'Yellow'
Write-Log '  保留服务: RDP(TermService) / WMI / DHCP / DNS' 'Yellow'
Write-Log '  保留服务: Azure Agent / RPC / EventLog / Netlogon' 'Yellow'
Write-Log '  Windows Defender 将在重启后完全关闭。' 'Yellow'
Write-Log '============================================================' 'Yellow'
Write-Log "  日志已保存至: C:\optimize_log.txt" 'Cyan'
::==PSEND==
