# profile.ps1: loaded by every PowerShell 7 host (console, VS Code).

# The block below returns init scripts that must be dot-sourced at global
# scope: completion scripts reference helper functions that would vanish with
# a child scope.
$__profileInitFiles = & {
    # -------------------------------------------------------------------------
    # 1. Environment & host introspection (fast-exit gate)
    # -------------------------------------------------------------------------
    function Test-ProfileRunsScript {
        param([string[]]$CommandLine)

        $switchNames = 'Command', 'File', 'EncodedCommand', 'NonInteractive'
        foreach ($argument in $CommandLine) {
            if ($argument -notmatch '^-(.+)$') {
                continue
            }

            $body = $Matches[1]
            $hits = @($switchNames | Where-Object { $_.StartsWith($body, [System.StringComparison]::OrdinalIgnoreCase) })
            if ($hits.Count -eq 1) {
                return $true
            }
        }

        $false
    }

    $commandLine = [Environment]::GetCommandLineArgs()
    $keepsShellOpen = [bool]($commandLine -match '^-noe')
    $runsScript = Test-ProfileRunsScript -CommandLine $commandLine

    $isInteractive = [Environment]::UserInteractive -and
        (-not [Console]::IsInputRedirected) -and
        (-not [Console]::IsOutputRedirected) -and
        ($Host.Name -in 'ConsoleHost', 'Visual Studio Code Host') -and
        ($keepsShellOpen -or -not $runsScript)

    # AI agent shells: Cursor, Claude Code, and agents that set AI_AGENT.
    $isAgentSession = [bool]($env:CURSOR_AGENT -or $env:CLAUDECODE -or $env:AI_AGENT -or $env:ACP_AGENT)

    $env:RIPGREP_CONFIG_PATH = Join-Path $env:USERPROFILE '.config\ripgrep\config'
    $env:YAZI_CONFIG_HOME = Join-Path $env:USERPROFILE '.config\yazi'

    # -------------------------------------------------------------------------
    # 2. UTF-8 console encoding (pwsh 7 already defaults $OutputEncoding)
    # -------------------------------------------------------------------------
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

    if (-not [Console]::IsOutputRedirected) {
        [Console]::OutputEncoding = $utf8NoBom
    }

    if (-not [Console]::IsInputRedirected) {
        [Console]::InputEncoding = $utf8NoBom
    }

    # Fast exit: skip UI, prompt hooks, and heavy tools in non-interactive
    # sessions or agent tasks. Starship is not loaded here, so neither is the
    # transient prompt.
    if (-not $isInteractive -or $isAgentSession) {
        return
    }

    # -------------------------------------------------------------------------
    # 3. Interactive shell enhancements (Windows Terminal, Cursor, Zed)
    # -------------------------------------------------------------------------

    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -ContinuationPrompt '  '

    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord

    # -------------------------------------------------------------------------
    # 4. Disk-cached init scripts (Starship, Zoxide)
    # -------------------------------------------------------------------------
    $initCacheDir = Join-Path $env:LOCALAPPDATA 'PowerShell\InitCache'
    $initFiles = [System.Collections.Generic.List[string]]::new()

    # Scoop shims never change on upgrade; stamp the real executable instead.
    function Resolve-ToolPath {
        param([string]$Path)

        $shim = [System.IO.Path]::ChangeExtension($Path, '.shim')
        if (Test-Path -LiteralPath $shim) {
            $line = Get-Content -LiteralPath $shim | Where-Object { $_ -match '^\s*path\s*=' } | Select-Object -First 1
            if ($line) {
                return ($line -replace '^\s*path\s*=\s*', '').Trim('"', ' ')
            }
        }

        $item = Get-Item -LiteralPath $Path
        if ($item.LinkTarget) {
            return $item.ResolvedTarget
        }
        $Path
    }

    function Add-CachedInit {
        param(
            [string]$ToolName,
            [scriptblock]$Generator
        )

        $exe = Get-Command -Name $ToolName -CommandType Application -ErrorAction Stop |
            Select-Object -First 1

        $real = Get-Item -LiteralPath (Resolve-ToolPath $exe.Source) -ErrorAction SilentlyContinue
        $profileTicks = (Get-Item -LiteralPath $PSCommandPath).LastWriteTimeUtc.Ticks
        $stamp = if ($real) { '{0}-{1}-{2}' -f $real.Length, $real.LastWriteTimeUtc.Ticks, $profileTicks } else { "unknown-$profileTicks" }
        $cacheFile = Join-Path $initCacheDir "$ToolName-$stamp.ps1"

        if (-not (Test-Path -LiteralPath $cacheFile)) {
            $null = New-Item -ItemType Directory -Path $initCacheDir -Force
            Get-ChildItem -LiteralPath $initCacheDir -Filter "$ToolName-*.ps1" -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue

            $content = & $Generator
            if ($content) {
                [System.IO.File]::WriteAllText($cacheFile, $content, [System.Text.Encoding]::UTF8)
            }
        }

        if (Test-Path -LiteralPath $cacheFile) {
            $initFiles.Add($cacheFile)
        }
    }

    function global:Invoke-Starship-TransientFunction {
        $clearBelow = "$([char]0x1b)[0J"

        if ($global:LASTEXITCODE -eq 0) {
            "$clearBelow$($PSStyle.Bold)$($PSStyle.Foreground.Green)❯$($PSStyle.Reset) "
        }
        else {
            "$clearBelow$($PSStyle.Bold)$($PSStyle.Foreground.BrightRed)❯$($PSStyle.Reset) "
        }
    }

    Add-CachedInit -ToolName 'starship' -Generator {
        & starship init powershell --print-full-init | Out-String
    }

    # Zoxide last: it hooks the prompt that Starship defines.
    Add-CachedInit -ToolName 'zoxide' -Generator {
        & zoxide init powershell | Out-String
    }

    # Yazi cannot Set-Location the parent. `y` cds after quit so zoxide records it.
    # `q` keeps the dir; `Q` leaves $PWD unchanged.
    function global:y {
        param([Parameter(ValueFromRemainingArguments)][string[]]$YaziArgs)

        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            & yazi @YaziArgs --cwd-file=$tmp
            if (-not (Test-Path -LiteralPath $tmp)) {
                return
            }

            $cwd = ([System.IO.File]::ReadAllText($tmp) -split ([char]0), 2)[0].Trim()
            if ($cwd -and (Test-Path -LiteralPath $cwd) -and $cwd -ne $PWD.Path) {
                Set-Location -LiteralPath $cwd
            }
        }
        finally {
            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
        }
    }

    # -------------------------------------------------------------------------
    # 5. winget and scoop tab completion
    # -------------------------------------------------------------------------
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $word = $wordToComplete.Replace('"', '""')
        $ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$word" --commandline "$ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }

    $scoopCmd = Get-Command -Name scoop -CommandType Application -ErrorAction Stop
    $scoopRoot = (Get-Item -LiteralPath $scoopCmd.Source).Directory.Parent.FullName
    Import-Module (Join-Path $scoopRoot 'modules\scoop-completion') -Global

    $script:ChezmoiEnableTransientPrompt = $true
    $initFiles
}

foreach ($__initFile in $__profileInitFiles) {
    . $__initFile
}
Remove-Variable -Name __profileInitFiles, __initFile -ErrorAction SilentlyContinue

if ($ChezmoiEnableTransientPrompt) {
    Enable-TransientPrompt
}
Remove-Variable -Name ChezmoiEnableTransientPrompt -ErrorAction SilentlyContinue
