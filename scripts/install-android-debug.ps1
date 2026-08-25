[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $DeviceId,

    [switch] $SkipBuild,

    [switch] $VerifyOnly,

    [switch] $NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageName = 'com.example.kar_upahar'
$mainActivity = "$packageName/.MainActivity"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$apkPath = Join-Path $repositoryRoot 'build\app\outputs\flutter-apk\app-debug.apk'

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string[]] $Arguments,

        [switch] $CaptureOutput
    )

    if ($CaptureOutput) {
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $commandOutput = @(& $FilePath @Arguments 2>&1)
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($exitCode -ne 0) {
            $renderedOutput = ($commandOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
            throw "Command failed ($exitCode): $FilePath $($Arguments -join ' ')$([Environment]::NewLine)$renderedOutput"
        }
        return @($commandOutput | ForEach-Object { $_.ToString() })
    }

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $FilePath $($Arguments -join ' ')"
    }
}

function Find-Adb {
    $adbCommand = Get-Command 'adb' -ErrorAction SilentlyContinue
    if ($null -ne $adbCommand) {
        return $adbCommand.Source
    }

    $sdkRoots = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) {
        $sdkRoots.Add($env:ANDROID_SDK_ROOT)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
        $sdkRoots.Add($env:ANDROID_HOME)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $sdkRoots.Add((Join-Path $env:LOCALAPPDATA 'Android\sdk'))
    }

    foreach ($sdkRoot in $sdkRoots) {
        $candidate = Join-Path $sdkRoot 'platform-tools\adb.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw 'adb was not found. Install Android SDK Platform-Tools or set ANDROID_SDK_ROOT.'
}

function Find-AndroidBuildTools {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AdbPath
    )

    $platformToolsDirectory = Split-Path -Parent $AdbPath
    $sdkRoot = Split-Path -Parent $platformToolsDirectory
    $buildToolsRoot = Join-Path $sdkRoot 'build-tools'
    if (-not (Test-Path -LiteralPath $buildToolsRoot -PathType Container)) {
        throw "Android SDK Build-Tools were not found under $sdkRoot."
    }

    $directories = @(Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
        Sort-Object -Property Name -Descending)
    foreach ($directory in $directories) {
        $aaptPath = Join-Path $directory.FullName 'aapt.exe'
        $apksignerPath = Join-Path $directory.FullName 'apksigner.bat'
        if ((Test-Path -LiteralPath $aaptPath -PathType Leaf) -and
            (Test-Path -LiteralPath $apksignerPath -PathType Leaf)) {
            return [pscustomobject]@{
                Aapt      = $aaptPath
                ApkSigner = $apksignerPath
            }
        }
    }

    throw 'A matching aapt.exe and apksigner.bat installation was not found. Install Android SDK Build-Tools.'
}

function Get-ApkMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AaptPath,

        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $badging = (Invoke-CheckedCommand -FilePath $AaptPath -Arguments @(
            'dump',
            'badging',
            $Path
        ) -CaptureOutput) -join [Environment]::NewLine
    $packageMatch = [regex]::Match($badging, "package:\s+name='([^']+)'")
    $versionMatch = [regex]::Match($badging, "versionCode='([0-9]+)'")
    if (-not $packageMatch.Success -or -not $versionMatch.Success) {
        throw "Could not read package metadata from $Path."
    }

    return [pscustomobject]@{
        PackageName = $packageMatch.Groups[1].Value
        VersionCode = [long] $versionMatch.Groups[1].Value
    }
}

function Get-ApkCertificateDigest {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ApkSignerPath,

        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $certificateOutput = (Invoke-CheckedCommand -FilePath $ApkSignerPath -Arguments @(
            'verify',
            '--print-certs',
            $Path
        ) -CaptureOutput) -join [Environment]::NewLine
    $digestMatch = [regex]::Match(
        $certificateOutput,
        'Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]+)'
    )
    if (-not $digestMatch.Success) {
        throw "Could not read the signing certificate from $Path."
    }

    return $digestMatch.Groups[1].Value.ToLowerInvariant()
}

function Get-ConnectedDeviceId {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AdbPath,

        [string] $RequestedDeviceId
    )

    $deviceOutput = Invoke-CheckedCommand -FilePath $AdbPath -Arguments @(
        'devices',
        '-l'
    ) -CaptureOutput
    $connectedDevices = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $deviceOutput) {
        if ($line -match '^(\S+)\s+device(?:\s|$)') {
            $connectedDevices.Add($Matches[1])
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedDeviceId)) {
        if ($connectedDevices -notcontains $RequestedDeviceId) {
            throw "Device '$RequestedDeviceId' is not connected and authorized."
        }
        return $RequestedDeviceId
    }

    if ($connectedDevices.Count -eq 0) {
        throw 'No connected and authorized Android device was found.'
    }
    if ($connectedDevices.Count -gt 1) {
        throw "Multiple Android devices are connected. Pass -DeviceId with one of: $($connectedDevices -join ', ')"
    }

    return $connectedDevices[0]
}

function Get-InstalledPackagePaths {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AdbPath,

        [Parameter(Mandatory = $true)]
        [string] $TargetDeviceId,

        [Parameter(Mandatory = $true)]
        [string] $TargetPackageName
    )

    $packageOutput = @(
        & $AdbPath -s $TargetDeviceId shell pm path $TargetPackageName 2>$null |
            ForEach-Object { $_.ToString().Trim() }
    )
    return @($packageOutput | Where-Object { $_ -match '^package:' })
}

function Get-InstalledVersionCode {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AdbPath,

        [Parameter(Mandatory = $true)]
        [string] $TargetDeviceId,

        [Parameter(Mandatory = $true)]
        [string] $TargetPackageName
    )

    $packageDetails = (Invoke-CheckedCommand -FilePath $AdbPath -Arguments @(
            '-s',
            $TargetDeviceId,
            'shell',
            'dumpsys',
            'package',
            $TargetPackageName
        ) -CaptureOutput) -join [Environment]::NewLine
    $versionMatch = [regex]::Match($packageDetails, 'versionCode=([0-9]+)')
    if (-not $versionMatch.Success) {
        throw "Could not read the installed version code for $TargetPackageName."
    }
    return [long] $versionMatch.Groups[1].Value
}

function Get-InstalledCertificateDigest {
    param(
        [Parameter(Mandatory = $true)]
        [string] $AdbPath,

        [Parameter(Mandatory = $true)]
        [string] $ApkSignerPath,

        [Parameter(Mandatory = $true)]
        [string] $TargetDeviceId,

        [Parameter(Mandatory = $true)]
        [string[]] $PackagePaths
    )

    $basePackage = $PackagePaths |
        Where-Object { $_ -match '/base\.apk$' } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($basePackage)) {
        $basePackage = $PackagePaths | Select-Object -First 1
    }
    $remoteApkPath = $basePackage.Substring('package:'.Length)

    $temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $temporaryRoot = [IO.Path]::GetFullPath(
        (Join-Path $temporaryParent "kar-upahar-install-$([guid]::NewGuid().ToString('N'))")
    )
    $parentWithSeparator = $temporaryParent.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    if (-not $temporaryRoot.StartsWith(
            $parentWithSeparator,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Refusing to create a temporary installer directory outside the system temporary directory.'
    }

    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    try {
        $localApkPath = Join-Path $temporaryRoot 'installed-base.apk'
        Invoke-CheckedCommand -FilePath $AdbPath -Arguments @(
            '-s',
            $TargetDeviceId,
            'pull',
            $remoteApkPath,
            $localApkPath
        ) -CaptureOutput | Out-Null
        return Get-ApkCertificateDigest -ApkSignerPath $ApkSignerPath -Path $localApkPath
    }
    finally {
        if ((Test-Path -LiteralPath $temporaryRoot) -and
            $temporaryRoot.StartsWith(
                $parentWithSeparator,
                [StringComparison]::OrdinalIgnoreCase
            )) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

$adbPath = Find-Adb
$buildTools = Find-AndroidBuildTools -AdbPath $adbPath
$targetDeviceId = Get-ConnectedDeviceId -AdbPath $adbPath -RequestedDeviceId $DeviceId

if (-not $SkipBuild) {
    if ($null -eq (Get-Command 'flutter' -ErrorAction SilentlyContinue)) {
        throw 'flutter was not found on PATH.'
    }
    Push-Location $repositoryRoot
    try {
        Invoke-CheckedCommand -FilePath 'flutter' -Arguments @(
            'build',
            'apk',
            '--debug'
        )
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    throw "Debug APK not found at $apkPath. Build it first or omit -SkipBuild."
}

$apkMetadata = Get-ApkMetadata -AaptPath $buildTools.Aapt -Path $apkPath
if ($apkMetadata.PackageName -ne $packageName) {
    throw "Refusing installation: APK package '$($apkMetadata.PackageName)' does not match '$packageName'."
}
$newCertificateDigest = Get-ApkCertificateDigest -ApkSignerPath $buildTools.ApkSigner -Path $apkPath

$installedPackagePaths = @(
    Get-InstalledPackagePaths -AdbPath $adbPath -TargetDeviceId $targetDeviceId -TargetPackageName $packageName
)

if ($installedPackagePaths.Count -gt 0) {
    $installedVersionCode = Get-InstalledVersionCode -AdbPath $adbPath -TargetDeviceId $targetDeviceId -TargetPackageName $packageName
    if ($apkMetadata.VersionCode -lt $installedVersionCode) {
        throw "Refusing downgrade from version code $installedVersionCode to $($apkMetadata.VersionCode). Increase the version in pubspec.yaml; do not uninstall the app."
    }

    $installedCertificateDigest = Get-InstalledCertificateDigest -AdbPath $adbPath -ApkSignerPath $buildTools.ApkSigner -TargetDeviceId $targetDeviceId -PackagePaths $installedPackagePaths
    if (-not [string]::Equals(
            $newCertificateDigest,
            $installedCertificateDigest,
            [StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Refusing installation: the APK signing certificate does not match the installed app. Use the original signing key; do not uninstall the app.'
    }

    Write-Host "Safe update verified for $packageName on $targetDeviceId."
}
else {
    Write-Host "$packageName is not currently installed on $targetDeviceId; this will be a first install."
}

if ($VerifyOnly) {
    Write-Host 'Verification complete. No installation was performed.'
    exit 0
}

Write-Host 'Installing with adb install -r (in-place update; app data retained)...'
$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $installOutput = @(& $adbPath -s $targetDeviceId install -r $apkPath 2>&1)
    $installExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
$installOutput | ForEach-Object { Write-Host $_.ToString() }
if ($installExitCode -ne 0) {
    throw 'The in-place update failed. The existing app was not intentionally removed. Stop and diagnose the error; do not uninstall or clear app data.'
}
$postInstallPackagePaths = @(
    Get-InstalledPackagePaths -AdbPath $adbPath -TargetDeviceId $targetDeviceId -TargetPackageName $packageName
)
if ($postInstallPackagePaths.Count -eq 0) {
    throw 'Installation reported success, but the package could not be verified on the device.'
}

if (-not $NoLaunch) {
    Invoke-CheckedCommand -FilePath $adbPath -Arguments @(
        '-s',
        $targetDeviceId,
        'shell',
        'am',
        'start',
        '-n',
        $mainActivity
    )
}

Write-Host 'Safe Android update completed successfully.'
