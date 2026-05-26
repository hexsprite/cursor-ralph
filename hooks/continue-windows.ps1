#Requires -Version 5.1
<#
.SYNOPSIS
  Fallback continuation for Windows when stop-hook followup_message hits Cursor's
  default loop_limit (5). Prefer setting "loop_limit": null in hooks.json instead.

.PARAMETER CommandText
  Full slash command to type, e.g. "/ralph-loop --continue abc123"
#>
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$CommandText
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Start-Sleep -Seconds 1.5

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class RalphWin32 {
  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
}
"@

$cursor = [RalphWin32]::FindWindow([string]::Empty, 'Cursor')
if ($cursor -ne [IntPtr]::Zero) {
  [void][RalphWin32]::SetForegroundWindow($cursor)
  Start-Sleep -Milliseconds 300
}

$wshell = New-Object -ComObject WScript.Shell
if (-not $wshell.AppActivate('Cursor')) {
  Write-Error 'Could not focus Cursor. Bring Cursor to the foreground or set loop_limit: null in hooks.json.'
}

Start-Sleep -Milliseconds 300
$wshell.SendKeys($CommandText)
$wshell.SendKeys('{ENTER}')
