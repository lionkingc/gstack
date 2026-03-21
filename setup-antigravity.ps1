# gstack setup for Antigravity
# Install skills from .agents/skills/ (Codex format) to ~/.gemini/antigravity/skills/
# with path references updated for Antigravity + Windows Git Bash compatibility

$ErrorActionPreference = "Stop"

$GstackDir = $PSScriptRoot
$AgentsSkillsDir = Join-Path $GstackDir ".agents\skills"
$AntigravitySkillsDir = Join-Path $env:USERPROFILE ".gemini\antigravity\skills"

# Compute tilde-style path for gstack (used in bash scripts inside SKILL.md)
$GstackRelToHome = $GstackDir.Substring($env:USERPROFILE.Length + 1) -replace '\\', '/'
$GstackTildePath = "~/$GstackRelToHome"

Write-Host "gstack Antigravity setup"
Write-Host "  gstack dir: $GstackDir"
Write-Host "  antigravity skills dir: $AntigravitySkillsDir"
Write-Host "  gstack tilde path: $GstackTildePath"
Write-Host ""

if (-not (Test-Path $AgentsSkillsDir)) {
    Write-Error "Missing .agents/skills/ directory. Run 'bun run build' first."
    exit 1
}

if (-not (Test-Path $AntigravitySkillsDir)) {
    New-Item -ItemType Directory -Path $AntigravitySkillsDir -Force | Out-Null
}

$skillDirs = Get-ChildItem -Path $AgentsSkillsDir -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "SKILL.md")
}
$installed = @()

foreach ($skillDir in $skillDirs) {
    $skillName = $skillDir.Name
    $srcSkillMd = Join-Path $skillDir.FullName "SKILL.md"

    $dstDir = Join-Path $AntigravitySkillsDir $skillName
    $dstSkillMd = Join-Path $dstDir "SKILL.md"

    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    $content = Get-Content -Path $srcSkillMd -Raw -Encoding UTF8

    # === Path replacements ===

    # 1. Replace codex global paths with actual gstack tilde path
    $content = $content -replace '~/.codex/skills/gstack/', "$GstackTildePath/"

    # 2. Fix BROWSE_SETUP: $_ROOT/.agents/skills/gstack/ -> global gstack path
    $content = $content -replace '\$_ROOT/\.agents/skills/gstack/', "$GstackTildePath/"

    # 3. Remaining .agents/skills/gstack/ references (preamble fallbacks)
    $content = $content -replace '(?<!\$_ROOT/)\.agents/skills/gstack/', "$GstackTildePath/"

    # === Windows / Git Bash compatibility ===

    # 4. Replace macOS `open https://...` with Windows `start https://...`
    $content = $content -replace '(?m)^(open )(https?://)', 'start $2'

    # 5. Wrap ```bash blocks with PowerShell bash -c @' ... '@ so they correctly run natively without quoting issues
    # Uses (?sm) multiline + singleline to allow matching padded code blocks exactly layouted.
    $bashToPs = '$1```powershell' + "`n" + '$1& "C:\Program Files\Git\bin\bash.exe" -c @''' + "`n" + '$2' + "`n" + '$1''@' + "`n" + '$1```'
    $content = [regex]::Replace($content, '(?sm)^([ \t]*)```bash\r?\n(.*?)\r?\n[ \t]*```[ \t]*\r?$', $bashToPs)

    Set-Content -Path $dstSkillMd -Value $content -Encoding UTF8 -NoNewline

    $installed += $skillName
    Write-Host "  installed: $skillName"
}

Write-Host ""
Write-Host "gstack ready (antigravity). Installed $($installed.Count) skills."
Write-Host "  skills dir: $AntigravitySkillsDir"
Write-Host "  skills: $($installed -join ', ')"
