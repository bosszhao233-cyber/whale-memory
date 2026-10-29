# 大肥鲸·双机记忆合并同步（Git 版）
# 逻辑：
#   1) 先从仓库拉最新的
#   2) 把仓库里"本机没有的段落/表格行"并进本机日记（不覆盖，只补）
#   3) 再把本机内容写回仓库、提交、推上去
# 两台不会同时开机，所以不会真冲突；就算同时开，段落级合并也不会丢内容。

$ErrorActionPreference = 'Continue'

# DSH_HOME
$dsh = $env:DSH_HOME
if (-not $dsh -or -not (Test-Path $dsh)) {
  if (Test-Path 'E:\dsh\profiles') { $dsh = 'E:\dsh' }
  else { $dsh = Join-Path $env:USERPROFILE '.dsh' }
}

$bili = Join-Path $env:USERPROFILE '.bili-ai'
$repo = Join-Path $dsh 'whale-memory'
$log  = Join-Path $dsh 'whale-sync.log'

function Log($msg) {
  $line = "{0}  {1}" -f (Get-Date -Format 's'), $msg
  Add-Content -Path $log -Value $line -Encoding utf8
}

function Normalize([string]$t) {
  if ($null -eq $t) { return '' }
  # 去掉空白差异，只比内容
  return (($t -split "`n") | ForEach-Object { $_.TrimEnd() } | Where-Object { $_.Trim() -ne '' }) -join "`n"
}

function Merge-Diary([string]$localText, [string]$remoteText) {
  if (-not $remoteText) { return $localText }
  if (-not $localText)  { return $remoteText }

  $localNorm = Normalize $localText
  $result = $localText -replace "`r`n", "`n"
  $remoteLines = ($remoteText -replace "`r`n", "`n") -split "`n"

  # ① 表格行：远端有、本机没有的「看过」行，补进本机第一张表
  $localBvs = [regex]::Matches($localText, 'BV[0-9A-Za-z]{10}') | ForEach-Object { $_.Value }
  $missingRows = @()
  foreach ($line in $remoteLines) {
    if ($line -match '^\|\s*\d{4}-\d{2}-\d{2}' -and $line -match '(BV[0-9A-Za-z]{10})') {
      $bv = $Matches[1]
      if ($localBvs -notcontains $bv) { $missingRows += $line }
    }
  }
  if ($missingRows.Count -gt 0) {
    $rl = $result -split "`n"
    $lastTable = -1
    for ($i = 0; $i -lt $rl.Count; $i++) { if ($rl[$i].StartsWith('|')) { $lastTable = $i } }
    if ($lastTable -ge 0) {
      $before = @()
      if ($lastTable -ge 0) { $before = $rl[0..$lastTable] }
      $after = @()
      if ($lastTable + 1 -lt $rl.Count) { $after = $rl[($lastTable + 1)..($rl.Count - 1)] }
      $result = (($before + $missingRows + $after) -join "`n")
    } else {
      $result = $result + "`n`n## 看过`n`n| 时间 | BV | 标题 | 简介 | 想法 |`n| --- | --- | --- | --- | --- |`n" + ($missingRows -join "`n") + "`n"
    }
    Log ("merged {0} table row(s)" -f $missingRows.Count)
  }

  # ② 段落：远端有、本机没有的「## 」块，整块补到末尾
  $blocks = @()
  $cur = $null
  foreach ($line in $remoteLines) {
    if ($line -match '^##\s') {
      if ($cur) { $blocks += ,$cur }
      $cur = @($line)
    } elseif ($cur) {
      $cur += $line
    }
  }
  if ($cur) { $blocks += ,$cur }

  $added = 0
  foreach ($b in $blocks) {
    $head = $b[0]
    if ($head -match '看过') { continue }   # 表格已经按行合并过
    $blockText = ($b -join "`n").TrimEnd()
    if (-not (Normalize $blockText)) { continue }
    if ((Normalize $result).Contains((Normalize $blockText))) { continue }
    $result = $result.TrimEnd() + "`n`n" + $blockText + "`n"
    $added++
  }
  if ($added -gt 0) { Log ("merged {0} section(s)" -f $added) }

  return $result
}

if (-not (Test-Path $repo)) {
  Log "repo missing: $repo"
  exit 0
}

Push-Location $repo
try {
  git pull --no-rebase --no-edit 2>&1 | Out-Null

  $pairs = @(
    @{ local = Join-Path $dsh  'whale-diary.md';         repo = Join-Path $repo 'whale-diary.md' },
    @{ local = Join-Path $dsh  'whale-diary-private.md'; repo = Join-Path $repo 'whale-diary-private.md' },
    @{ local = Join-Path $bili 'persona.md';             repo = Join-Path $repo 'persona.md' }
  )

  foreach ($p in $pairs) {
    $localExists  = Test-Path $p.local
    $repoExists   = Test-Path $p.repo
    if (-not $localExists -and -not $repoExists) { continue }

    $localText  = if ($localExists) { Get-Content -Raw -Encoding UTF8 -LiteralPath $p.local } else { '' }
    $repoText   = if ($repoExists)  { Get-Content -Raw -Encoding UTF8 -LiteralPath $p.repo }  else { '' }

    $merged = Merge-Diary $localText $repoText

    if ($localExists -or $repoExists) {
      $dir = Split-Path $p.local -Parent
      if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      if ($merged -ne $localText) {
        [System.IO.File]::WriteAllText($p.local, $merged, (New-Object System.Text.UTF8Encoding($false)))
        Log ("pulled into local: {0}" -f (Split-Path $p.local -Leaf))
      }
      if ($merged -ne $repoText) {
        [System.IO.File]::WriteAllText($p.repo, $merged, (New-Object System.Text.UTF8Encoding($false)))
      }
    }
  }

  git add -A 2>&1 | Out-Null
  $pending = git status --porcelain
  if ($pending) {
    git commit -q -m ("memory sync " + (Get-Date -Format 'yyyy-MM-dd HH:mm')) 2>&1 | Out-Null
    git push 2>&1 | Out-Null
    Log "pushed"
  }
}
finally {
  Pop-Location
}
