# Comprehensive scan for Chinese hardcoded strings in all Dart files
# Excludes: imports, comments, data definitions, already-translated t() calls

$projectDir = "C:\Users\ziboo\AppData\Local\Reasonix\workspace\asset_management"
$allFiles = Get-ChildItem "$projectDir\lib" -Recurse -Filter "*.dart" | Where-Object { $_.FullName -notmatch "\\generated\\" }

# Build regex for Chinese characters using Unicode category
# CJK Unified Ideographs: U+4E00–U+9FFF
$cjkPattern = "[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]"

$results = @()

foreach ($file in $allFiles) {
    $lines = Get-Content $file.FullName -Encoding UTF8
    $relPath = $file.FullName.Substring($projectDir.Length + 1)
    $lineNum = 0
    
    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.Trim()
        
        # Skip known non-UI patterns
        if ($trimmed -match "^\s*//") { continue }
        if ($trimmed -match "^\s*import") { continue }
        if ($trimmed -match "asset_management|DateFormat|dateFormat|formatCn|monthFormat|yearFormat") { continue }
        if ($trimmed -match "presetCategories|getCategory|AppConstants|AppDateUtils") { continue }
        if ($trimmed -match "languageCode|'zh'|localeCodeProvider|localeSettingProvider") { continue }
        if ($trimmed -match "Common|Collection|GPLv3|verParts|licenseName") { continue }
        if ($trimmed -match "t\(|ref\.read|AppToast\.|Toast\.") { continue }
        if ($trimmed -match "locale\s*=|locale\s*==") { continue }
        
        # Check for Chinese characters inside quoted strings
        if ($trimmed -match "'([^']{2,80})'" -or $trimmed -match '"([^"]{2,80})"') {
            $matched = $matches[1]
            if ($matched -match $cjkPattern) {
                $results += [PSCustomObject]@{
                    File = $relPath
                    Line = $lineNum
                    Text = $trimmed.Substring(0, [Math]::Min(100, $trimmed.Length))
                }
            }
        }
    }
}

# Group by file and display
$grouped = $results | Group-Object File

foreach ($group in $grouped) {
    Write-Host "`n=== $($group.Name) ===" -ForegroundColor Yellow
    foreach ($item in $group.Group) {
        Write-Host "  L$($item.Line): $($item.Text)" -ForegroundColor Gray
    }
}

Write-Host "`n=== TOTAL: $($results.Count) Chinese strings in $($grouped.Count) files ===" -ForegroundColor Cyan
Write-Host "Files:" -ForegroundColor Cyan
$grouped | ForEach-Object { Write-Host "  $($_.Count) x $($_.Name)" }
