# Mirror a release to Brent's play folder (S:\Passage by default), waiting for the share to come back if it is down.
#   game\         robocopy /MIR of the repo's game\ (without tests\) - what Play.cmd runs with the Godot editor exe
#   build\        robocopy /MIR of build\windows\ - the exported EtherSyntax.exe (run tools/release/export_windows.sh first)
#   README.txt    the first line's "build vX (sha), copied YYYY-MM-DD", and under TO PLAY a line on starting the .exe
# Usage (release time only; nothing else writes to S:):
#   powershell -ExecutionPolicy Bypass -File tools\release\mirror_passage.ps1 -Build v0.56.0-label -Sha abc1234
#   -Target <folder> mirrors somewhere else (a scratch copy, to try it); -MaxMinutes how long to wait for the share.
param(
    [Parameter(Mandatory = $true)][string]$Build,
    [Parameter(Mandatory = $true)][string]$Sha,
    [string]$Target = 'S:\Passage',
    [int]$MaxMinutes = 480
)
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$exeDir = Join-Path $repo 'build\windows'
$exe = Join-Path $exeDir 'EtherSyntax.exe'
if (-not (Test-Path $exe)) { Write-Output "MIRROR: no $exe - run tools/release/export_windows.sh first"; exit 3 }
$stamp = (Get-Content (Join-Path $exeDir 'version.txt') -TotalCount 1).Trim()
# The stamp carries the sha the release was cut from (the stamp commit's parent), so compare the numbers only.
$want = ($Build -replace '^v', '') -replace '^(\d+\.\d+\.\d+).*', '$1'
if ($stamp.Split('+')[0] -ne $want) {
    Write-Output "MIRROR: warning - the exported build is stamped '$stamp', not $want (stamp, then re-export?)"
}

$readme = Join-Path $Target 'README.txt'
$deadline = (Get-Date).AddMinutes($MaxMinutes)
while (-not (Test-Path $readme)) {
    if ((Get-Date) -gt $deadline) { Write-Output "MIRROR: gave up - $Target still unavailable after $MaxMinutes min"; exit 2 }
    Start-Sleep -Seconds 30
}
Write-Output "MIRROR: $Target is up at $(Get-Date -Format 'HH:mm')"

# The project folder, as before (Brent's Play.cmd runs it with the editor exe).
robocopy (Join-Path $repo 'game') (Join-Path $Target 'game') /MIR /XD tests /NFL /NDL /NJH /NP | Select-Object -Last 6
$rcGame = $LASTEXITCODE
# The exported build.
robocopy $exeDir (Join-Path $Target 'build') /MIR /NFL /NDL /NJH /NP | Select-Object -Last 6
$rcBuild = $LASTEXITCODE

# README: the build line, and how to start the .exe (replaced on every mirror, inserted at the end of TO PLAY).
$lines = [System.Collections.Generic.List[string]](Get-Content $readme)
$lines[0] = $lines[0] -replace 'build v[^\s]+ \([0-9a-f]+\)', "build $Build ($Sha)"
$lines[0] = $lines[0] -replace 'copied \d{4}-\d{2}-\d{2}', "copied $(Get-Date -Format 'yyyy-MM-dd')"
$marker = 'build\EtherSyntax.exe'
for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i].Contains($marker)) { $lines.RemoveAt($i) } }
$at = $lines.FindIndex([Predicate[string]]{ param($l) $l -match '^TO PLAY' })
if ($at -ge 0) {
    $end = $at + 1
    while ($end -lt $lines.Count -and $lines[$end].Trim() -ne '') { $end++ }
    $lines.Insert($end, "  Or double-click $marker - the exported game ($stamp), no Godot needed; same saves.")
} else {
    $lines.Add('')
    $lines.Add("  To play without Godot: double-click $marker (the exported game, $stamp; same saves).")
}
Set-Content -Path $readme -Value $lines -Encoding utf8
Write-Output "MIRROR: robocopy game exit $rcGame, build exit $rcBuild (0-7 = ok)"
Get-Content $readme -TotalCount 1
if ($rcGame -ge 8 -or $rcBuild -ge 8) { exit 1 }
