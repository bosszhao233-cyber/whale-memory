# 大肥鲸·记忆合并同步 一键安装（第二台电脑用）
# 做完这些：
#   1) 检查 git
#   2) 把仓库 clone 到 DSH_HOME\whale-memory
#   3) 跑一次合并（会把它自己的日记并进来，再推上去）
#   4) 建一个每 5 分钟同步一次的计划任务

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$dsh = $env:DSH_HOME
if (-not $dsh -or -not (Test-Path $dsh)) {
  if (Test-Path 'E:\dsh\profiles') { $dsh = 'E:\dsh' }
  else { $dsh = Join-Path $env:USERPROFILE '.dsh' }
}

Write-Host "DSH_HOME = $dsh"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "这台没装 git，先去 https://git-scm.com/download/win 装一个，再回来双击。" -ForegroundColor Red
  exit 1
}

# 系统代理：GitHub 在国内经常连不上，有代理就顺手给 git 配上
$ie = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
if ($ie.ProxyEnable -eq 1 -and $ie.ProxyServer) {
  $proxy = 'http://' + ($ie.ProxyServer -replace '^https?://', '')
  git config --global http.proxy $proxy
  git config --global https.proxy $proxy
  Write-Host "已给 git 配代理：$proxy"
}

$repo      = Join-Path $dsh 'whale-memory'
$repoUrl   = 'https://github.com/bosszhao233-cyber/whale-memory.git'
$tools     = Join-Path $dsh 'tools'
$syncLocal = Join-Path $tools 'whale-sync-git.ps1'

if (-not (Test-Path $tools)) { New-Item -ItemType Directory -Path $tools -Force | Out-Null }

if (-not (Test-Path $repo)) {
  Write-Host "正在下载记忆仓库……如果弹出 GitHub 登录窗口，登录并允许即可。"
  git clone $repoUrl $repo
  if ($LASTEXITCODE -ne 0) {
    Write-Host "clone 失败。多半是网络或没登录。把报错发给我。" -ForegroundColor Red
    exit 1
  }
}

Set-Location $repo
git config user.name  "whale"
git config user.email "bosszhao233-cyber@users.noreply.github.com"
git config core.autocrlf false
Set-Location $here

$srcSync = Join-Path $here 'whale-sync-git.ps1'
if (-not (Test-Path $srcSync)) {
  $srcSync = Join-Path $repo 'tools\whale-sync-git.ps1'
}
if (Test-Path $srcSync) {
  Copy-Item -LiteralPath $srcSync -Destination $syncLocal -Force
  Write-Host "同步脚本已就位：$syncLocal"
} else {
  Write-Host "找不到 whale-sync-git.ps1，安装包里缺文件。" -ForegroundColor Red
  exit 1
}

& ([scriptblock]::Create((Get-Content -Raw -LiteralPath $syncLocal)))
Write-Host "已跑过一次合并同步"

$cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $syncLocal + '"'
schtasks /Create /TN "WhaleMemorySync" /TR $cmd /SC MINUTE /MO 3 /F | Out-Null
if ($LASTEXITCODE -eq 0) {
  Write-Host "已建计划任务 WhaleMemorySync（每 3 分钟一次）" -ForegroundColor Green
} else {
  Write-Host "计划任务没建成，之后可以手动跑 $syncLocal" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "完成。两边的日记已经合到一起了。"
