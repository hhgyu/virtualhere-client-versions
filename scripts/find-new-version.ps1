
$url = "https://www.virtualhere.com/usb_client_software"
$html = Invoke-RestMethod $url -MaximumRetryCount 3 -RetryIntervalSec 60 -Headers @{"Cache-Control" = "no-cache" }

$url = "https://www.virtualhere.com/sites/default/files/usbclient/SHA1SUM"
$hashs = Invoke-RestMethod $url -MaximumRetryCount 3 -RetryIntervalSec 60 -Headers @{"Cache-Control" = "no-cache" }

$url = "https://raw.githubusercontent.com/hhgyu/virtualhere-client-versions/main/versions-manifest.json"
$releases = Invoke-RestMethod $url -MaximumRetryCount 3 -RetryIntervalSec 60 -Headers @{"Cache-Control" = "no-cache" }

$m = "$html" | Select-String -Pattern "Please click on a link below to download\: <strong>Version (?<Version>[.\d]+)</strong>"

$m_hashs = [regex]::new("^(?<SHA1SUM>.+?)\s+(?<FileName>.+?)$", [Text.RegularExpressions.RegexOptions]'Multiline,IgnoreCase').Matches("$hashs")

$versionJson = @"
{
    "version": null,
    "download_info": [] 
}
"@
$downInfoJson = @"
{
    "filename": null,
    "download_url": null,
    "platform": null,
    "arch": null,
    "sha1sum": null
}
"@
if ($m.Matches.Success -And $m_hashs.Count -gt 0) {
    $versionObject = $versionJson | ConvertFrom-Json

    $versionObject.version = $m.Matches[0].Groups["Version"].Value

    $client_prefix = "https://www.virtualhere.com/sites/default/files/usbclient/"
    $m_hashs | ForEach-Object {
        if ($_.Success) {
            if (($_.Groups["FileName"].Value.IndexOf("vhuit") -eq 0 -And $_.Groups["FileName"].Value.IndexOf(".exe") -eq -1) -Or 
                $_.Groups["FileName"].Value.IndexOf(".dmg") -ne -1) {
                # linux gui client and mac client skip
                return
            }

            $fileName = $_.Groups["FileName"].Value
            $downInfoObject = $downInfoJson | ConvertFrom-Json
            $downInfoObject.filename = $fileName
            $downInfoObject.sha1sum = $_.Groups["SHA1SUM"].Value
            $downInfoObject.download_url = $client_prefix + $fileName
            switch ($downInfoObject.filename) {
                "vhui64.exe" { 
                    $downInfoObject.platform = "win32"
                    $downInfoObject.arch = "x64"
                }
                "vhuiarm64.exe" { 
                    $downInfoObject.platform = "win32"
                    $downInfoObject.arch = "arm64"
                }
                "vhclientarmhf" { 
                    $downInfoObject.platform = "linux"
                    $downInfoObject.arch = "arm32"
                }
                "vhclienti386" { 
                    $downInfoObject.platform = "linux"
                    $downInfoObject.arch = "x86"
                }
                "vhclientmipsel" { 
                    $downInfoObject.platform = "linux"
                    $downInfoObject.arch = "mips32"
                }
                "vhclientmipsel64" { 
                    $downInfoObject.platform = "linux"
                    $downInfoObject.arch = "mips64"
                }
                "vhclientx86_64" { 
                    $downInfoObject.platform = "linux"
                    $downInfoObject.arch = "x64"
                }
                "vhclientarm64" { 
                    $downInfoObject.platform = "linux"
                    $downInfoObject.arch = "arm64"
                }
                Default {
                    Write-Host "New Client ${fileName}"
                    return
                }
            }

            $versionObject.download_info += $downInfoObject
        }
    }

    $VersionIsValid = & {
        try {
            [bool][version]$versionObject.version
        }
        catch {
            $false
        }
    }

    if (!$VersionIsValid) {
        throw [System.Exception]::new("Version Check Failed!")
    }

    if ($versionObject.download_info.Length -eq 0) {
        throw [System.Exception]::new("Not Found Version Data!")
    }

    $versionsFromDist = @($versionObject.version)
    $versionsFromManifest = $releases.version
    $versionsToBuild = $VersionsFromDist | Where-Object { $versionsFromManifest -notcontains $_ }
    
    if ($versionsToBuild) {
        $availableVersion = $versionsToBuild
        $versionObjectJson = ConvertTo-Json $versionObject -Compress
        Write-Host "The following versions are available to build:`n${availableVersion}"
        "NEW_VERSION=${availableVersion}" >> $env:GITHUB_OUTPUT
        "VERSIONS_INFO=${versionObjectJson}" >> $env:GITHUB_OUTPUT
    }
    else {
        Write-Host "There aren't versions to build"
    }
}
elseif ($m_hashs.Count -eq 0) {
    throw [System.Exception]::new("Not Found HASH Data")
}
else {
    throw [System.Exception]::new("Not Found Version String")
}