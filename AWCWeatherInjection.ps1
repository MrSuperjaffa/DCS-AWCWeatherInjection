<#
    Author: Mr_Superjaffa#5430
    Description: Inject real world weather into DCS .miz file for use on servers.
    Version: v0.7.0
    Modified: 28DEC19
    Notes: N/A
#>

# Log Output "PARAM1" "MESSAGE" "LOGFILE"
Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($LogFile) {
        Add-Content $LogFile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

$workingdir = Split-Path $MyInvocation.MyCommand.Path -Parent
. "$workingdir\Functions\MissionExtraction.ps1"
. "$workingdir\Functions\MissionExport.ps1"
. "$workingdir\Functions\WeatherGeneration.ps1"
. "$workingdir\Functions\TimeConversion.ps1"
. "$workingdir\Functions\ArraySearch.ps1"

#$ErrorActionPreference = "Stop"
$Version = "v0.7.0"
[xml]$script:InjectionSettings = Get-Content "./WeatherInjectionSettings.xml"
$script:Log = $InjectionSettings.Settings.Setup.Log
$script:SavedGamesFolder = $InjectionSettings.Settings.Setup.SavedGamesFolder
$script:Mission = $InjectionSettings.Settings.Setup.Mission
$script:AirportICAO = $InjectionSettings.Settings.General.AirportICAO
$script:DEBUG = $InjectionSettings.Settings.General.DEBUG

Write-Log "INFO" "---------- Initializing AWCWeatherInjection $Version ----------" $Log

Try {
    If (!(Test-Path $Log) -and $Log){
        New-Item -Path $Log
        Write-Log "WARN" "Log not found. Creating log at @Log" $Log
    } Elseif (!(Test-Path $Log) -and !$Log) {
        New-Item -Path "./" -Name "WeatherInjection.log"
        Write-Log "WARN" "Log not found. Creating log at @Log" $Log
    }
} Catch {Write-Log "FATAL" "Log creation failed!" $Log}

#Conversion Constants
$FeetToMeters = 3.281
$KnotToMPS = 1.944
$inHGTommHg = 25.4
$NMtoFeet = 6076

# Exit if disabled. Nothing to do here.
If (!$InjectionSettings.Settings.Enabled -eq "False") {
    Write-Log "INFO" "Script Disabled. Exiting..." $Log
    Exit
} Else {
    Write-Log "INFO" "Script Enabled. Continuing..." $Log
}

FindMission
UnzipMiz($miz)
GetTDSWeather
GenerateWeather
MissionExport
ZipMiz($mizzip)

Write-Log "INFO" "Script complete. Exiting..." $Log
Exit