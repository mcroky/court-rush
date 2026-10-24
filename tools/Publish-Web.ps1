param(
 [string]$Version='0.7.1',
 [string]$Repository='mcroky/court-rush',
 [switch]$Push
)
$ErrorActionPreference='Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Use a numeric release version.' }
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pagesRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot 'release/pages'))
if (-not $pagesRoot.StartsWith($projectRoot+[IO.Path]::DirectorySeparatorChar)) { throw 'Invalid publish workspace.' }
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'build/web/engine-config.js'))) { throw 'Export Web and run tools/build_web.mjs first.' }
New-Item -ItemType Directory -Force -Path $pagesRoot | Out-Null
function Git-Pages { & git -C $pagesRoot @args; if ($LASTEXITCODE -ne 0) { throw 'Git Pages command failed.' } }
if (-not (Test-Path -LiteralPath (Join-Path $pagesRoot '.git'))) {
 Git-Pages init -b gh-pages
 Git-Pages remote add origin "https://github.com/$Repository.git"
}
$publishBranch=(& git -C $pagesRoot branch --show-current).Trim()
if ($publishBranch -ne 'gh-pages') { throw 'Refusing to publish from a different branch.' }
$destination=Join-Path $pagesRoot "v$Version"
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'build/web') -Force | Where-Object { $_.Extension -ne '.gz' } | ForEach-Object {
 Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
}
Set-Content -LiteralPath (Join-Path $pagesRoot '.nojekyll') -Value '' -Encoding utf8
$landing=@"
<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>코트러시 · COURT RUSH</title><meta http-equiv="refresh" content="0;url=./v$Version/"><script>location.replace('./v$Version/'+location.search+location.hash)</script><a href="./v$Version/">코트러시 플레이하기 →</a></html>
"@
Set-Content -LiteralPath (Join-Path $pagesRoot 'index.html') -Value $landing -Encoding utf8
Copy-Item -LiteralPath (Join-Path $projectRoot 'site/career.css') -Destination (Join-Path $pagesRoot 'career.css') -Force
foreach ($languageFile in @('language.css','locales.js','i18n.js')) {
 Copy-Item -LiteralPath (Join-Path $projectRoot "site/$languageFile") -Destination (Join-Path $pagesRoot $languageFile) -Force
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'site/privacy.html') -Destination (Join-Path $pagesRoot 'privacy.html') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'site/updates.json') -Destination (Join-Path $pagesRoot 'updates.json') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination (Join-Path $pagesRoot 'icon.svg') -Force
Git-Pages add --all
& git -C $pagesRoot diff --cached --quiet
if ($LASTEXITCODE -ne 0) { Git-Pages commit -m "Publish COURT RUSH v$Version" }
if ($Push) { Git-Pages -c credential.helper= -c 'credential.helper=!gh auth git-credential' push origin gh-pages }
Write-Output "Prepared v$Version at $destination"
