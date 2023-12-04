Import-Module (Join-Path $PSScriptRoot -ChildPath "html.psm1") -DisableNameChecking
 
if (!($IsWindows -Or $IsLinux -Or $IsMacOS)) {
    Write-Host ("Invalid platform: " + $PSVersionTable.Platfor)
    exit 1
}

$newVersion = $env:NEW_VERSION
$versionInfo = $env:VERSIONS_INFO | ConvertFrom-Json

$tmpFolderLocation = [IO.Path]::GetTempPath()
$workFolderLocation = Join-Path $env:RUNNER_TEMP "binaries"
$artifactFolderLocation = Join-Path ($PSCommandPath | Split-Path -Parent | Split-Path -Parent) "artifact"

function RemoveFiles() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Path
    )
    if (Test-Path $Path) {
        Write-Debug "Delete Path ${Path} inner files"
        Get-ChildItem -Path $Path -Recurse | ForEach-Object { $_.Delete() }
    }
}

if ($newVersion -contains $versionInfo.version) {
    $url = "https://www.virtualhere.com/node/955"
    $changeLogHtml = Invoke-WebRequest $url -MaximumRetryCount 3 -RetryIntervalSec 60 -Headers @{"Cache-Control" = "no-cache" }
    
    $m = "$changeLogHtml" | Select-String -Pattern ("\<p\>(?<ChangeLog>" + [regex]::Escape($newVersion) + "\s\(.+?\).+?)\<\/p\>")

    if (!$m.Matches.Success -Or $m.Matches[0].Groups["ChangeLog"].Value -eq '') {
        Write-Host "ChangeLog Not Found!"
        exit 1
    }

    $changeLog = ConvertFrom-Html -Html $m.Matches[0].Groups["ChangeLog"].Value
    Write-Debug "ChangeLog`n${changeLog}"

    if (!(Test-Path $artifactFolderLocation)) {
        mkdir $artifactFolderLocation
    }
    RemoveFiles -Path $artifactFolderLocation

    $versionInfo.download_info | ForEach-Object {
        if (!(Test-Path $workFolderLocation)) {
            mkdir $workFolderLocation
        }
        
        RemoveFiles -Path $workFolderLocation

        $fileName = $_.filename
        $tempFilePath = Join-Path -Path $tmpFolderLocation -ChildPath $fileName
        if (Test-Path -Path $tempFilePath -PathType Leaf) {
            Remove-Item $tempFilePath
        }

        $binariesUri = $_.download_url
        Write-Debug "Download binaries from $binariesUri to $tempFilePath"
        try {
            [System.Net.WebClient]::new().DownloadFile($binariesUri, $tempFilePath)
        }
        catch {
            Write-Host "Error during downloading file from '$binariesUri'"
            exit 1
        }

        $webHash = $_.sha1sum
        $hash = (Get-FileHash -Path $tempFilePath -Algorithm SHA1).Hash

        if ("$webHash" -ne $hash) {
            Write-Host "Vaildate failed hash '$fileName' $hash != $webHash!"
            exit 1
        }

        $outfutExt = ""
        $outputArtifactExt += ""
        if ($_.platform -match 'win32') {
            $outfutExt = ".exe"
            $outputArtifactExt = ".7z"
        }
        elseif (($_.platform -match 'linux') -or ($_.platform -match 'darwin')) {
            $outputArtifactExt = ".tar.xz"
        }

        $outputBinaryName = "virtualhere-client{0}" -f $outfutExt
        $outputArtifactName = "virtualhere-client-{0}-{1}-{2}{3}" -f $versionInfo.version, $_.platform, $_.arch, $outputArtifactExt

        $workFilePath = Join-Path -Path $workFolderLocation -ChildPath $outputBinaryName

        Move-Item -Path $tempFilePath -Destination $workFilePath -Confirm:$False -Force

        $outputPath = Join-Path -Path $artifactFolderLocation -ChildPath $outputArtifactName

        if ($_.platform -match 'win32') {
            $arguments = @(
                "-t7z", "-mx=5"
            )
            Push-Location $workFolderLocation
            Write-Debug "7z a $arguments $outputPath @$workFolderLocation"
            7z a $arguments $outputPath * | Out-Null
            Pop-Location
        }
        elseif (($_.platform -match 'linux') -or ($_.platform -match 'darwin')) {
            $arguments = @(
                "-c", "--xz", "-f", $outputPath, "."
            )
            Push-Location $workFolderLocation
            Write-Debug "tar $arguments"
            tar @arguments | Out-Null
            Pop-Location
        }
    }
    
    Push-Location $artifactFolderLocation
    $childItems = Get-Childitem -Path '.'
    $childItems | Foreach-Object {
        $packageObj = Get-Childitem -Path $_.FullName | Select-Object -First 1
        Write-Debug "Package: $($packageObj.Name)"
        $actualHash = (Get-FileHash -Path $packageObj.FullName -Algorithm sha256).Hash
        $hashString = "$actualHash $($packageObj.Name)"
        Write-Debug "$hashString"
        Add-Content -Path ./hashes.sha256 -Value "$hashString"
    }
    Pop-Location

    $EOF = -join (1..15 | ForEach-Object { [char]((48..57) + (65..90) + (97..122) | Get-Random) })
    "CHANGE_LOG<<$EOF" >> $env:GITHUB_OUTPUT
    $changeLog >> $env:GITHUB_OUTPUT
    "$EOF" >> $env:GITHUB_OUTPUT
}
else {
    Write-Host "Not Download able Versions!"
    exit 1
}