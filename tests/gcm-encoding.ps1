#requires -Version 7.0
$ErrorActionPreference = 'Stop'

function Get-RawStdoutBytes {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FileName,
        [Parameter(Mandatory = $true)]
        [string[]] $ArgumentList
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Failed to start $FileName"
    }

    $stderrTask = $process.StandardError.ReadToEndAsync()
    $stdout = [System.IO.MemoryStream]::new()
    $process.StandardOutput.BaseStream.CopyTo($stdout)
    [void]$stderrTask.GetAwaiter().GetResult()
    $process.WaitForExit()
    $bytes = $stdout.ToArray()
    $exitCode = $process.ExitCode
    $stderr = $stderrTask.Result.Trim()
    $process.Dispose()
    $stdout.Dispose()

    if ($exitCode -ne 0) {
        throw "$FileName exited with code $exitCode. $stderr"
    }

    return ,$bytes
}

function Assert-NoNulBytes {
    param(
        [byte[]] $Bytes,
        [string] $Label
    )

    foreach ($byte in $Bytes) {
        if ($byte -eq 0) {
            [Console]::Error.WriteLine("$Label stdout contains a 0x00 byte.")
            exit 1
        }
    }
}

$system32 = if ($env:PROCESSOR_ARCHITEW6432) {
    Join-Path $env:SystemRoot 'Sysnative'
} else {
    Join-Path $env:SystemRoot 'System32'
}
$powershellExe = Join-Path $system32 'WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powershellExe)) {
    [Console]::Error.WriteLine("powershell.exe is missing ($powershellExe).")
    exit 1
}

$fallbackCommand = '$OutputEncoding = [System.Text.UTF8Encoding]::new($false); [Console]::OutputEncoding = $OutputEncoding; [Environment]::GetFolderPath(''LocalApplicationData'')'
$fallbackBytes = Get-RawStdoutBytes -FileName $powershellExe -ArgumentList @(
    '-NoProfile',
    '-Command',
    $fallbackCommand
)
Assert-NoNulBytes -Bytes $fallbackBytes -Label 'powershell.exe'

$pwshExe = 'C:\Program Files\PowerShell\7\pwsh.exe'
if (Test-Path -LiteralPath $pwshExe) {
    $pwshBytes = Get-RawStdoutBytes -FileName $pwshExe -ArgumentList @(
        '-NoProfile',
        '-Command',
        "[Environment]::GetFolderPath('LocalApplicationData')"
    )
    Assert-NoNulBytes -Bytes $pwshBytes -Label 'pwsh.exe'
}

exit 0
