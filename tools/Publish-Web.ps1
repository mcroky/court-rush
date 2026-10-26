param(
 [string]$Version='0.8.6',
 [string]$Repository='mcroky/court-rush',
 [string]$PagesDirectory='release/pages',
 [switch]$Push
)
$ErrorActionPreference='Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Use a numeric release version.' }
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pagesRoot=[IO.Path]::GetFullPath((Join-Path $projectRoot $PagesDirectory))
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
if ((& git -C $pagesRoot status --porcelain)) { throw 'Pages checkout has pending changes. Review them before publishing.' }
$releaseNode=(Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $releaseNode) { $releaseNode=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' }
& $releaseNode (Join-Path $projectRoot 'tools/verify_web_release.mjs') $Version
if ($LASTEXITCODE -ne 0) { throw 'Web release verification failed.' }
$destination=Join-Path $pagesRoot "v$Version"
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'build/web') -Force | Where-Object { $_.Extension -ne '.gz' } | ForEach-Object {
 Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
}
Set-Content -LiteralPath (Join-Path $pagesRoot '.nojekyll') -Value '' -Encoding utf8
& $releaseNode (Join-Path $projectRoot 'tools/prepare_stable_pages.mjs') (Join-Path $projectRoot 'build/web') $pagesRoot $Version
if ($LASTEXITCODE -ne 0) { throw 'Stable page preparation failed.' }
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
