# Ralph — Autonomous AI Agent Loop
# FALLBACK: Prefer OpenCode TUI native agent (run `opencode --agent ralph` in project root).
# Usage: .\ralph.ps1 [-Tool opencode|claude] [-MaxIterations 50]

param(
  [ValidateSet("opencode", "claude")]
  [string]$Tool = "opencode",
  [int]$MaxIterations = 50
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$PrdFile = Join-Path $ScriptDir "prd.json"
$ProgressFile = Join-Path $ScriptDir "progress.txt"
$PromptFile = Join-Path $ScriptDir "prompt.md"

# === Initialize progress file ===
if (-not (Test-Path $ProgressFile)) {
  @"
# Ralph Progress Log
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
---
"@ | Out-File -FilePath $ProgressFile -Encoding utf8
}

Write-Host "╔═══════════════════════════════════════════════════════════╗"
Write-Host "║  Ralph — Autonomous Agent Loop                            ║"
Write-Host "║  Tool: $Tool                                             ║"
Write-Host "║  Max iterations: $MaxIterations"
Write-Host "╚═══════════════════════════════════════════════════════════╝"

for ($i = 1; $i -le $MaxIterations; $i++) {
  Write-Host ""
  Write-Host "==============================================================="
  Write-Host "  Ralph Iteration $i of $MaxIterations ($Tool)"
  Write-Host "==============================================================="

  # Check if all stories are complete
  if (Test-Path $PrdFile) {
    try {
      $prd = Get-Content $PrdFile -Raw | ConvertFrom-Json
      $remaining = ($prd.userStories | Where-Object { -not $_.passes }).Count
    } catch {
      $remaining = "?"
    }
  } else {
    $remaining = "?"
  }
  Write-Host "  Remaining stories: $remaining"

  if ($remaining -eq 0) {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗"
    Write-Host "║  ALL STORIES COMPLETE!                                   ║"
    Write-Host "╚═══════════════════════════════════════════════════════════╝"
    exit 0
  }

  # Run the selected AI tool and capture output in real-time
  $outputBuilder = [System.Text.StringBuilder]::new()

  try {
    if ($Tool -eq "opencode") {
      & opencode run `
        --dangerously-skip-permissions `
        --dir $ProjectDir `
        -f $PromptFile `
        "Execute the complete instructions in the attached prompt file. Read and follow every step." `
        2>&1 | ForEach-Object {
          $line = $_.ToString()
          Write-Host $line
          [void]$outputBuilder.AppendLine($line)
        }
    } else {
      # Claude Code: pipe prompt via stdin
      $promptContent = Get-Content $PromptFile -Raw
      $promptContent | & claude --dangerously-skip-permissions --print 2>&1 | ForEach-Object {
        $line = $_.ToString()
        Write-Host $line
        [void]$outputBuilder.AppendLine($line)
      }
    }
  } catch {
    $errMsg = "Error: $_"
    Write-Host $errMsg
    [void]$outputBuilder.AppendLine($errMsg)
  }

  $output = $outputBuilder.ToString()

  # Check for completion signal
  if ($output -match "<promise>COMPLETE</promise>") {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗"
    Write-Host "║  Ralph completed all tasks at iteration $i!              ║"
    Write-Host "╚═══════════════════════════════════════════════════════════╝"
    exit 0
  }

  Write-Host ""
  Write-Host "Iteration $i complete. Continuing..."
  Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Ralph reached max iterations ($MaxIterations) without completing all stories."
Write-Host "Check $ProgressFile for status."
Write-Host "Run ralph.ps1 again to continue."
exit 1
