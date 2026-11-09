# Parses Test-ProfileRunsScript out of the profile, then loads the profile
# in a non-interactive child pwsh.
$profilePath = Join-Path $PSScriptRoot '..\home\Documents\PowerShell\profile.ps1'
$resolvedProfile = (Resolve-Path -LiteralPath $profilePath).Path
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($resolvedProfile, [ref]$tokens, [ref]$parseErrors)

if ($parseErrors.Count -gt 0) {
    $parseErrors | ForEach-Object { [Console]::Error.WriteLine($_.ToString()) }
    exit 1
}

$functionAst = $ast.Find(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Test-ProfileRunsScript'
    },
    $true)

if (-not $functionAst) {
    [Console]::Error.WriteLine('Test-ProfileRunsScript was not found.')
    exit 1
}

$yAst = $ast.Find(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            ($node.Name -eq 'y' -or $node.Name -eq 'global:y')
    },
    $true)

if (-not $yAst) {
    [Console]::Error.WriteLine('function y was not found.')
    exit 1
}

. ([scriptblock]::Create($functionAst.Extent.Text))

function Assert-ProfileRunsScript {
    param(
        [string]$Label,
        [bool]$Expected,
        [string[]]$CommandLine
    )

    $actual = Test-ProfileRunsScript -CommandLine $CommandLine
    if ($actual -ne $Expected) {
        [Console]::Error.WriteLine("${Label}: expected $Expected but was $actual")
        return $false
    }

    $true
}

# Command, File, EncodedCommand, and NonInteractive share no prefix, so there is no ambiguous argument to assert.
$results = @(
    (Assert-ProfileRunsScript 'pwsh -enc AAAA' $true @('pwsh', '-enc', 'AAAA'))
    (Assert-ProfileRunsScript 'pwsh -EncodedCommand AAAA' $true @('pwsh', '-EncodedCommand', 'AAAA'))
    (Assert-ProfileRunsScript 'pwsh -co Get-Date' $true @('pwsh', '-co', 'Get-Date'))
    (Assert-ProfileRunsScript 'pwsh.exe' $false @('pwsh.exe'))
)

if ($results -contains $false) {
    exit 1
}

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = (Get-Command -Name pwsh).Source
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.ArgumentList.Add('-NoProfile')
$psi.ArgumentList.Add('-Command')
$psi.ArgumentList.Add(". '$resolvedProfile'; 'PROFILE_OK'")
$proc = [System.Diagnostics.Process]::new()
$proc.StartInfo = $psi
[void]$proc.Start()
$stdout = $proc.StandardOutput.ReadToEnd()
$stderr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()
$proc.Dispose()

if ($stdout -notmatch 'PROFILE_OK') {
    [Console]::Error.WriteLine('profile load did not reach PROFILE_OK')
    [Console]::Error.WriteLine($stdout)
    [Console]::Error.WriteLine($stderr)
    exit 1
}

if ($stderr -match 'Enable-TransientPrompt') {
    [Console]::Error.WriteLine('non-interactive profile load mentioned Enable-TransientPrompt:')
    [Console]::Error.WriteLine($stderr)
    exit 1
}

exit 0
