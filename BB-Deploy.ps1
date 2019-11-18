<#
=============       Deploy Bluebeam to a Remote Computer      ==================

Based on Bluebeam® Revu® Deployment Guide – Version 2018.x
https://support.bluebeam.com/articles/bluebeam-revu-deployment-guide-version-2018-0/

Auther: David Wang
June 2019

Usage: Usage: .\Deploy.ps1 [-C TARGET] -E STD|CAD|EXT [-T Y|N] [-S SOURCEPATH]
Bluebeam Editions:
STD = Standard
CAD = AutoCAD
EXT = eXtreme

How to run this script on your own computer:
1.Open powershell.exe (the command line version) as an user who has local admin right on the target computer
2.Set BBRD folder as your current directly
3.Run .\Deploy.ps1 [-C TARGET] -E STD|CAD|EXT [-T Y|N] [-S SOURCEPATH]

If -T is missing, a licensed version will be installed.
If -S is missing, the current directory will be used for source files.

Switch detail:
-C : Target Computer Name, LOCALHOST by default
-E : Bluebeam Edition (STD | CAD | EXT) (This is the only mandatory switch)
-T : Install Trial Version (Y | N), N by default
-S : Source files path, default to the current directory

CAUTION:
1. Please start Powershell/ISE program with your domain admin account
2. If you get this error message:
   Deploy.ps1 cannot be loaded. The file Deploy.ps1 is not digitally signed. You cannot run this script on the current system.
   Please run this command: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -force
#>

param(
    [Parameter(ParameterSetName='Arg')]
    [string] $C, # Target computer name
    [string] $E, # Bluebeam edition: STD, CAD, EXT
    [string] $T, # Trial version Y/N
    [string] $S  # The folder which contains all installation files
)

# Please keep confidential for the following license information
# Please direct questions about all license keys to Brian Joncas
set-variable SN_STD -value "1234567" -option Constant          # Serial Number (Standard)
set-variable PK_STD -value "12345-1234567" -option Constant    # Product Key (Standard)
set-variable SN_CAD -value "1234567" -option Constant          # Serial Number (CAD)
set-variable PK_CAD -value "12345-1234567" -option Constant    # Product Key (CAD)
set-variable SN_EXT -value "1234567" -option Constant          # Serial Number (eXtreme)
set-variable PK_EXT -value "12345-1234567" -option Constant    # Product Key (eXtreme)

[string] $Target     = ""
[string] $sPath      = ""
[string] $fPath      = ""
[string] $tPath      = "C:\BBRD" # Temporary path on the target machine
[string] $Edition    = ""
[string] $SN         = ""
[string] $PK         = ""

Write-Host -ForegroundColor Green "╔═════════════════════════════════════════════════════════════════════════════════════╗"
Write-Host -ForegroundColor Green "║                           Bluebeam Remote Deployment Tool                           ║"
Write-Host -ForegroundColor Green "╠═════════════════════════════════════════════════════════════════════════════════════╣"
Write-Host -ForegroundColor Green "║Based on Bluebeam Revu Deployment Guide – Version 2018.x                             ║"
Write-Host -ForegroundColor Green "║https://support.bluebeam.com/articles/bluebeam-revu-deployment-guide-version-2018-0/ ║"
Write-Host -ForegroundColor Green "╠═════════════════════════════════════════════════════════════════════════════════════╣"
Write-Host -ForegroundColor Green -NoNewline "║"
Write-Host -ForegroundColor Cyan -NoNewline "         Please report the bugs to developer@mecro.ca                                "
Write-Host -ForegroundColor Green "║"
Write-Host -ForegroundColor Green "╚═════════════════════════════════════════════════════════════════════════════════════╝"

if (!$E) {
    Write-Host -ForegroundColor Yellow "╔═════════════════════════════════════════════════════════════════════════════════════╗"
    Write-Host -ForegroundColor Yellow "║    Bluebeam Edition missing...                                                      ║"
    Write-Host -ForegroundColor Yellow "║    Usage: .\Deploy.ps1 [-C TARGET] -E STD|CAD|EXT [-T Y|N] [-S SOURCEPATH]          ║"
    Write-Host -ForegroundColor Yellow "╚═════════════════════════════════════════════════════════════════════════════════════╝"
    exit
}

if (!$C) {
    $Target = $env:COMPUTERNAME
    Write-Host -ForegroundColor Yellow -NoNewline "  Target computer : "
    Write-Host -ForegroundColor Cyan "localhost ($Target)"
} else {
    $Target = $C
    Write-Host -ForegroundColor Yellow -NoNewline "  Target computer : "
    Write-Host -ForegroundColor Cyan "$Target"
}

# Check if the target is alive
if(!(Test-Connection -Computername $Target -BufferSize 16 -Count 1 -Quiet)) {
    Write-Host -ForegroundColor Red "The remote computer $Target is not online."
    exit
}

if ($E -cin "STD","CAD","EXT") {
    switch($E) {
        "STD" { $SN = $SN_STD;
                $PK = $PK_STD;
                $Edition = "0"
              }
        "CAD" { $SN = $SN_CAD;
                $PK = $PK_CAD;
                $Edition = "1"
              }
        "EXT" { $SN = $SN_EXT;
                $PK = $PK_EXT;
                $Edition = "2"
              }
}
} else {
    Write-Host -ForegroundColor Yellow "╔═════════════════════════════════════════════════════════════════════════════════════╗"
    Write-Host -ForegroundColor Yellow "║    Wrong Bluebeam Edition...                                                        ║"
    Write-Host -ForegroundColor Yellow "║    Edition example: (Case Sensitive)                                                ║"
    Write-Host -ForegroundColor Yellow "║                     STD = Standard                                                  ║"
    Write-Host -ForegroundColor Yellow "║                     CAD = AutoCAD                                                   ║"
    Write-Host -ForegroundColor Yellow "║                     EXT = eXtreme                                                   ║"
    Write-Host -ForegroundColor Yellow "║    Usage: .\Deploy.ps1 [-C TARGET] -E STD|CAD|EXT [-T Y|N] [-U Y|N] [-S SOURCEPATH] ║"
    Write-Host -ForegroundColor Yellow "╚═════════════════════════════════════════════════════════════════════════════════════╝"
    exit
}

# Trail version
if ($T -eq "Y") {
    Write-Host -ForegroundColor Yellow -NoNewline "  License type : "
    Write-Host -ForegroundColor Cyan "30-day trial"
    $SN = ""
    $PK = ""
} else {
    Write-Host -ForegroundColor Yellow -NoNewline "  License type : "
    Write-Host -ForegroundColor Cyan "Bluebeam $E license"
}

# Build the source folder
if (!$S) {
    Write-Host -ForegroundColor Yellow -NoNewline "  Source files will be in the current directory : "
    Write-Host -ForegroundColor Cyan (Get-Item -Path ".\").FullName
    $sPath = (Get-Item -Path ".\").FullName + "\"
} else
{
    Write-Host -ForegroundColor Yellow -NoNewline "  Source files will be in this directory : "
    Write-Host -ForegroundColor Cyan $S
    $sPath = $S + "\"
}

Write-Host -ForegroundColor Green "═══════════════════════════════════════════════════════════════════════════════════════"

# Start WinRM service on the target if not started
$service='NoService'
Write-Host -ForegroundColor Cyan -NoNewline "  Checking Windows Remote Management Service ... "
$services=Get-Service -Name WinRM -ComputerName $Target | Start-service 2>&1 | out-null
if($?){
    Write-Host -ForegroundColor Green -NoNewline "Ok"
}else{
    Write-Host -ForegroundColor Red "Failed"
    write-host "The target is not a Windows machine!" -ForegroundColor Red
    exit
}
$services=Get-Service -Name WinRM -ComputerName $Target | Set-Service -Status Running 2>&1 | out-null
if($?){
    Write-Host -ForegroundColor Green "  Ok"
}else{
    Write-Host -ForegroundColor Red "Failed"
    write-host "The target is not a Windows machine!" -ForegroundColor Red
    exit
}

# Create temp directory and establish a connection with the target
invoke-command -computer $Target {
    New-Item -Path C:\BBRD -type directory -Force | Out-Null
}
$Session = New-PSSession -ComputerName $Target
Copy-Item -Path $sPath\Uninstall_Previous_Versions.bat -Destination $tPath -ToSession $session

# Uninstall previous version of Bluebeam
write-host -ForegroundColor Cyan  -NoNewline "  Uninstalling previous version of Bluebeam ... "

invoke-command -Session $session {
    Start-Process "cmd.exe"  "/c $Using:tPath\Uninstall_Previous_Versions.bat"  -Wait
}

write-host -ForegroundColor Green "Done"

# Copy all files over
write-host -ForegroundColor Cyan  -NoNewline "  Copy deployment files to the target ... "

$fPath = $sPath + "Bluebeam_Revu_x64_18.msi"
Copy-Item -Path $fPath -Destination $tPath -ToSession $session

$fPath = $sPath + "ARP_Modifier_v1850.exe"
Copy-Item -Path $fPath -Destination $tPath -ToSession $session

$fPath = $sPath + "NDP461-KB3102436-x86-x64-AllOS-ENU.exe"
Copy-Item -Path $fPath -Destination $tPath -ToSession $session

$fPath = $sPath + "vc_redist.x64.exe"
Copy-Item -Path $fPath -Destination $tPath -ToSession $session

write-host -ForegroundColor Green "Done"

# Install Prerequisites
write-host -ForegroundColor Cyan  -NoNewline "  Installing Prerequisites on the target ... "

invoke-command -Session $session {
    Start-Process "$Using:tPath\vc_redist.x64.exe" "/quiet" -Wait
}

invoke-command -Session $session {
    Start-Process "$Using:tPath\NDP461-KB3102436-x86-x64-AllOS-ENU.exe"  "/q" -Wait
}

write-host -ForegroundColor Green "Done"

# Install Bluebeam
write-host -ForegroundColor Cyan  -NoNewline "  Installing Bluebeam 2018 $E on the target ... "

invoke-command -Session $session {
    Start-Process "msiexec.exe" "/i $Using:tPath\Bluebeam_Revu_x64_18.msi BB_SERIALNUMBER=$Using:SN BB_PRODUCTKEY=$Using:PK BB_EDITION=$Using:Edition /qn" -Wait
}

invoke-command -Session $session {
    Start-Process "$Using:tPath\ARP_Modifier_v1850.exe" "$Using:Edition" -Wait
}

write-host -ForegroundColor Green "Done"

Write-Host -ForegroundColor Cyan  -NoNewline "  Removing the deployment packages on the target ... "

Invoke-Command -Session $session {
        Remove-Item "$Using:tPath"   -Recurse -Force | Out-Null
}

Disconnect-PSSession -Session $Session | out-null

write-host -ForegroundColor Green "Done"
Write-Host -ForegroundColor Green "╔════════════════════════════════════════════════════════════════════════════════════════════════════"
write-host -ForegroundColor Green "║   Bluebeam 2018 $E has been successfully deployed on the target computer: $Target"
Write-Host -ForegroundColor Green "╚════════════════════════════════════════════════════════════════════════════════════════════════════"
exit