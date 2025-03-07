# extract.ps1
param(
    [string]$InputDir = "."
)

# 配置参数
$OutputSubdir = "missing_translations"
$FilePattern = "*.lang"

# 遍历所有.lang文件
Get-ChildItem -Path $InputDir -Filter $FilePattern | ForEach-Object {
    try {
        # 创建输出目录
        $outputDir = Join-Path $_.Directory.FullName $OutputSubdir
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir | Out-Null
        }

        # 生成输出路径
        $outputPath = Join-Path $outputDir ($_.BaseName + "_missing.lang")

        # 处理文件内容
        $count = 0
        Get-Content $_.FullName | Where-Object {
            if ($_ -match '^MISSING_TRANSLATION:') {
                $count++
                $true
            }
        } | Out-File $outputPath -Encoding utf8

        # 显示结果
        Write-Host "处理完成: $($_.Name)" -ForegroundColor Cyan
        Write-Host "  找到未翻译项: $count" -ForegroundColor Yellow
        Write-Host "  输出位置: $outputPath`n" -ForegroundColor Green
    }
    catch {
        Write-Host "处理失败: $($_.Name)" -ForegroundColor Red
        Write-Host "  错误信息: $($_.Exception.Message)`n" -ForegroundColor DarkRed
    }
}