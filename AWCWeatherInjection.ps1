<#
    Author: Mr_Superjaffa#5430
    Description: Inject real world weather into DCS .miz file for use on servers.
    Version: v0.5
    Modified: May 25th/2019
    Notes: Weather Calculation: Finished
           Mission Extraction/Recompression: WIP, Working
           Time Functions: Non-Existent
           User Weather: Non-Existent

    TODO:
        ***Create log if not found.
        Set cloud height to be that of the thickest layer.
        Check against user constraints. <-- Basics done.
        Rewrite Fog/Visibility calculations.
        Rewrite Turbulence calculations.

#>

<# 
    -==Min/Max Weather Contraints (Tested on Caucasus)==-
    
    ==Temperature==
    Dec-Feb: -12.4C - 10.4C
    March-May: -3.1C - 23.2C
    June - August: 8.4C - 50C
    Sept - Nov: -6.6C - 26.5C

    Mission Editor: Celcius C
    Miz File: Celcius C

    ==Precipitation==
    TempC > 0 {
        <5: None
        >5: Rain
        >=9: Rain, Thunderstorm
    }
    TempC < 0 {
        <5: None
        >5: Snow
        >=9: Snow, Snowstorm
    }

    None: 0
    Rain: 1
    Thunderstorm: 2
    Snow: 3
    Snowstorm: 4

    ==Clouds==
    Min Cloud Base: 984FT
    Max Cloud Base: 16404FT
    Min Cloud Thickness: 656FT
    Max Cloud Thickness: 6562FT
    Cloud Density: 0 - 8 Broken, 9-10 Overcast
    Max Density Before Gross Fog: 8

    ==Pressure==
    Min Pressure: 28.35InHG
    Max Pressure: 31.09InHG

    Mission Editor: Inches of Mercury InHG
    Miz File: Millimeters of Mercury mmHG

    ==Winds==
    Max 33FT: 97KTS
    Max 1600FT: 206KTS
    Max 6600FT: 97KTS
    Max 26000FT: 97KTS

    Mission Editor: Knots KTS | Winds TO
    Miz File: Metres Per Second M/S | Winds TO

    ==Turbulence==
    Max: 197

    Formula: 0.1 x NumFPS?

    Mission Editor: Feet Per Second
    Miz File: Metres Per Second

    ==Fog==
    Min Visibility: 82FT
    Max Visibility: 19685FT
    Min Thickness: 0FT
    Max Thickness: 3281FT

    Mission Editor: Feet FT
    Miz File: Meters M

    ==Dust Smoke==
    Min Visibility: 984FT
    Max Visibility: 9843FT

    Mission Editor: Feet FT
    Miz File: Meters M

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

<#
    Input: Any string.
    Output: Location of first found matching string in an array of text.
    Remarks: N/A
#>
function GetMissionElement($search) {
    for($i=1; $i -le $mission.Length; $i++) {
        If($mission[$i] -Match $search) {
            $element = $i
            $i = $mission.Length }}
return $element }

function GetSettingsElement($search) {
    for($i=1; $i -le $serverConfig.Length; $i++) {
        If($serverConfig[$i] -Match $search) {
            $element = $i
            $i = $serverConfig.Length }}
return $element }

####
# INITIALIZING
####

#$ErrorActionPreference = "Stop"
[xml]$InjectionSettings = Get-Content "./WeatherInjectionSettings.xml"
$Log = $InjectionSettings.Settings.Setup.Log
$SavedGamesFolder = $InjectionSettings.Settings.Setup.SavedGamesFolder
$Mission = $InjectionSettings.Settings.Setup.Mission
$AirportICAO = $InjectionSettings.Settings.General.AirportICAO
$Version = "v0.4"
$DEBUG = $InjectionSettings.Settings.General.DEBUG

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

Write-Log "INFO" "---------- Initializing AWCWeatherInjection $Version ----------" $Log
#Write-Log "INFO" $MissionFolder $Log

# Exit if disabled. Nothing to do here.
If (!$InjectionSettings.Settings.Enabled -eq "False") {
    Write-Log "INFO" "Script Disabled. Exiting..." $Log
    Exit
} Else {
    Write-Log "INFO" "Script Enabled. Continuing..." $Log
}

# Fetching METAR from TDS
Try {
    If ($InjectionSettings.Settings.General.AirportICAO) {
        Write-Log "INFO" "Fetching TDS Weather for $AirportICAO..." $Log
        [xml]$weatherxml = Invoke-WebRequest "https://www.aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml&hoursBeforeNow=3&mostRecent=true&stationString=$AirportICAO" -UseBasicParsing
        $debugMETAR = $weatherxml.response.data.metar.raw_text
        Write-Log "INFO" "TDS METAR: $debugMETAR" $Log
    }
} Catch {Write-Log "FATAL" "Weather fetching failed!" $Log}

##############
# BEGIN WEATHER GENERATION
##############

# Setting wind speed from XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.WindGroundSpeedKts) {
    [int]$windSpeedGround = $InjectionSettings.Settings.Weather.WindGroundSpeedKts
} Elseif ($weatherxml.Response.Data.Metar.wind_speed_kt) {
    [int]$windSpeedGround = $weatherxml.Response.Data.Metar.Wind_speed_kt
} Else {
    [int]$windSpeedGround = $null
}

# Checking wind speeds against user constraints
If ($InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts -and ($WindSpeedGround -gt $InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts)) {
    $WindSpeedGround = $InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts
}

# Setting wind direction from XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.WindGroundDir) {
    [int]$windDirGround = $InjectionSettings.Settings.Weather.WindGroundDir
} Elseif ($weatherxml.Response.Data.Metar.Wind_dir_degrees) {
    [int]$windDirGround = $weatherxml.Response.Data.Metar.Wind_dir_degrees
} Else {
    [int]$windDirGround = $null
}

# Setting upper winds speeds and direction
If ($InjectionSettings.Settings.Weather.Wind2000SpeedKts) {
    [int]$windSpeed2000 = $InjectionSettings.Settings.Weather.Wind2000SpeedKts
} Elseif ($windSpeedGround) {
    [int]$windSpeed2000 = $windSpeedGround/1 + (get-Random -Maximum 10 -Minimum 1)
} Else {
    [int]$windSpeed2000 = $null
}

If ($InjectionSettings.Settings.Weather.Wind2000Dir) {
    [int]$windDir2000 = $InjectionSettings.Settings.Weather.Wind2000Dir
} Elseif ($windDirGround) {
    [int]$windDir2000 = $windDirGround/1 + (get-Random -Maximum 90 -Minimum 1)
} Else {
    [int]$windDir2000 = $null
}

If ($InjectionSettings.Settings.Weather.Wind8000SpeedKts) {
    [int]$windSpeed8000 = $InjectionSettings.Settings.Weather.Wind8000SpeedKts
} Elseif ($windSpeedGround) {
    [int]$windSpeed8000 = $windSpeedGround/1 + (get-Random -Maximum 20 -Minimum 5)
} Else {
    [int]$windSpeed8000 = $null
}

If ($InjectionSettings.Settings.Weather.Wind8000Dir) {
    [int]$windDir8000 = $InjectionSettings.Settings.Weather.Wind8000Dir
} Elseif ($windDirGround) {
    [int]$windDir8000 = $windDirGround/1 + (get-Random -Maximum 180 -Minimum 1)
} Else {
    [int]$windDir8000 = $null
}

# Just making sure the winds are between 0-360 degrees.
If ($windDir2000 -gt 360) {$windDir2000 = $windDir2000 - 360}
If ($windDir8000 -gt 360) {$windDir8000 = $windDir8000 - 360}

Write-Log "INFO" "Winds Ground: $windDirGround @ $windSpeedGround Kts" $Log
Write-Log "INFO" "Winds 2000m: $windDir2000 @ $windSpeed2000 Kts" $Log
Write-Log "INFO" "Winds 8000m: $windDir8000 @ $windSpeed8000 Kts" $Log

# Flipping our winds to work with DCS (WINDS FROM --> WINDS TO)
If ($windDirGround -gt 180) {$windDirGround = $windDirGround - 180} ElseIf ($windDirGround -le 180) {$windDirGround = $windDirGround + 180}
If ($windDir2000 -gt 180) {$windDir2000 = $windDir2000 - 180} ElseIf ($windDir2000 -le 180) {$windDir2000 = $windDir2000 + 180}
If ($windDir8000 -gt 180) {$windDir8000 = $windDir8000 - 180} ElseIf ($windDir8000 -le 180) {$windDir8000 = $windDir8000 + 180}

# Setting turbulence if XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.Turbulence) {
    [int]$Turbulence = $InjectionSettings.Weather.Turbulence
} Elseif ($windSpeedGround) {
    [int]$Turbulence = $windSpeedGround * 1.3
} Else {
    [int]$Turbulence = $null
}
Write-Log "INFO" "Turbulence: $Turbulence" $Log

# Setting Temperature if XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.Temperature_C){
    [int]$temperature = $InjectionSettings.Settings.Weather.Temperature_C
} Elseif ($weatherxml.Response.Data.Metar.Temp_c) {
    [int]$temperature = $weatherxml.Response.Data.Metar.Temp_c
} Else {
    [int]$temperature = $null
}
Write-Log "INFO" "Temperature: $temperature C" $Log

# Setting Temperature if XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.Altimeter_InHG) {
    $pressure = $InjectionSettings.Settings.Weather.Altimeter_InHG
} ElseIf ($weatherxml.Response.Data.Metar.altim_in_hg) {
    $pressure = $weatherxml.Response.Data.Metar.altim_in_hg/1
} Else {
    $pressure = $null
}
If ($pressure) {$pressure = [math]::Round($pressure,2)}
#If ($pressure) {$pressure = "{0:n2}" -f $pressure}
Write-Log "INFO" "Pressure: $pressure inHG" $Log

# Setting cloud coverage 
If ($InjectionSettings.Settings.Weather.CloudCoverage) {
    [int]$cloudCoverage = $InjectionSettings.Settings.Weather.CloudCoverage
} Elseif ($weatherxml.Response.Data.Metar.Sky_Condition.Sky_Cover) {
    Switch ($weatherxml.Response.Data.Metar.Sky_condition.Sky_Cover) {
    "SKC" {[int]$cloudCoverage = "0"}
    "CLR" {[int]$cloudCoverage = "0"}
    "CAVOK" {[int]$cloudCoverage = "0"}
    "FEW" {[int]$cloudCoverage = "4"}
    "SCT" {[int]$cloudCoverage = "6"}
    "BKN" {[int]$cloudCoverage = "8"}
    "OVC" {[int]$cloudCoverage = "10"}
    "OVX" {[int]$cloudCoverage = "10"}
    "VV" {[int]$cloudCoverage = "10"}
    default {$cloudCoverage = "2"}}
} Else {
    [int]$cloudCoverage = -1
}

# Checking cloud coverage against user constraints
If ($InjectionSettings.Settings.Constraints.MaxCloudCoverage -and ($cloudCoverage -gt $InjectionSettings.Settings.Constraints.MaxCloudCoverage)) {
    $cloudCoverage = $InjectionSettings.Settings.Constraints.MaxCloudCoverage
}
Write-Log "INFO" "Cloud Cover: $cloudCoverage" $Log

# Grabbing station height MSL, this will be used to calculate cloud height MSL as all clouds are reported as AGL.
[int]$stationHeight = $weatherxml.Response.Data.Metar.Elevation_m/1 * $FeetToMeters

# Setting cloud base if XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.CloudBase_FtMSL) {
    $cloudBaseMSL = $InjectionSettings.Settings.Weather.CloudBase_FtMSL
} Elseif ($weatherxml.Response.Data.Metar.Sky_condition.Cloud_base_ft_agl) {
    $cloudBaseMSL = $null
    $cloudBaseMSL = $weatherxml.Response.Data.Metar.Sky_condition.Cloud_base_ft_agl | Measure-Object -Maximum
    $cloudBaseMSL = $cloudBaseMSL.Maximum + $stationHeight
} Else {
    $cloudBaseMSL = $null
}

# Generating cloud height
[int]$cloudHeight = Get-Random -Maximum "6562" -Minimum "656"

If ($InjectionSettings.Settings.Weather.Precipitation) {
    [int]$Precipitation = $InjectionSettings.Settings.Weather.Precipitation
} Elseif ($weatherxml.Response.Data.Metar.Wx_string) {
    Switch ($weatherxml.Response.Data.Metar.Wx_string) {
    "RA" {[int]$Precipitation = "1"}
    "TS" {[int]$Precipitation = "2"}
    "SN" {[int]$Precipitation = "3"}
    "FZ" {[int]$Precipitation = "4"} #This is for snowstorm, but a snowstorm in DCS is just a thunderstorm with snow so I have nothing to equate this too really
    default {[int]$Precipitation = "0"}}
} Else {
    [int]$Precipitation = $null
}

# Setting fog visibility if XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.FogVisibility_NM) {
    [int]$FogVisibility = $InjectionSettings.Settings.Weather.FogVisibility_NM/1 * $NMtoFeet
} Elseif ($weatherxml.Response.Data.Metar.Visibility_statute_mi/1 -le 3) {
    [int]$FogVisibility = $weatherxml.Response.Data.Metar.Visibility_statute_mi/1 * $NMtoFeet
} Else {
    #[int]$FogVisibility = $null
}

# Checking fog visibility against user constraints
If ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 -and $FogVisibility -gt ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 * 6076)) {
    $FogVisibility = $InjectionSettings.Settings.Constraints.MinimumVisibility_NM * 6076
}

# Setting fog thickness
# If the cloud base is close to the max fox height, the cloud base and fog heights will be matched
# Else, it will be randomly generated
If ($InjectionSettings.Settings.Weather.FogThickness_Ft) {
    [int]$FogHeight = $InjectionSettings.Settings.Weather.FogThickness_Ft
} Elseif ($cloudBaseMSL -lt 5281 -and $weatherxml.Response.Data.Metar.Visibility_statute_mi -le 3 -and $cloudCoverage -ge 8) {
    [int]$FogHeight = 3281
    $cloudBaseMSL = 3281
} Elseif ($FogVisibility) {
    [int]$FogHeight = Get-Random -Maximum 3281 -Minimum 0
} Else {
    [int]$FogHeight = $null
}
Write-Log "INFO" "Cloud Base: $cloudBaseMSL Ft" $Log
Write-Log "INFO" "Cloud Height: $cloudHeight Ft" $Log
Write-Log "INFO" "Precipitation: $Precipitation" $Log

Write-Log "INFO" "Fog Visibility: $FogVisibility Ft" $Log
Write-Log "INFO" "Fog Height: $FogHeight Ft" $Log

<# Setting dust visibility if XML elseif TDS elseif Random else null
If ($InjectionSettings.Settings.Weather.DustVisibility_Ft) {
    [int]$DustVisibility = $InjectionSettings.Settings.Weather.DustVisibility_Ft
} Elseif ($weatherxml.Response.Data.Metar.Wx_string -match "DS" -and $weatherxml.Response.Data.Metar.visibility_statute_mi -le 1.5) {
    [int]$DustVisibility = $weatherxml.Response.Data.Metar.Visibility_statute_mi * 6076
} Elseif ($weatherxml.Response.Data.Metar.Wx_string -match "DS") {
    [int]$DustVisibility = Get-Random -Maximum 9843 -Minimum 984
} Else {
    [int]$DustVisibility = $null
}

#Checking dust visibility against user constraints
If ($DustVisibility -gt ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM * 6076)) {
    $DustVisibility = $InjectionSettings.Settings.Constraints.MinimumVisibility_NM * 6076
}
#>

# Final conversion of units to Meters for later injection.
$windSpeedGround = $windSpeedGround / $KnotToMPS
$windSpeed2000 = $windSpeed2000 / $KnotToMPS
$windSpeed8000 = $windSpeed8000 / $KnotToMPS
$cloudBaseMSL = [math]::Round($cloudBaseMSL / $FeetToMeters)
$FogHeight = [math]::Round($FogHeight / $FeetToMeters)
$FogVisibility = [math]::Round($FogVisibility / $FeetToMeters)
$Pressure = $Pressure * $inHGTommHg
$DustVisibility = $DustVisibility * $FeetToMeters

##############
# END WEATHER GENERATION
##############

If ($InjectionSettings.Settings.Setup.Mission) {
    If (Test-Path $Mission) {
        $miz = $Mission
        Write-Log "INFO" "Fetched Mission: $miz" $Log
    }
} Elseif (Test-Path (Join-Path -path $SavedGamesFolder -childPath "Config\serverSettings.lua")) {
    Write-Log "INFO" "Found Saved Games Folder: $SavedGamesFolder" $Log
    $serverConfig = Get-Content (Join-Path -Path $SavedGamesFolder -ChildPath "Config\serverSettings.lua")
    If($serverConfig) {Write-Log "INFO" "Found Server Config: $serverConfig" $Log}
    $miz = $ServerConfig[(GetSettingsElement(".miz"))]|%{$_.split('"')[1]}
    Write-Log "INFO" "Fetched Mission: $miz" $Log
}

Write-Log "INFO" "Unzipping miz..." $Log
Try {
# Gets the latest modified mission in the mission folder.
$miz | Rename-Item -NewName {$miz -replace ".miz",".zip"} -PassThru |  Set-Variable -Name Mizzip # Renaming it to a .zip.
Get-ChildItem -Path $mizzip | Expand-Archive -DestinationPath "./TempMiz" -Force # Extracting it into ./TempMiz for editing.
$mission = Get-Content ./TempMiz/mission # Finally getting the contents of the mission.
$mizzip = $mizzip.fullname
} Catch {Write-Log "FATAL" "Mission extraction failed!" $Log}

Write-Log "INFO" "Exporting weather..." $Log
# Exporting ground wind speed
Try {
If ($mission[(GetMissionElement("atGround")) + 2] -match "speed" -and $windSpeedGround) {
    $mission[(GetMissionElement("atGround")) + 2] = @"
                ["speed"] = $WindSpeedGround,
"@
    Write-Log "INFO" "Ground wind speed exported." $Log
}} Catch {Write-Log "ERROR" "Ground wind speed export failed!" $Log}

# Exporting ground wind direction
Try {
If ($mission[(GetMissionElement("atGround")) + 3] -match "dir" -and $windDirGround) {
    $mission[(GetMissionElement("atGround")) + 3] = @"
                ["dir"] = $WindDirGround,
"@
    Write-Log "INFO" "Ground wind direction exported." $Log
}} Catch {Write-Log "ERROR" "Ground wind direction export failed!" $Log}

# Exporting 2000m wind speed
Try {
If ($mission[(GetMissionElement("at2000")) + 2] -match "speed" -and $windSpeed2000) {
    $mission[(GetMissionElement("at2000")) + 2] = @"
                ["speed"] = $windSpeed2000,
"@
    Write-Log "INFO" "Wind speed 2000m exported." $Log
}} Catch {Write-Log "ERROR" "Wind speed 2000m export failed!" $Log}

# Exporting 2000m wind direction
Try {
If ($mission[(GetMissionElement("at2000")) + 3] -match "dir" -and $windDir2000) {
    $mission[(GetMissionElement("at2000")) + 3] = @"
                ["dir"] = $windDir2000,
"@
    Write-Log "INFO" "Wind direction 2000m exported." $Log
}} Catch {Write-Log "ERROR" "Wind direction 2000m export failed!" $Log}

# Exporting 8000m wind speed
Try {
If ($mission[(GetMissionElement("at8000")) + 2] -match "speed" -and $windSpeed8000) {
    $mission[(GetMissionElement("at8000")) + 2] = @"
                ["speed"] = $windSpeed8000,
"@
    Write-Log "INFO" "Wind speed 8000m exported." $Log
}} Catch {Write-Log "ERROR" "Wind speed 8000m export failed!" $Log}

# Exporting 8000m wind direction
Try {
If ($mission[(GetMissionElement("at8000")) + 3] -match "dir" -and $windSpeed8000) {
    $mission[(GetMissionElement("at8000")) + 3] = @"
                ["dir"] = $windDir8000,
"@
    Write-Log "INFO" "Wind direction 8000m exported." $Log
}} Catch {Write-Log "ERROR" "Wind direction 8000m export failed!" $Log}

# Exporting turbulence
Try {
If ($mission[(GetMissionElement("groundTurbulence"))] -match "groundTurbulence" -and $Turbulence) {
    $mission[(GetMissionElement("groundTurbulence"))] = @"
        ["groundTurbulence"] = $Turbulence,
"@
    Write-Log "INFO" "Turbulence exported." $Log
}} Catch {Write-Log "ERROR" "Turbulence export failed!" $Log}

# Exporting temperature
Try {
If ($mission[(GetMissionElement("temperature"))] -match "temperature" -and $Temperature) {
    $mission[(GetMissionElement("temperature"))] = @"
            ["temperature"] = $Temperature
"@
    Write-Log "INFO" "Temperature exported." $Log
}} Catch {Write-Log "ERROR" "Temperature export failed!" $Log}

# Exporting pressure
Try {
If ($mission[(GetMissionElement("qnh"))] -match "qnh" -and $Pressure) {
    $mission[(GetMissionElement("qnh"))] = @"
        ["qnh"] = $Pressure,
"@
    Write-Log "INFO" "Pressure exported." $Log
}} Catch {Write-Log "ERROR" "Pressure export failed!" $Log}

# Exporting cloud height
Try {
If ($mission[(GetMissionElement("clouds")) + 2] -match "thickness" -and $cloudHeight) {
    $mission[(GetMissionElement("clouds")) + 2] = @"
            ["thickness"] = $cloudHeight,
"@
    Write-Log "INFO" "Exported cloud height." $Log
}} Catch {Write-Log "ERROR" "Cloud height export failed!" $Log}

# Exporting cloud coverage
Try {
If ($mission[(GetMissionElement("clouds")) + 3] -match "density" -and ($cloudCoverage -gt -1)) {
    $mission[(GetMissionElement("clouds")) + 3] = @"
            ["density"] = $cloudCoverage,
"@
    Write-Log "INFO" "Exported cloud coverage." $Log
}} Catch {Write-Log "ERROR" "Cloud coverage export failed!" $Log}

# Exporting cloud base
Try {
If ($mission[(GetMissionElement("clouds")) + 4] -match "base" -and $cloudBaseMSL) {
    $mission[(GetMissionElement("clouds")) + 4] = @"
            ["base"] = $cloudBaseMSL,
"@
    Write-Log "INFO" "Exported cloud base." $Log
}} Catch {Write-Log "ERROR" "Cloud base export failed!" $Log}

# Exporting precipitation
Try {
If ($mission[(GetMissionElement("clouds")) + 5] -match "iprecptns" -and $Precipitation) {
    $mission[(GetMissionElement("clouds")) + 5] = @"
            ["iprecptns"] = $Precipitation,
"@
    Write-Log "INFO" "Exported precipitation." $Log
}} Catch {Write-Log "ERROR" "Precipitation export failed!"}

# Enabling fog in mission if fog present
Try {
If ($mission[(GetMissionElement("enable_fog"))] -match "enable_fog" -and $FogVisibility) {
    $mission[(GetMissionElement("enable_fog"))] = @"
            ["enable_fog"] = true,
"@
    Write-Log "INFO" "Fog enabled." $Log
}} Catch {Write-Log "ERROR" "Fog enable failed!" $Log}

# Disable fog in mission if fog is not present
Try {
If ($mission[(GetMissionElement("enable_fog"))] -match "enable_fog" -and !$FogVisibility) {
    $mission[(GetMissionElement("enable_fog"))] = @"
            ["enable_fog"] = false,
"@
    Write-Log "INFO" "Fog disabled." $Log
}} Catch {Write-Log "ERROR" "Fog disable failed!" $Log}

# Exporting fog height
Try {
If ($mission[(GetMissionElement("`"fog`"")) + 2] -match "thickness" -and $FogHeight) {
    $mission[(GetMissionElement("`"fog`"")) + 2] = @"
            ["thickness"] = $FogHeight,
"@
    Write-Log "INFO" "Exported fog height." $Log
}} Catch {Write-Log "ERROR" "Fog height export failed!" $Log}

# Exporting fog visibility
Try {
If ($mission[(GetMissionElement("`"fog`"")) + 3] -match "visibility" -and $FogVisibility) {
    $mission[(GetMissionElement("`"fog`"")) + 3] = @"
            ["visibility"] = $FogVisibility,
"@
    Write-Log "INFO" "Exported fog visibility." $Log
}} Catch {Write-Log "ERROR" "Fog visibility export failed!" $Log}
<#
# Enabling dust in mission if dust present
Try {
If ($mission[(GetMissionElement("enable_dust"))] -match "enable_dust" -and $DustVisibility) {
    $mission[(GetMissionElement("enable_dust"))] = @"
        ["enable_dust"] = true,
"@
    Write-Log "INFO" "Dust Enabled." $Log
}} Catch {Write-Log "ERROR" "Dust enable failed!" $Log}

# Disabling dust in mission if dust is not present
Try {
If ($mission[(GetMissionElement("enable_dust"))] -match "enable_dust" -and !$DustVisibility) {
    $mission[(GetMissionElement("enable_dust"))] = @"
        ["enable_dust"] = false,
"@
    Write-Log "INFO" "Dust Disabled." $Log
}} Catch {Write-Log "ERROR" "Dust disable failed!" $Log}

# Exporting dust visibility
Try {
If ($mission[(GetMissionElement("dust_density"))] -match "dust_density" -and $DustVisibility) {
    $mission[(GetMissionElement("dust_density"))] = @"
        ["dust_density"] = $DustVisibility,
"@
    Write-Log "INFO" "Exported Dust Visibility." $Log
}} Catch {Write-Log "ERROR" "Dust visibility export failed!" $Log}
#>

Write-Log "INFO" "Finished Export." $Log
Try {Set-Content -Path "./TempMiz/mission" -Value $mission -Force} Catch {Write-Log "FATAL" "Mission export failed!"}

Try {
Compress-Archive -Path "./TempMiz/mission" -Update -DestinationPath $mizzip
$mizzip | Rename-Item -NewName {$mizzip -replace ".zip",".miz"} -Force # Renaming it to a .zip.
Remove-Item "./TempMiz" -Recurse -Force
} Catch {Write-Log "FATAL" "Zipping failed!" $Log}

Write-Log "INFO" "Script complete. Exiting..." $Log
Exit