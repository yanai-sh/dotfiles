# profile.ps1: loaded by every PowerShell 7 host (console, VS Code).

# The block below returns init scripts that must be dot-sourced at global
# scope: completion scripts reference helper functions that would vanish with
# a child scope.
$__profileInitFiles = & {
    # -------------------------------------------------------------------------
    # 1. Environment & host introspection (fast-exit gate)
    # -------------------------------------------------------------------------
    $commandLine = [Environment]::GetCommandLineArgs()
    $keepsShellOpen = [bool]($commandLine -match '^-noe')
    $runsScript = [bool]($commandLine -match '^-(c|command|f|file|e|ec|encodedcommand|noni|noninteractive)$')

    $isInteractive = [Environment]::UserInteractive -and
        (-not [Console]::IsInputRedirected) -and
        (-not [Console]::IsOutputRedirected) -and
        ($Host.Name -in 'ConsoleHost', 'Visual Studio Code Host') -and
        ($keepsShellOpen -or -not $runsScript)

    # AI agent shells: Cursor, Claude Code, and agents that set AI_AGENT.
    $isAgentSession = [bool]($env:CURSOR_AGENT -or $env:CLAUDECODE -or $env:AI_AGENT -or $env:ACP_AGENT)

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

    $fnmExe = (Get-Command -Name fnm -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1).Source
    $fnmArgs = @('env', '--shell', 'powershell', '--version-file-strategy', 'recursive')

    # Fast exit: skip UI, prompt hooks, and heavy tools in non-interactive
    # sessions or agent tasks. Node stays on PATH for them.
    if (-not $isInteractive -or $isAgentSession) {
        if ($fnmExe) {
            & $fnmExe @fnmArgs | Out-String | Invoke-Expression
        }
        return
    }

    # -------------------------------------------------------------------------
    # 3. Interactive shell enhancements (Windows Terminal, Cursor, Zed)
    # -------------------------------------------------------------------------

    # PSReadLine: only non-default settings.
    if (Get-Command -Name Set-PSReadLineOption -ErrorAction SilentlyContinue) {
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
        Set-PSReadLineOption -BellStyle None
        Set-PSReadLineOption -ContinuationPrompt '  '
        Set-PSReadLineOption -Colors @{
            InlinePrediction = "$([char]0x1b)[38;5;242m"
        }

        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    }

    # -------------------------------------------------------------------------
    # 4. Disk-cached init scripts (Starship, Zoxide, gh, Docker)
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

        $exe = Get-Command -Name $ToolName -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $exe) {
            return
        }

        $real = Get-Item -LiteralPath (Resolve-ToolPath $exe.Source) -ErrorAction SilentlyContinue
        $stamp = if ($real) { '{0}-{1}' -f $real.Length, $real.LastWriteTimeUtc.Ticks } else { 'unknown' }
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

    # Starship transient prompt (\e[0J clears leftovers below the prompt).
    if (Get-Command -Name starship -ErrorAction SilentlyContinue) {
        function global:Invoke-Starship-TransientFunction {
            $clearBelow = "$([char]0x1b)[0J"

            if ($global:LASTEXITCODE -eq 0) {
                "$clearBelow$($PSStyle.Bold)$($PSStyle.Foreground.Green)❯$($PSStyle.Reset) "
            }
            else {
                "$clearBelow$($PSStyle.Bold)$($PSStyle.Foreground.BrightRed)❯$($PSStyle.Reset) "
            }
        }
    }

    Add-CachedInit -ToolName 'starship' -Generator {
        & starship init powershell --print-full-init | Out-String
    }

    Add-CachedInit -ToolName 'gh' -Generator {
        & gh completion -s powershell | Out-String
    }

    Add-CachedInit -ToolName 'docker' -Generator {
        & docker completion powershell | Out-String
    }

    # Zoxide last: it hooks the prompt that Starship defines.
    Add-CachedInit -ToolName 'zoxide' -Generator {
        & zoxide init powershell | Out-String
    }

    # -------------------------------------------------------------------------
    # 5. fnm & Node toolchain
    # -------------------------------------------------------------------------
    if ($fnmExe) {
        & $fnmExe @fnmArgs --use-on-cd | Out-String | Invoke-Expression
    }

    # -------------------------------------------------------------------------
    # 6. winget completion (https://learn.microsoft.com/windows/package-manager/winget/tab-completion)
    # -------------------------------------------------------------------------
    if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)

            [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
            $word = $wordToComplete.Replace('"', '""')
            $ast = $commandAst.ToString().Replace('"', '""')
            winget complete --word="$word" --commandline "$ast" --position $cursorPosition | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        }
    }

    $initFiles
}

foreach ($__initFile in $__profileInitFiles) {
    . $__initFile
}
Remove-Variable -Name __profileInitFiles, __initFile -ErrorAction SilentlyContinue

if (Get-Command -Name Enable-TransientPrompt -ErrorAction SilentlyContinue) {
    Enable-TransientPrompt
}
