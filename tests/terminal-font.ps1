# Parses Set-WindowsTerminalDefaultFont out of the Windows font script.
$scriptPath = Join-Path $PSScriptRoot '..\home\.chezmoiscripts\run_before_windows-font.ps1.tmpl'
$resolved = (Resolve-Path -LiteralPath $scriptPath).Path
$source = [System.IO.File]::ReadAllText($resolved)
$source = [regex]::Replace($source, '(?m)^\{\{.*\}\}\r?\n?', '')

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, $resolved, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    $parseErrors | ForEach-Object { [Console]::Error.WriteLine($_.ToString()) }
    exit 1
}

$functionAst = $ast.Find(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Set-WindowsTerminalDefaultFont'
    },
    $true)

if (-not $functionAst) {
    [Console]::Error.WriteLine('Set-WindowsTerminalDefaultFont was not found.')
    exit 1
}

. ([scriptblock]::Create($functionAst.Extent.Text))

$failed = $false

function Assert-Equal {
    param([string]$Label, $Expected, $Actual)
    if ($Expected -ne $Actual) {
        [Console]::Error.WriteLine("${Label}: expected [$Expected] but was [$Actual]")
        $script:failed = $true
    }
}

function Get-Face {
    param([string]$Json)
    $documentOptions = [System.Text.Json.JsonDocumentOptions]::new()
    $documentOptions.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
    $documentOptions.AllowTrailingCommas = $true
    $root = [System.Text.Json.Nodes.JsonNode]::Parse($Json, $null, $documentOptions)
    $root['profiles']['defaults']['font']['face'].GetValue[string]()
}

$unchanged = @'
// keep me
{
    "profiles": {
        "defaults": {
            "font": { "face": "CaskaydiaCove NF", "size": 12 }
        }
    }
}
'@
$same = Set-WindowsTerminalDefaultFont -Json $unchanged -Face 'CaskaydiaCove NF'
Assert-Equal -Label 'unchanged text' -Expected $unchanged -Actual $same

$resized = Set-WindowsTerminalDefaultFont -Json @'
{
    "profiles": {
        "defaults": {
            "font": { "size": 13 },
            "fontFace": "Cascadia Mono"
        },
        "list": [
            { "name": "pwsh", "font": { "face": "Other Font" } }
        ]
    }
}
'@ -Face 'CaskaydiaCove NF'
Assert-Equal -Label 'replaced face' -Expected 'CaskaydiaCove NF' -Actual (Get-Face $resized)
Assert-Equal -Label 'kept size' -Expected 13 -Actual ([System.Text.Json.Nodes.JsonNode]::Parse($resized)['profiles']['defaults']['font']['size'].GetValue[int]())
Assert-Equal -Label 'dropped fontFace' -Expected $null -Actual ([System.Text.Json.Nodes.JsonNode]::Parse($resized)['profiles']['defaults']['fontFace'])
Assert-Equal -Label 'kept profile font' -Expected 'Other Font' -Actual ([System.Text.Json.Nodes.JsonNode]::Parse($resized)['profiles']['list'][0]['font']['face'].GetValue[string]())

$wrapped = Set-WindowsTerminalDefaultFont -Json '{"profiles":[{"name":"cmd"}]}' -Face 'CaskaydiaCove NF'
Assert-Equal -Label 'wrapped face' -Expected 'CaskaydiaCove NF' -Actual (Get-Face $wrapped)
Assert-Equal -Label 'wrapped list' -Expected 'cmd' -Actual ([System.Text.Json.Nodes.JsonNode]::Parse($wrapped)['profiles']['list'][0]['name'].GetValue[string]())

$commented = Set-WindowsTerminalDefaultFont -Json "// header`n{ `"profiles`": { `"defaults`": { } } }" -Face 'CaskaydiaCove NF'
if (-not $commented.StartsWith("// header`n")) {
    [Console]::Error.WriteLine('leading comment was dropped')
    $failed = $true
}
Assert-Equal -Label 'commented face' -Expected 'CaskaydiaCove NF' -Actual (Get-Face $commented)

if ($failed) {
    exit 1
}
