# 大肥鲸·记忆同步（常驻循环版）
# 每 180 秒跑一次同步，不弹窗；由开机启动项拉起，一直待着。
# 路径按本机来：优先 DSH_HOME，再退回 ~/.dsh，不再写死盘符。
$ErrorActionPreference = 'SilentlyContinue'
$dsh = $env:DSH_HOME
if (-not $dsh -or -not (Test-Path $dsh)) { $dsh = Join-Path $env:USERPROFILE '.dsh' }
$script = Join-Path $dsh 'tools\whale-sync-git.ps1'
while ($true) {
  try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $script
  } catch { }
  Start-Sleep -Seconds 180
}
