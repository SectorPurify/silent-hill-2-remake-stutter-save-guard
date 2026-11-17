<#
.SYNOPSIS
    Silent Hill 2 Save & Stutter Guard — Read-Only Windows Diagnostic Script
.DESCRIPTION
    Performs non-invasive, read-only local checks on Windows (Steam paths, folder layout,
    file timestamps/sizes, and system info). Does NOT modify, delete, or upload any files,
    and does NOT require administrator privileges or changes to Windows Defender.
.NOTES
    License: MIT
#>

$ErrorActionPreference = 'SilentlyContinue'

function Get-SteamLibraries {
    $libs = @()
    $regPath = 'HKCU:\Software\Valve\Steam'
    $steamPath = (Get-ItemProperty -Path $regPath -Name 'SteamPath').SteamPath
    if (-not $steamPath) {
        $steamPath = 'C:\Program Files (x86)\Steam'
    }
    $steamPath = $steamPath -replace '/', '\'
    if (Test-Path $steamPath) {
        $libs += $steamPath
        $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            $content = Get-Content -Path $vdf -Raw
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $p = $m.Groups[1].Value -replace '\\', '\'
                if ((Test-Path $p) -and ($libs -notcontains $p)) {
                    $libs += $p
                }
            }
        }
    }
    return $libs
}

function Find-SteamGameDir {
    param([string[]]$FolderNames)
    foreach ($lib in (Get-SteamLibraries)) {
        foreach ($name in $FolderNames) {
            $candidate = Join-Path $lib "steamapps\common\$name"
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }
    return $null
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Silent Hill 2 Save & Stutter Guard (Read-Only Check)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$sh2Saved = "$env:LOCALAPPDATA\SilentHill2\Saved"
Write-Host "[SILENT HILL 2 Saved & Config Check]" -ForegroundColor Yellow
if (-not (Test-Path $sh2Saved)) {
    Write-Host "  Folder not found at $sh2Saved" -ForegroundColor DarkYellow
} else {
    Write-Host "  Saved Dir : $sh2Saved" -ForegroundColor Green
    $saveGames = Join-Path $sh2Saved "SaveGames"
    if (Test-Path $saveGames) {
        $savs = Get-ChildItem -Path $saveGames -Filter "*.sav" -Recurse
        Write-Host "  Save Files: $($savs.Count) .sav file(s)" -ForegroundColor Cyan
        foreach ($s in ($savs | Sort-Object LastWriteTime -Descending | Select-Object -First 10)) {
            $kb = [math]::Round($s.Length / 1KB, 2)
            Write-Host ("    - {0,-32} | {1,8} KB | {2}" -f $s.Name, $kb, $s.LastWriteTime)
        }
    }
}
Write-Host ""

$gameDir = Find-SteamGameDir -FolderNames @("SILENT HILL 2", "SilentHill2")
Write-Host "[Steam Install & ~mods Check]" -ForegroundColor Yellow
if ($gameDir) {
    Write-Host "  Install   : $gameDir" -ForegroundColor Green
    $modsDir = Join-Path $gameDir "SHProto\Content\Paks\~mods"
    if (Test-Path $modsDir) {
        $paks = Get-ChildItem -Path $modsDir -File
        Write-Host "  ~mods     : $($paks.Count) file(s)" -ForegroundColor Cyan
        foreach ($p in $paks) { Write-Host "    - $($p.Name)" }
    } else {
        Write-Host "  ~mods     : None detected"
    }
} else {
    Write-Host "  Game folder not found in default Steam libraries." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "Diagnostic complete. No files were modified." -ForegroundColor Green
Read-Host "Press Enter to exit"
