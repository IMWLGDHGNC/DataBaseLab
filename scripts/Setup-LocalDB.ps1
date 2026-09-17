# Run manually in Windows PowerShell as Administrator.
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Open Windows PowerShell as Administrator, then run this script again.' }

$localDb = Join-Path $env:ProgramFiles 'Microsoft SQL Server\160\Tools\Binn\SqlLocalDB.exe'
if (-not (Test-Path -LiteralPath $localDb)) {
    $setupDir = Join-Path $env:LOCALAPPDATA 'DataBaseLab\setup'
    New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
    $installer = Join-Path $setupDir 'SqlLocalDB.msi'
    $log = Join-Path $setupDir 'localdb-install.log'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri 'https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SqlLocalDB.msi' -OutFile $installer
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        throw 'Installer must have a valid Microsoft signature.'
    }
    $installArgs = '/i "{0}" /qn /norestart IACCEPTSQLLOCALDBLICENSETERMS=YES /L*v "{1}"' -f $installer, $log
    $process = Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $installArgs -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -eq 3010) {
        Write-Host 'Installation succeeded. Restart Windows, then run scripts\Initialize-LocalDB.ps1 in a normal Windows PowerShell window.'
        return
    }
    if ($process.ExitCode -ne 0) { throw "Installation failed: $($process.ExitCode). See $log" }
}
Write-Host 'LocalDB installed. In a normal Windows PowerShell window, run scripts\Initialize-LocalDB.ps1.'
