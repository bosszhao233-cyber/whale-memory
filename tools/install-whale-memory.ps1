# 大肥鱼·记忆同步 一键安装（第二台电脑用）
# 做完这些：
#   1) 检查 git
#   2) 把仓库 clone 到 DSH_HOME\whale-memory（有了就拉一下）
#   3) 把同步脚本拷到 DSH_HOME\tools
#   4) 建一个开机自启的常驻同步进程（每 3 分钟一次，不弹窗）
#   5) 立刻跑一次合并同步

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$dsh = $env:DSH_HOME
if (-not $dsh -or -not (Test-Path $dsh)) {
  if (Test-Path 'E:\dsh\profiles') { $dsh = 'E:\dsh' }
  else { $dsh = Join-Path $env:USERPROFILE '.dsh' }
}
Write-Host "DSH_HOME = $dsh"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "这台没装 git，先装一个再来：https://git-scm.com/download/win" -ForegroundColor Red
  exit 1
}

# 有系统代理就顺手给 git 配上（GitHub 在国内常连不上）
$ie = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
if ($ie.ProxyEnable -eq 1 -and $ie.ProxyServer) {
  $proxy = 'http://' + ($ie.ProxyServer -replace '^https?://', '')
  git config --global http.proxy $proxy
  git config --global https.proxy $proxy
  Write-Host "已给 git 配代理：$proxy"
}

$repoUrl = 'https://github.com/bosszhao233-cyber/whale-memory.git'
$repo    = Join-Path $dsh 'whale-memory'
$tools   = Join-Path $dsh 'tools'
if (-not (Test-Path $tools)) { New-Item -ItemType Directory -Path $tools -Force | Out-Null }

if (-not (Test-Path $repo)) {
  Write-Host "正在下载记忆仓库……如果弹出 GitHub 登录窗口，登录并允许即可。"
  git clone $repoUrl $repo
  if ($LASTEXITCODE -ne 0) {
    Write-Host "clone 失败。多半是网络或没登录。" -ForegroundColor Red
    exit 1
  }
}

Set-Location $repo
git config user.name  "whale"
git config user.email "bosszhao233-cyber@users.noreply.github.com"
git config core.autocrlf false
git pull --no-rebase --no-edit 2>&1 | Out-Null
Set-Location $here

foreach ($name in @('whale-sync-git.ps1', 'whale-sync-loop.ps1')) {
  $src = Join-Path $repo ("tools\" + $name)
  if (-not (Test-Path $src)) { $src = Join-Path $here $name }
  if (Test-Path $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $tools $name) -Force }
}

$sync = Join-Path $tools 'whale-sync-git.ps1'
$loop = Join-Path $tools 'whale-sync-loop.ps1'
if (-not (Test-Path $sync) -or -not (Test-Path $loop)) {
  Write-Host "同步脚本没找到，安装包不完整。" -ForegroundColor Red
  exit 1
}

# 开机自启：启动文件夹里放一个隐藏窗口的快捷方式
$startup = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$lnk = Join-Path $startup '大肥鱼记忆同步.lnk'
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($lnk)
$s.TargetPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$s.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $loop + '"'
$s.WorkingDirectory = $tools
$s.WindowStyle = 7
$s.Description = '大肥鱼双机记忆同步'
$s.Save()
Write-Host ("开机自启已装：" + $lnk)

Start-Process 'powershell.exe' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$loop -WindowStyle Hidden
Write-Host "常驻同步已启动（每 3 分钟一次）"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $sync
Write-Host "已跑过一次合并同步"

Write-Host ""
Write-Host "完成。两边的记忆已经合到一起了。"
