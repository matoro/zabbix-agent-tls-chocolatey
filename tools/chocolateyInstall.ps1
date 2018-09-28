$version        = '3.4.11'
$id             = 'zabbix-agent'
$title          = 'Zabbix Agent'
$url            = "https://support.zabbix.com/secure/attachment/62526/zabbix-$version-openssl1.1.0h-win32.zip"
$url64          = "https://support.zabbix.com/secure/attachment/62525/zabbix-$version-openssl1.1.0h-win64.zip"
$checksum       = "ab880f1ab3eddda6c7fbf19dd188a080"
$checksumType   = "md5"
$checksum64     = "48ebd868443d51c0c709888001f3a15a"
$checksumType64 = $checksumType

$is64bit = (Get-WmiObject -Class Win32_OperatingSystem | Select-Object OSArchitecture) -match '64'

$service = Get-WmiObject -Class Win32_Service -Filter "Name=`'$title`'"

$configDir    = Join-Path $env:PROGRAMDATA 'zabbix'
$zabbixConf   = Join-Path $configDir 'zabbix_agentd.conf'

$installDir   = Join-Path $env:PROGRAMFILES $title
$installDirHeaders  = Join-Path $installDir 'dev'
$zabbixAgentd = Join-Path $installDir 'zabbix_agentd.exe'

$tempDir      = Join-Path $env:TEMP 'chocolatey\zabbix'

if ($is64bit) {
  $zipFile      = Join-Path $tempDir "zabbix-$version-openssl1.1.0h-win64.zip"
} else {
  $zipFile      = Join-Path $tempDir "zabbix-$version-openssl1.1.0h-win32.zip"
}
$sampleConfig = Join-Path $tempDir 'conf\zabbix_agentd.win.conf'
$binFiles     = @('zabbix_agentd.exe', 'zabbix_get.exe', 'zabbix_sender.exe', 
 'libcrypto-1_1-x64.dll', 'libssl-1_1-x64.dll', 'msvcr120.dll')
$headerFiles  = @('zabbix_sender.dll', 'zabbix_sender.h', 'zabbix_sender.lib')

try {
  if ($service) {
    $service.StopService()
  }

  if (!(Test-Path $configDir)) {
    New-Item $configDir -type directory
  }

  if (!(Test-Path $installDir)) {
    New-Item $installDir -type directory
  }

  if (!(Test-Path $tempDir)) {
    New-Item $tempDir -type directory
  }

  Get-ChocolateyWebFile -PackageName "$id" -FileFullPath "$zipFile" -Url "$url" -Url64bit "$url64" -Checksum "$checksum" -ChecksumType "$checksumType" -Checksum64 "$checksum64" -ChecksumType64 "$checksumType64"
  Get-ChocolateyUnzip "$zipFile" "$tempDir"

  if ($is64bit) {
    $binDir = Join-Path $tempDir 'win64'
    $headerDir = Join-Path $tempDir 'win64\dev'
  } else {
    $binDir = Join-Path $tempDir 'win32'
    $headerDir = Join-Path $tempDir 'win32\dev'
  }

  foreach ($executable in $binFiles ) {
    $file = Join-Path $binDir $executable
    Move-Item $file $installDir -Force
  }
  foreach ($header in $headerFiles ) {
    $file = Join-Path $headerDir $header
    Move-Item $file $installDirHeaders -Force
  }

  if (Test-Path "$installDir\zabbix_agentd.conf") {
    if ($service) {
      $service.Delete()
      Clear-Variable -Name $service
    }

    Move-Item "$installDir\zabbix_agentd.conf" "$configDir\zabbix_agentd.conf" -Force

  } elseif (Test-Path "$configDir\zabbix_agentd.conf") {
    $configFile = "$configDir\zabbix_agentd-$version.conf"
    Move-Item $sampleConfig $configFile -Force

  } else {
    $configFile = "$configDir\zabbix_agentd.conf"
    Move-Item $sampleConfig $configFile

  }

  if (!($service)) {
    Start-ChocolateyProcessAsAdmin "--config `"$zabbixConf`" --install" "$zabbixAgentd"
  }

  Start-Service -Name $title

  Install-ChocolateyPath $installDir 'Machine'

} catch {
  Write-Host "Error installing Zabbix Agent"
  throw $_.Exception
}
