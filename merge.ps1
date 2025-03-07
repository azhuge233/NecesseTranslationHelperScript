# merge_translations.ps1
param(
    [string]$RootDir = ".",
    [switch]$Backup = $true
)

$MISSING_PREFIX = "MISSING_TRANSLATION:"
$TRANSLATION_DIR = "missing_translations"

function Merge-File {
    param(
        [string]$OriginalFile,
        [string]$TranslationFile
    )

    try {
        # 读取翻译内容
        $translations = @{}
        Get-Content $TranslationFile | ForEach-Object {
            if ($_ -match "^${MISSING_PREFIX}(.+?)=(.+)") {
                $translations[$matches[1].Trim()] = $matches[2]
            }
        }

        # 创建临时文件
        $tempFile = [System.IO.Path]::GetTempFileName()
        
        # 流式处理原始文件
        $reader = [System.IO.StreamReader]::new($OriginalFile)
        $writer = [System.IO.StreamWriter]::new($tempFile)
        $replacedCount = 0

        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            
            if ($line.StartsWith($MISSING_PREFIX)) {
                $keyValue = $line.Substring($MISSING_PREFIX.Length).Split('=', 2)
                $key = $keyValue[0].Trim()
                
                if ($translations.ContainsKey($key)) {
                    $newLine = "${key}=$($translations[$key])"
                    $replacedCount++
                    $writer.WriteLine($newLine)
                    continue
                }
            }
            
            $writer.WriteLine($line)
        }

        # 关闭文件流
        $reader.Close()
        $writer.Close()

        # 创建备份
        if ($Backup) {
            $backupPath = "${OriginalFile}.bak"
            Copy-Item $OriginalFile $backupPath -Force
        }

        # 替换原始文件
        Move-Item $tempFile $OriginalFile -Force

        return [PSCustomObject]@{
            FileName = (Split-Path $OriginalFile -Leaf)
            Replaced = $replacedCount
            Missing = ($translations.Count - $replacedCount)
            Success = $true
        }
    }
    catch {
        return [PSCustomObject]@{
            FileName = (Split-Path $OriginalFile -Leaf)
            Replaced = 0
            Missing = 0
            Success = $false
            Error   = $_.Exception.Message
        }
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $writer) { $writer.Dispose() }
    }
}

# 主流程
try {
    # 查找所有翻译文件
    $translationFiles = Get-ChildItem -Path $RootDir -Filter "*_missing.lang" -Recurse |
                        Where-Object { $_.Directory.Name -eq $TRANSLATION_DIR }

    if ($translationFiles.Count -eq 0) {
        Write-Host "未找到任何翻译文件（*_missing.lang）" -ForegroundColor Yellow
        return
    }

    # 进度计数器
    $total = $translationFiles.Count
    $processed = 0

    $results = $translationFiles | ForEach-Object {
        # 显示进度
        $progress = [math]::Round(($processed / $total) * 100, 2)
        Write-Progress -Activity "合并翻译文件" -Status "$progress% 完成" `
            -PercentComplete $progress -CurrentOperation $_.Name

        # 计算原始文件路径
        $baseName = $_.BaseName -replace '_missing$',''
        $originalPath = Join-Path $_.Directory.Parent.FullName "$baseName.lang"

        if (-not (Test-Path $originalPath)) {
            Write-Host "[警告] 原始文件不存在：$($_.Name) → $(Split-Path $originalPath -Leaf)" -ForegroundColor DarkYellow
            return [PSCustomObject]@{
                FileName = "$baseName.lang"
                Replaced = 0
                Missing = 0
                Success = $false
                Error   = "Original file not found"
            }
        }

        # 执行合并
        $result = Merge-File -OriginalFile $originalPath -TranslationFile $_.FullName

        # 显示结果
        if ($result.Success) {
            Write-Host "[$($result.FileName)]" -NoNewline -ForegroundColor Cyan
            Write-Host " 替换 $($result.Replaced) 项" -NoNewline -ForegroundColor Green
            if ($result.Missing -gt 0) {
                Write-Host " (未匹配项：$($result.Missing))" -ForegroundColor Red
            }
            else {
                Write-Host ""
            }
        }
        else {
            Write-Host "[$($result.FileName)]" -NoNewline -ForegroundColor Cyan
            Write-Host " 处理失败：$($result.Error)" -ForegroundColor Red
        }

        $processed++
        $result
    }

    # 过滤空结果并汇总
    $validResults = $results | Where-Object { $_ -ne $null }
    
    $totalReplaced = ($validResults | Measure-Object -Property Replaced -Sum).Sum
    $totalMissing = ($validResults | Measure-Object -Property Missing -Sum).Sum

    Write-Host "`n合并完成报告：" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "• 已处理文件: $($validResults.Count)" -ForegroundColor Cyan
    Write-Host "• 成功替换项: $totalReplaced" -ForegroundColor Green
    if ($totalMissing -gt 0) {
        Write-Host "• 未匹配翻译: $totalMissing" -ForegroundColor Red
    }
    if ($Backup) {
        Write-Host "• 原始文件备份: 已创建 (.bak)" -ForegroundColor Magenta
    }
}
catch {
    Write-Host "发生错误: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}