"analyze" {
    Write-Info "Детальний аналіз якості коду..."

    # Підрахунок файлів та рядків
    $gdFiles = Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse -ErrorAction Silently-Continue
    if (-not $gdFiles) {
        Write-Error "GDScript файли не знайдені"
        return
    }

    $totalLines = 0
    $totalFunctions = 0
    $issuesFound = 0

    Write-Host "Аналізую $($gdFiles.Count) файлів..." -ForegroundColor Yellow

    foreach ($file in $gdFiles) {
        $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
        if ($content) {
            $totalLines += $content.Count

            # Підрахунок функцій
            $functions = $content | Where-Object { $_ -match "^func " }
            $totalFunctions += $functions.Count

            # Пошук проблем
            $untypedVars = $content | Where-Object { $_ -match "^\s*var\s+[a-zA-Z_][a-zA-Z0-9_]*\s*=" -and $_ -notmatch ":" }
            if ($untypedVars) {
                Write-Host "$($file.Name): знайдено $($untypedVars.Count) нетипізованих змінних" -ForegroundColor Yellow
                $issuesFound += $untypedVars.Count
            }

            # Пошук довгих рядків
            $longLines = $content | Where-Object { $_.Length -gt 100 }
            if ($longLines) {
                Write-Host "$($file.Name): $($longLines.Count) рядків довше 100 символів" -ForegroundColor Yellow
                $issuesFound += $longLines.Count
            }
        }
    }

    # Звіт
    Write-Host ""
    Write-Host "Підсумок аналізу:" -ForegroundColor Cyan
    Write-Host "   Файлів: $($gdFiles.Count)"
    Write-Host "   Рядків коду: $totalLines"
    Write-Host "   Функцій: $totalFunctions"
    Write-Host "   Знайдено проблем: $issuesFound"

    if ($issuesFound -eq 0) {
        Write-Success "Відмінна якість коду!"
    } elseif ($issuesFound -lt 10) {
        Write-Host "Хороша якість коду з невеликими зауваженнями" -ForegroundColor Green
    } else {
        Write-Host "Потрібні покращення якості коду" -ForegroundColor Yellow
    }
}
