param([string]$Command)

function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-ErrorMsg { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }

switch ($Command) {
    "format" {
        Write-Info "Formatting code..."
        if (Test-Path "scripts") {
            gdformat scripts/
            Write-Success "Code formatted successfully."
        } else {
            Write-ErrorMsg "scripts folder not found."
        }
        break
    }

    "check" {
        Write-Info "Checking code formatting..."
        if (Test-Path "scripts") {
            gdformat --check scripts/
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Code is properly formatted."
            } else {
                Write-ErrorMsg "Formatting required."
                Write-Host "Run: .\scripts\commands.ps1 format" -ForegroundColor Yellow
            }
        } else {
            Write-ErrorMsg "scripts folder not found."
        }
        break
    }

    "help" {
        Write-Host "Available commands:" -ForegroundColor Cyan
        Write-Host "  format  - Format all GDScript code"
        Write-Host "  check   - Check formatting"
        Write-Host "  help    - Show this help message"
        Write-Host ""
        Write-Host "Example usage:"
        Write-Host "  .\scripts\commands.ps1 format"
        break
    }

    "analyze" {
    Write-Info "Detailed code quality analysis..."

    # Count files and lines
    $gdFiles = Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse -ErrorAction SilentlyContinue
    if (-not $gdFiles) {
        Write-ErrorMsg "No GDScript files found."
        return
    }

    $totalLines = 0
    $totalFunctions = 0
    $issuesFound = 0

    Write-Host "Analyzing $($gdFiles.Count) file(s)..." -ForegroundColor Yellow

    foreach ($file in $gdFiles) {
        $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
        if ($content) {
            $totalLines += $content.Count

            # Count functions
            $functions = $content | Where-Object { $_ -match "^func " }
            $totalFunctions += $functions.Count

            # Find untyped variables
            $untypedVars = $content | Where-Object { $_ -match "^\s*var\s+[a-zA-Z_][a-zA-Z0-9_]*\s*=" -and $_ -notmatch ":" }
            if ($untypedVars) {
                Write-Host "$($file.Name): $($untypedVars.Count) untyped variable(s) found" -ForegroundColor Yellow
                $issuesFound += $untypedVars.Count
            }

            # Find long lines
            $longLines = $content | Where-Object { $_.Length -gt 100 }
            if ($longLines) {
                Write-Host "$($file.Name): $($longLines.Count) line(s) longer than 100 characters" -ForegroundColor Yellow
                $issuesFound += $longLines.Count
            }
        }
    }

    # Summary
    Write-Host ""
    Write-Host "Analysis summary:" -ForegroundColor Cyan
    Write-Host "   Files: $($gdFiles.Count)"
    Write-Host "   Lines of code: $totalLines"
    Write-Host "   Functions: $totalFunctions"
    Write-Host "   Issues found: $issuesFound"

    if ($issuesFound -eq 0) {
        Write-Success "Excellent code quality!"
    } elseif ($issuesFound -lt 10) {
        Write-Host "[OK] Good code quality with minor issues" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Code quality improvements needed" -ForegroundColor Yellow
    }

    }

    "report" {
    Write-Info "Generating code quality report..."

    # Create report content
    $reportContent = @"
# Code Quality Report

**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')
**Project:** $(Split-Path -Leaf (Get-Location))

## Statistics

"@

    # Analyze GDScript files
    $gdFiles = Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse -ErrorAction SilentlyContinue
    if ($gdFiles) {
        $reportContent += "`n- GDScript files: $($gdFiles.Count)`n"

        $totalIssues = 0
        foreach ($file in $gdFiles) {
            $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
            if ($content) {
                $untypedVars = $content | Where-Object { $_ -match "^\s*var\s+[a-zA-Z_][a-zA-Z0-9_]*\s*=" -and $_ -notmatch ":" }
                $totalIssues += $untypedVars.Count
            }
        }

        $reportContent += "- Issues found: $totalIssues`n"

        if ($totalIssues -eq 0) {
            $reportContent += "`n**Status:** Excellent code quality`n"
        } else {
            $percentage = [math]::Round((1 - $totalIssues / ($gdFiles.Count * 5)) * 100, 1)
            $reportContent += "`n**Code Quality:** $percentage%`n"
        }
    }

    $reportContent | Out-File "quality_report.md" -Encoding UTF8
    Write-Success "Report saved to quality_report.md"
    }

    "deep-analyze" {
    Write-Info "Running deep code quality analysis..."

    # Initialize collections for tracking issues
    $allIssues = @()
    $processedFiles = 0

    # Get all GDScript files in the project
    $gdFiles = Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse -ErrorAction SilentlyContinue

    if (-not $gdFiles) {
        Write-Error "No GDScript files found in scripts directory"
        return
    }

    Write-Host "Analyzing $($gdFiles.Count) GDScript files..." -ForegroundColor Yellow

    foreach ($file in $gdFiles) {
        try {
            $content = Get-Content $file.FullName -ErrorAction Stop
            $fileName = $file.Name
            $processedFiles++

            Write-Host "Processing: $fileName" -ForegroundColor Gray

            # Check 1: Untyped variables
            $untypedVars = $content | Select-String "^\s*var\s+[a-zA-Z_][a-zA-Z0-9_]:*\s*=" | Where-Object { $_.Line -notmatch ":" }
            foreach ($match in $untypedVars) {
                $allIssues += [PSCustomObject]@{
                    Type = "Untyped Variable"
                    File = $fileName
                    Line = $match.LineNumber
                    Description = "Variable without type annotation"
                    Severity = "Warning"
                }
            }

            # Check 2: Functions without return type annotation
            $untypedFunctions = $content | Select-String "^func\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(" | Where-Object { $_.Line -notmatch "->" }
            foreach ($match in $untypedFunctions) {
                $allIssues += [PSCustomObject]@{
                    Type = "Untyped Function"
                    File = $fileName
                    Line = $match.LineNumber
                    Description = "Function without return type annotation"
                    Severity = "Warning"
                }
            }

            # Check 3: Long lines (over 100 characters)
            for ($i = 0; $i -lt $content.Count; $i++) {
                if ($content[$i].Length -gt 100) {
                    $allIssues += [PSCustomObject]@{
                        Type = "Long Line"
                        File = $fileName
                        Line = ($i + 1)
                        Description = "Line exceeds 100 characters ($($content[$i].Length) chars)"
                        Severity = "Style"
                    }
                }
            }

            # Check 4: Missing documentation for public functions
            for ($i = 0; $i -lt $content.Count; $i++) {
                if ($content[$i] -match "^func\s+[a-zA-Z_]") {
                    # Check if there's documentation before the function
                    $hasDocumentation = $false
                    if ($i -gt 0 -and $content[$i-1] -match "^##") {
                        $hasDocumentation = $true
                    }

                    if (-not $hasDocumentation) {
                        $allIssues += [PSCustomObject]@{
                            Type = "Missing Documentation"
                            File = $fileName
                            Line = ($i + 1)
                            Description = "Public function lacks documentation"
                            Severity = "Info"
                        }
                    }
                }
            }

            # Check 5: Unused variables (basic detection)
            $varDeclarations = $content | Select-String "^\s*var\s+([a-zA-Z_][a-zA-Z0-9_]*)" | ForEach-Object {
                $_.Matches[0].Groups[1].Value
            }

            foreach ($varName in $varDeclarations) {
                $usageCount = ($content | Select-String "\b$varName\b").Count
                if ($usageCount -eq 1) { # Only declared, never used
                    $lineNumber = ($content | Select-String "^\s*var\s+$varName").LineNumber
                    $allIssues += [PSCustomObject]@{
                        Type = "Unused Variable"
                        File = $fileName
                        Line = $lineNumber
                        Description = "Variable '$varName' is declared but never used"
                        Severity = "Warning"
                    }
                }
            }

        } catch {
            Write-Warning "Failed to process file: $fileName - $($_.Exception.Message)"
        }
    }

    # Display results
    Write-Host ""
    Write-Host "Deep Analysis Results:" -ForegroundColor Cyan
    Write-Host "Files processed: $processedFiles" -ForegroundColor White
    Write-Host "Issues found: $($allIssues.Count)" -ForegroundColor $(if ($allIssues.Count -eq 0) { "Green" } else { "Yellow" })

    if ($allIssues.Count -eq 0) {
        Write-Success "Excellent code quality! No issues detected."
    } else {
        # Group issues by type for better reporting
        $groupedIssues = $allIssues | Group-Object Type

        Write-Host ""
        Write-Host "Issue Summary:" -ForegroundColor Yellow
        foreach ($group in $groupedIssues) {
            Write-Host "  $($group.Name): $($group.Count) issues" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "Detailed Issues:" -ForegroundColor Yellow

        # Sort issues by severity and file
        $sortedIssues = $allIssues | Sort-Object Severity, File, Line

        foreach ($issue in $sortedIssues) {
            $severityColor = switch ($issue.Severity) {
                "Error" { "Red" }
                "Warning" { "Yellow" }
                "Style" { "Cyan" }
                "Info" { "Gray" }
                default { "White" }
            }

            Write-Host "  [$($issue.Severity)] " -ForegroundColor $severityColor -NoNewline
            Write-Host "$($issue.File):$($issue.Line) - $($issue.Description)" -ForegroundColor Gray
        }

        # Calculate quality score
        $totalLines = ($gdFiles | ForEach-Object { (Get-Content $_.FullName).Count } | Measure-Object -Sum).Sum
        $qualityScore = [math]::Round((1 - ($allIssues.Count / [math]::Max($totalLines, 1))) * 100, 1)

        Write-Host ""
        Write-Host "Code Quality Score: $qualityScore%" -ForegroundColor $(if ($qualityScore -gt 80) { "Green" } elseif ($qualityScore -gt 60) { "Yellow" } else { "Red" })

        # Provide recommendations
        if ($qualityScore -lt 80) {
            Write-Host ""
            Write-Host "Recommendations:" -ForegroundColor Cyan
            Write-Host "  - Add type annotations to variables and functions" -ForegroundColor Gray
            Write-Host "  - Break long lines into smaller chunks" -ForegroundColor Gray
            Write-Host "  - Add documentation comments for public functions" -ForegroundColor Gray
            Write-Host "  - Remove unused variables" -ForegroundColor Gray
        }
    }
    }

"ultimate-check" {
    Write-Host "COMPREHENSIVE CODE QUALITY CHECK" -ForegroundColor Magenta
    Write-Host "=================================" -ForegroundColor Magenta

    $startTime = Get-Date
    $overallSuccess = $true
    $results = @{
        Format = $null
        Analysis = $null
        Documentation = $null
        Report = $null
    }

    try {
        # Stage 1: Code Formatting Check
        Write-Host "`nStage 1: Code Formatting Validation..." -ForegroundColor Cyan
        Write-Host "Running format check on all GDScript files..." -ForegroundColor Gray

        try {
            & $PSCommandPath format
            $results.Format = "PASSED"
            Write-Host "Format check completed successfully" -ForegroundColor Green
        } catch {
            $results.Format = "FAILED"
            $overallSuccess = $false
            Write-Host "Format check failed: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Stage 2: Deep Code Analysis
        Write-Host "`nStage 2: Deep Code Analysis..." -ForegroundColor Cyan
        Write-Host "Analyzing code quality, patterns, and potential issues..." -ForegroundColor Gray

        try {
            & $PSCommandPath deep-analyze
            $results.Analysis = "PASSED"
            Write-Host "Deep analysis completed successfully" -ForegroundColor Green
        } catch {
            $results.Analysis = "FAILED"
            $overallSuccess = $false
            Write-Host "Deep analysis failed: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Stage 3: Documentation Coverage Analysis
        Write-Host "`nStage 3: Documentation Coverage Analysis..." -ForegroundColor Cyan
        Write-Host "Checking function documentation coverage..." -ForegroundColor Gray

        try {
            # Inline documentation analysis (replacing the function call)
            $gdFiles = Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse -ErrorAction SilentlyContinue
            $totalFunctions = 0
            $documentedFunctions = 0
            $functionsWithoutDocs = @()

            if ($gdFiles) {
                foreach ($file in $gdFiles) {
                    try {
                        $content = Get-Content $file.FullName -ErrorAction Stop

                        for ($i = 0; $i -lt $content.Count; $i++) {
                            if ($content[$i] -match "^func\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(") {
                                $functionName = $matches[1]
                                $totalFunctions++

                                # Check for documentation (## comment) in the line before
                                if ($i -gt 0 -and $content[$i-1] -match "^\s*##") {
                                    $documentedFunctions++
                                } else {
                                    $functionsWithoutDocs += @{
                                        File = $file.Name
                                        Function = $functionName
                                        Line = $i + 1
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-Warning "Could not analyze file: $($file.Name) - $($_.Exception.Message)"
                    }
                }
            }

            $results.Documentation = "COMPLETED"

            if ($totalFunctions -gt 0) {
                $docPercentage = [math]::Round(($documentedFunctions / $totalFunctions) * 100, 1)
                Write-Host "Documentation Coverage: $docPercentage% ($documentedFunctions/$totalFunctions functions)" -ForegroundColor White

                if ($docPercentage -lt 50) {
                    Write-Host "Warning: Low documentation coverage detected" -ForegroundColor Yellow
                    Write-Host "Functions without documentation:" -ForegroundColor Yellow
                    foreach ($func in $functionsWithoutDocs | Select-Object -First 5) {
                        Write-Host "  $($func.File):$($func.Line) - $($func.Function)" -ForegroundColor Gray
                    }
                    if ($functionsWithoutDocs.Count -gt 5) {
                        Write-Host "  ... and $($functionsWithoutDocs.Count - 5) more" -ForegroundColor Gray
                    }
                } elseif ($docPercentage -ge 80) {
                    Write-Host "Excellent documentation coverage!" -ForegroundColor Green
                }
            } else {
                Write-Host "No functions found for documentation analysis" -ForegroundColor Yellow
            }
        } catch {
            $results.Documentation = "FAILED"
            $overallSuccess = $false
            Write-Host "Documentation analysis failed: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Stage 4: Report Generation
        Write-Host "`nStage 4: Generating Quality Report..." -ForegroundColor Cyan
        Write-Host "Creating comprehensive quality report..." -ForegroundColor Gray

        try {
            & $PSCommandPath report
            $results.Report = "GENERATED"
            Write-Host "Quality report generated successfully" -ForegroundColor Green
        } catch {
            $results.Report = "FAILED"
            $overallSuccess = $false
            Write-Host "Report generation failed: $($_.Exception.Message)" -ForegroundColor Red
        }

    } catch {
        Write-Host "Critical error during quality check: $($_.Exception.Message)" -ForegroundColor Red
        $overallSuccess = $false
    } finally {
        # Calculate execution time and display summary
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds

        # Fixed string formatting
        $separator = "=" * 50
        Write-Host "`n$separator" -ForegroundColor Magenta
        Write-Host "QUALITY CHECK SUMMARY" -ForegroundColor Magenta
        Write-Host "$separator" -ForegroundColor Magenta

        # Display results for each stage
        Write-Host "`nStage Results:" -ForegroundColor White

        $formatColor = if ($results.Format -eq "PASSED") { "Green" } else { "Red" }
        Write-Host "  Format Check:        $($results.Format)" -ForegroundColor $formatColor

        $analysisColor = if ($results.Analysis -eq "PASSED") { "Green" } else { "Red" }
        Write-Host "  Deep Analysis:       $($results.Analysis)" -ForegroundColor $analysisColor

        $docColor = if ($results.Documentation -eq "COMPLETED") { "Green" } else { "Red" }
        Write-Host "  Documentation:       $($results.Documentation)" -ForegroundColor $docColor

        $reportColor = if ($results.Report -eq "GENERATED") { "Green" } else { "Red" }
        Write-Host "  Report Generation:   $($results.Report)" -ForegroundColor $reportColor

        # Overall status
        $statusColor = if ($overallSuccess) { "Green" } else { "Red" }
        $statusText = if ($overallSuccess) { "PASSED" } else { "FAILED" }
        Write-Host "`nOverall Status: $statusText" -ForegroundColor $statusColor

        # Execution metrics
        Write-Host "`nExecution Details:" -ForegroundColor White
        Write-Host "  Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Gray
        Write-Host "  Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

        if (Test-Path "quality_report.md") {
            Write-Host "  Report saved: quality_report.md" -ForegroundColor Gray
        }

        # Exit with appropriate code
        if (-not $overallSuccess) {
            Write-Host "`nSome quality checks failed. Please review the issues above." -ForegroundColor Yellow
        } else {
            Write-Host "`nAll quality checks passed successfully!" -ForegroundColor Green
        }
    }
}

    default {
        Write-ErrorMsg "Unknown command. Use: .\scripts\commands.ps1 help"
        break
    }
}

# Helper function for documentation coverage analysis - define this OUTSIDE the switch statement
function Measure-DocumentationCoverage {
    $gdFiles = Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse -ErrorAction SilentlyContinue
    $totalFunctions = 0
    $documentedFunctions = 0
    $functionsWithoutDocs = @()

    if (-not $gdFiles) {
        return @{
            TotalFunctions = 0
            DocumentedFunctions = 0
            Coverage = 0
            UndocumentedFunctions = @()
        }
    }

    foreach ($file in $gdFiles) {
        try {
            $content = Get-Content $file.FullName -ErrorAction Stop

            for ($i = 0; $i -lt $content.Count; $i++) {
                if ($content[$i] -match "^func\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(") {
                    $functionName = $matches[1]
                    $totalFunctions++

                    # Check for documentation (## comment) in the line before
                    $hasDocumentation = $false
                    if ($i -gt 0 -and $content[$i-1] -match "^\s*##") {
                        $hasDocumentation = $true
                        $documentedFunctions++
                    }

                    if (-not $hasDocumentation) {
                        $functionsWithoutDocs += @{
                            File = $file.Name
                            Function = $functionName
                            Line = $i + 1
                        }
                    }
                }
            }
        } catch {
            Write-Warning "Could not analyze file: $($file.Name) - $($_.Exception.Message)"
        }
    }

    $coverage = if ($totalFunctions -gt 0) {
        [math]::Round(($documentedFunctions / $totalFunctions) * 100, 1)
    } else {
        0
    }

    return @{
        TotalFunctions = $totalFunctions
        DocumentedFunctions = $documentedFunctions
        Coverage = $coverage
        UndocumentedFunctions = $functionsWithoutDocs
    }
}
