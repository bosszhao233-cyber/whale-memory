# 大肥鲸·记忆同步（常驻循环版）
# 每 180 秒跑一次同步，不弹窗；由开机启动项拉起，一直待着。
$ErrorActionPreference = 'SilentlyContinue'
$script = 'E:\dsh\tools\whale-sync-git.ps1'
while ($true) {
  try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $script
  } catch { }
  Start-Sleep -Seconds 180
}
