<#
    Author: Mr_Superjaffa#5430
    Description: Inject real world weather into DCS .miz file for use on servers.
    Version: v0.7.2
    Modified: Dec 25/2021
    Notes: N/A
#>

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

Function Add-Element($ArrayIn, [int]$InsertIndex, $InputString) {
    $ArrayA = $ArrayIn[0..$InsertIndex]
    $ArrayB = $ArrayIn[$InsertIndex..$ArrayIn.Count]
    
    $ArrayA[$InsertIndex] = $InputString
    $ArrayA += $ArrayB

    Return $ArrayA
}

####
# INITIALIZING
####

#$ErrorActionPreference = "Stop"
$Version = "v0.7.2"
[xml]$InjectionSettings = Get-Content "./WeatherInjectionSettings.xml"
$Log = $InjectionSettings.Settings.Setup.Log
$SavedGamesFolder = $InjectionSettings.Settings.Setup.SavedGamesFolder
$Mission = $InjectionSettings.Settings.Setup.Mission
$AirportICAO = $InjectionSettings.Settings.General.AirportICAO
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
If ($InjectionSettings.Settings.Enabled -eq "False") {
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
		if(-not $weatherxml.response.data.metar.raw_text -and (Test-Path -Path "./$($InjectionSettings.Settings.General.AirportICAO)-Weather.csv")) {
			Write-Log "INFO" "Entering Historic Mode." $Log

			#Historic data in CSV format for this function can be obtained from https://mesonet.agron.iastate.edu/request/download.phtml
			$historicdata = Import-CSV -Path "./$($InjectionSettings.Settings.General.AirportICAO)-Weather.csv"

			$todayMonth = (Get-Date).ToUniversalTime().ToString("MM")
			if($InjectionSettings.Settings.Time.Month) {
				$todayMonth = $InjectionSettings.Settings.Time.Month
				if($todayMonth.Length -eq 1) {
					$todayMonth = "0$todayMonth"
				}
			}
			$todayDay = (Get-Date).ToUniversalTime().ToString("dd")
			if($InjectionSettings.Settings.Time.Day) {
				$todayDay = $InjectionSettings.Settings.Time.Day
				if($todayDay.Length -eq 1) {
					$todayDay = "0$todayDay"
				}
			}
			$todayTime = (Get-Date).ToUniversalTime().ToString("HH:mm")
			if($InjectionSettings.Settings.Time.Time) {
				$timeSplit = $InjectionSettings.Settings.Time.Time.Split(":")
				$todayTime = "$($timeSplit[0]):$($timeSplit[1])"
			}

			$i = 0
			$temp = -1
			$diff
			foreach($item in $historicdata) {
				$timestamp = $item.valid.replace(" ","T").Split("-T")
				if(($timestamp[1] -eq $todayMonth) -and ($timestamp[2] -eq $todayDay)) {
					#Write-Host $timestamp[0] $timestamp[1] $timestamp[2] $timestamp[3] i:$i
					if(($temp -eq -1) -or ($([Math]::Abs(((Get-Date -Hour ([int]$timestamp[3].Substring(0,2)) -Minute ([int]$timestamp[3].Substring(3,2)) -Second 0) - (Get-Date -Hour ([int]$todayTime.Substring(0,2)) -Minute ([int]$todayTime.Substring(3,2)) -Second 0)).TotalMinutes) -lt $diff))) {
						$temp = $i
						$diff =  $([Math]::Abs(((Get-Date -Hour ([int]$timestamp[3].Substring(0,2)) -Minute ([int]$timestamp[3].Substring(3,2)) -Second 0) - (Get-Date -Hour ([int]$todayTime.Substring(0,2)) -Minute ([int]$todayTime.Substring(3,2)) -Second 0)).TotalMinutes))
					}
				}
				$i++
			}
			$i = $temp

			Write-Log "INFO" "Using historic METAR at index $i" $Log

			$metar = $weatherxml.CreateNode("element", "metar", $null)

			$t = $weatherxml.CreateNode("element", "raw_text", $null)
			$metar.AppendChild($t) | Out-Null

			$t = $weatherxml.CreateNode("element", "observation_time", $null)
			$metar.AppendChild($t) | Out-Null

			if (-not ($historicdata[$i].tmpf -eq "M")) {
				$t = $weatherxml.CreateNode("element", "temp_c", $null)
				$metar.AppendChild($t) | Out-Null
			}
			
			if (-not ($historicdata[$i].drct -eq "M")) {
				$t = $weatherxml.CreateNode("element", "wind_dir_degrees", $null)
				$metar.AppendChild($t) | Out-Null
			}
			
			if (-not ($historicdata[$i].sknt -eq "M")) {
				$t = $weatherxml.CreateNode("element", "wind_speed_kt", $null)
				$metar.AppendChild($t) | Out-Null
			}

			if (-not ($historicdata[$i].vsby -eq "M")) {
				$t = $weatherxml.CreateNode("element", "visibility_statute_mi", $null)
				$metar.AppendChild($t) | Out-Null
			}

			if (-not ($historicdata[$i].alti -eq "M")) {
				$t = $weatherxml.CreateNode("element", "altim_in_hg", $null)
				$metar.AppendChild($t) | Out-Null
			}

			if (-not ($historicdata[$i].wxcodes -eq "M")) {
				$t = $weatherxml.CreateNode("element", "wx_string", $null)
				$metar.AppendChild($t) | Out-Null
			}

			if (-not ($historicdata[$i].skyc1 -eq "M")) {
				$t = $weatherxml.CreateNode("element", "sky_condition", $null)
				$t.SetAttribute("sky_cover", $historicdata[$i].skyc1)
				if (-not ($historicdata[$i].skyl1 -eq "M")) {
					$t.SetAttribute("cloud_base_ft_agl", [int]$historicdata[$i].skyl1)
				}
				$metar.AppendChild($t) | Out-Null
			}
			
			if (-not ($historicdata[$i].skyc2 -eq "M")) {
				$t = $weatherxml.CreateNode("element", "sky_condition", $null)
				$t.SetAttribute("sky_cover", $historicdata[$i].skyc2)
				if (-not ($historicdata[$i].skyl2 -eq "M")) {
					$t.SetAttribute("cloud_base_ft_agl", [int]$historicdata[$i].skyl2)
				}
				$metar.AppendChild($t) | Out-Null
			}
			
			if (-not ($historicdata[$i].skyc3 -eq "M")) {
				$t = $weatherxml.CreateNode("element", "sky_condition", $null)
				$t.SetAttribute("sky_cover", $historicdata[$i].skyc3)
				if (-not ($historicdata[$i].skyl3 -eq "M")) {
					$t.SetAttribute("cloud_base_ft_agl", [int]$historicdata[$i].skyl3)
				}
				$metar.AppendChild($t) | Out-Null
			}
			
			if (-not ($historicdata[$i].skyc4 -eq "M")) {
				$t = $weatherxml.CreateNode("element", "sky_condition", $null)
				$t.SetAttribute("sky_cover", $historicdata[$i].skyc4)
				if (-not ($historicdata[$i].skyl4 -eq "M")) {
					$t.SetAttribute("cloud_base_ft_agl", [int]$historicdata[$i].skyl4)
				}
				$metar.AppendChild($t) | Out-Null
			}

			
			if (-not ($historicdata[$i].elevation -eq "M")) {
				$t = $weatherxml.CreateNode("element", "elevation_m", $null)
				$metar.AppendChild($t) | Out-Null
			}

			#$weatherxml.response.data.
			$weatherxml.response.data.AppendChild($metar) | Out-Null
			$weatherxml.response.data.metar.raw_text = $historicdata[$i].metar
			$weatherxml.response.data.metar.observation_time = "$($historicdata[$i].valid.replace(" ","T")):00Z"
			if(-not ($historicdata[$i].tmpf -eq "M")) {
				$weatherxml.response.data.metar.temp_c = "$(([int]$historicdata[$i].tmpf - 32) / 1.8)"
			}
			if(-not ($historicdata[$i].drct -eq "M")) {
				$weatherxml.response.data.metar.wind_dir_degrees = "$([int]$historicdata[$i].drct)"
			}
			if(-not ($historicdata[$i].sknt -eq "M")) {
				$weatherxml.response.data.metar.wind_speed_kt = "$([int]$historicdata[$i].sknt)"
			}
			if(-not ($historicdata[$i].vsby -eq "M")) {
				$weatherxml.response.data.metar.visibility_statute_mi = "$($historicdata[$i].vsby)"
			}
			if(-not ($historicdata[$i].alti -eq "M")) {
				$weatherxml.response.data.metar.altim_in_hg = "$($historicdata[$i].alti)"
			}
			if(-not ($historicdata[$i].wxcodes -eq "M")) {
				$weatherxml.response.data.metar.wx_string = "$($historicdata[$i].wxcodes)"
			}
			if(-not ($historicdata[$i].elevation -eq "M")) {
				$weatherxml.response.data.metar.elevation_m = "$([int]$historicdata[$i].elevation)"
			}
			$weatherxml.Save("test.xml") #For debugging the fake XML
		}
        $debugMETAR = $weatherxml.response.data.metar.raw_text
        Write-Log "INFO" "TDS METAR: $debugMETAR" $Log
    }
} Catch {Write-Log "FATAL" "Weather fetching failed! $_" $Log}

If ($InjectionSettings.Settings.Setup.Mission) {
    If (Test-Path $Mission) {
        $miz = $Mission
        Write-Log "INFO" "Fetched Mission: $miz" $Log
    }
} Elseif (Test-Path (Join-Path -path $SavedGamesFolder -childPath "Config\serverSettings.lua")) {
    Write-Log "INFO" "Found Saved Games Folder: $SavedGamesFolder" $Log
    $serverConfigLocation = Join-Path -Path $SavedGamesFolder -ChildPath "Config\serverSettings.lua"
    $serverConfig = Get-Content $serverConfigLocation
    If($serverConfig) {Write-Log "INFO" "Found Server Config: $serverConfigLocation" $Log}
    $miz = $ServerConfig[(GetSettingsElement("\[1\]"))]|%{$_.split('"')[1]}
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

##############
# BEGIN WEATHER GENERATION
##############

# Setting wind speed from XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.WindGroundSpeedKts) {
    [int]$windSpeedGround = $InjectionSettings.Settings.Weather.WindGroundSpeedKts
} Elseif ($weatherxml.Response.Data.Metar.wind_speed_kt) {
	If ([int]$weatherxml.Response.Data.Metar.elevation_m -le 488) {
		[int]$windSpeedGround = (1.95958*[float]$weatherxml.Response.Data.Metar.wind_speed_kt)/([Math]::Pow((([float]$weatherxml.Response.Data.Metar.elevation_m)*3.281),0.1924))
	} Elseif ([int]$weatherxml.Response.Data.Metar.elevation_m -le 2000) {
		[int]$windSpeedGround = ([float]$weatherxml.Response.Data.Metar.Wind_speed_kt)/2
	} Else {
		[int]$windSpeedGround = $weatherxml.Response.Data.Metar.Wind_speed_kt
	}
} Else {
    [int]$windSpeedGround = $null
}

# Checking wind speeds against user constraints
If ($InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts -and ($WindSpeedGround -gt $InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts)) {
    $WindSpeedGround = $InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts
    Write-Log "WARN" "Wind speed higher than max allowed! Setting maximum wind speed allowed!" $Log
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
    "CAVOK" {[int]$cloudCoverage = Get-Random -Input 0,1,2}
    "FEW" {[int]$cloudCoverage = Get-Random -Input 3,4}
    "SCT" {[int]$cloudCoverage = Get-Random -Input 5,6}
    "BKN" {[int]$cloudCoverage = Get-Random -Input 7,8}
    "OVC" {[int]$cloudCoverage = Get-Random -Input 9,10}
    "OVX" {[int]$cloudCoverage = "10"}
    "VV" {[int]$cloudCoverage = "10"}
    default {$cloudCoverage = "2"}}
} Else {
    [int]$cloudCoverage = -1
}

# Checking cloud coverage against user constraints
If ($InjectionSettings.Settings.Constraints.MaxCloudCoverage -and ($cloudCoverage -gt $InjectionSettings.Settings.Constraints.MaxCloudCoverage)) {
    $cloudCoverage = $InjectionSettings.Settings.Constraints.MaxCloudCoverage
    Write-Log "WARN" "Cloud coverage higher than max allowed! Setting max allowed value!" $Log
}
Write-Log "INFO" "Cloud Cover: $cloudCoverage" $Log

# Grabbing station height MSL, this will be used to calculate cloud height MSL as all clouds are reported as AGL.
[int]$stationHeight = $weatherxml.Response.Data.Metar.elevation_m/1 * $FeetToMeters

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
Write-Log "INFO" "Cloud Base: $cloudBaseMSL ft MSL" $Log

# Checking cloud base against user constraints
If ($InjectionSettings.Settings.Constraints.MinCloudBase_FtMSL -and ($cloudBaseMSL -lt $InjectionSettings.Settings.Constraints.MinCloudBase_FtMSL)) {
    $cloudBaseMSL = $InjectionSettings.Settings.Constraints.MinCloudBase_FtMSL
    Write-Log "WARN" "Cloud base lower than allowed! Setting minimum allowed value!" $Log
}

# Generating cloud height
[int]$cloudHeight = Get-Random -Maximum "6562" -Minimum "656"

If ($InjectionSettings.Settings.Weather.Precipitation) {
    [int]$Precipitation = $InjectionSettings.Settings.Weather.Precipitation
} Elseif ($weatherxml.Response.Data.Metar.Wx_string) {
    Switch -wildcard ($weatherxml.Response.Data.Metar.Wx_string) {
    "*RA*" {[int]$Precipitation = "1"}
    "*TS*" {[int]$Precipitation = "2"}
    "*SN*" {[int]$Precipitation = "3"}
    "*FZ*" {[int]$Precipitation = "4"} #This is for snowstorm, but a snowstorm in DCS is just a thunderstorm with snow so I have nothing to equate this too really
    default {[int]$Precipitation = "0"}}
} Else {
    [int]$Precipitation = $null
}
<#
# Setting fog visibility if XML elseif TDS else null
If ($InjectionSettings.Settings.Weather.FogVisibility_NM) {
    [int]$FogVisibility = $InjectionSettings.Settings.Weather.FogVisibility_NM/1 * $NMtoFeet
} Elseif ($weatherxml.Response.Data.Metar.Visibility_statute_mi/1 -le 3) {
    [int]$FogVisibility = $weatherxml.Response.Data.Metar.Visibility_statute_mi/1 * $NMtoFeet
} Else {
    [int]$FogVisibility = $null
}

# Checking fog visibility against user constraints
If ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 -and $FogVisibility -gt ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 * 6076)) {
    $FogVisibility = $InjectionSettings.Settings.Constraints.MinimumVisibility_NM * 6076
    Write-Log "WARN" "Fog Visibility lower than minimum allowed. Setting minimum allowed value!" $Log
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

Switch ($InjectionSettings.Settings.Weather.DustVisibility_Ft) {
    "FU" {$Obscuration = $True; Break}
    "DU" {$Obscuration = $True; Break}
    "SA" {$Obscuration = $True; Break}
    "HZ" {$Obscuration = $True; Break}
    "VA" {$Obscuration = $True; Break}
    "PO" {$Obscuration = $True; Break}
    "SS" {$Obscuration = $True; Break}
    "DS" {$Obscuration = $True; Break}
    Default {$Obscuration = $False}
}
Write-Log "INFO" "Obscuration: $Obscuration" $Log
#>
<#
## Commented out the dust settings until it's fixed by ED.

# Setting dust visibility if XML elseif TDS elseif Random else null
If ($InjectionSettings.Settings.Weather.DustVisibility_Ft) {
    [int]$DustVisibility = $InjectionSettings.Settings.Weather.DustVisibility_Ft
} Elseif ($Obscuration -eq $True -and $weatherxml.Response.Data.Metar.visibility_statute_mi -le 1.5) {
    [int]$DustVisibility = $weatherxml.Response.Data.Metar.Visibility_statute_mi/1 * 6076
} Elseif ($Obscuration -eq $True) {
    [int]$DustVisibility = Get-Random -Maximum 9843 -Minimum 984
} Else {
    [int]$DustVisibility = $null
}
Write-Log "INFO" "Dust Visibility: $DustVisibility Ft" $Log

#Checking dust visibility against user constraints
If ($DustVisibility -gt ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 * 6076)) {
    $DustVisibility = $InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 * 6076
    Write-Log "WARN" "Dust Visibility greater than allowed! Setting max allowed value!" $Log
}
#>

$presetHSCT = @("Preset3","Preset4","Preset8")

$presetLSCT = @("Preset1","Preset2")

$presetSCT = @("Preset5","Preset6","Preset7","Preset9","Preset10","Preset11","Preset12")

$presetBKN = @("Preset13","Preset14","Preset15","Preset16","Preset17","Preset18","Preset19","Preset20")

$presetOVC = @("Preset21","Preset22","Preset23","Preset24","Preset25","Preset26","Preset27")

$presetOVCRA = @("RainyPreset1","RainyPreset2","RainyPreset3")

Switch ($cloudCoverage)
{
    {$_ -eq 0} {$cloudPreset = $null; Break}
    {$_ -le 2} {$cloudPreset = Get-Random -InputObject $presetHSCT; Break} ## High Scattered
    {$_ -le 4} {$cloudPreset = Get-Random -InputObject $presetLSCT; Break} ## Light Scattered
    {$_ -le 6} {$cloudPreset = Get-Random -InputObject $presetSCT; Break} ## Scattered
    {$_ -le 8} {$cloudPreset = Get-Random -InputObject $presetBKN; Break} ## Broken
    {$_ -le 10} { ## Overcast
        if ($Precipitation -ge 1) {
            $cloudPreset = Get-Random -InputObject $presetOVCRA
        } else {
            $cloudPreset = Get-Random -InputObject $presetOVC
        };
        Break
    } 
}

If ($InjectionSettings.Settings.Weather.WeatherPreset) {
    $cloudPreset = $InjectionSettings.Settings.Weather.WeatherPreset
}
Write-Log "INFO" "Cloud Preset: $cloudPreset" $Log

# Final conversion of units to Meters for later injection.
$windSpeedGround = $windSpeedGround / $KnotToMPS
$windSpeed2000 = $windSpeed2000 / $KnotToMPS
$windSpeed8000 = $windSpeed8000 / $KnotToMPS
$cloudBaseMSL = [math]::Round($cloudBaseMSL / $FeetToMeters)
$cloudHeight = [math]::Round($cloudHeight / $FeetToMeters)
$FogHeight = [math]::Round($FogHeight / $FeetToMeters)
$FogVisibility = [math]::Round($FogVisibility / $FeetToMeters)
$Pressure = $Pressure * $inHGTommHg
$DustVisibility = $DustVisibility * $FeetToMeters

##############
# END WEATHER GENERATION
# BEGIN TIME CONVERSION
##############

Try {
    If ($InjectionSettings.Settings.General.EnableTime -eq "True") {
        Write-Log "INFO" "Time enabled. Calculating time..." $Log

        # Grabbing METAR Zulu time and splitting it. YYYY MM DD HH:MM:SS
        $DateTime = $weatherxml.Response.Data.Metar.Observation_time.Split("-TZ")

        # Setting Year if XML else METAR else null.
        If($InjectionSettings.Settings.Time.Year){
            $Year = $InjectionSettings.Settings.Time.Year
        } ElseIf ($DateTime[0] -ge 1900) {
            $Year = $DateTime[0]
        } Else {
            $Year = $null
        }
        Write-Log "INFO" "Year: $Year" $Log

        # Setting Month if XML else METAR else null.
        If($InjectionSettings.Settings.Time.Month){
            $Month = $InjectionSettings.Settings.Time.Month
        } Elseif ($DateTime[1]) {
            $Month = $DateTime[1]
        } Else {
            $Month = $null
        }
        Write-Log "INFO" "Month: $Month" $Log

        # Setting Day if XML else METAR else null.
        If($InjectionSettings.Settings.Time.Day){
            $Day = $InjectionSettings.Settings.Time.Day
        } Elseif ($DateTime[2]) {
            $Day = $DateTime[2]
        } Else {
            $Day = $null
        }
        Write-Log "INFO" "Day: $Day" $Log

        # Setting Time from XML else METAR else null. Converted into seconds.
        If($InjectionSettings.Settings.Time.Time) {
            $TimeHHMMSS = $InjectionSettings.Settings.Time.Time
            $TimeSplit = $TimeHHMMSS.Split(":")
            $TimeSeconds = (New-TimeSpan -Hours $TimeSplit[0] -Minutes $TimeSplit[1] -Seconds $TimeSplit[2]).TotalSeconds
        } Elseif ($InjectionSettings.Settings.General.TimeFormat -Match "Random") {
            $TimeSeconds = ((Get-Random -Minimum 0 -Maximum 24) * 3600)
        } Elseif ($DateTime[3]) {
            $TimeHHMMSS = $DateTime[3]
            $TimeSplit = $TimeHHMMSS.Split(":")
            $TimeSeconds = (New-TimeSpan -Hours $TimeSplit[0] -Minutes $TimeSplit[1] -Seconds $TimeSplit[2]).TotalSeconds
        } Else {
            $TimeSeconds = $null
        }

        # Setting Zulu into Local if enabled.
        If ($InjectionSettings.Settings.Time.Timezone) {
            $Timezone = $InjectionSettings.Settings.Time.Timezone / 1
            $TimeSeconds = $TimeSeconds + ($Timezone * 3600)
            Write-Log "INFO" "Setting manual timezone: $Timezone" $Log
        } 
        ElseIf($InjectionSettings.Settings.General.TimeFormat -Match "Local" -and $TimeSeconds) {
            Write-Log "INFO" "Converting to local time..." $Log
            
            # Getting mission theatre and adjusting time accordingly.
            [string]$theatreString = $mission[(GetMissionElement("theatre"))]
            If ($theatreString -Match "Caucasus") {
                $TimeSeconds = $TimeSeconds + (3 * 3600)
                $Theatre = "Caucasus"
            } Elseif ($theatreString -Match "PersianGulf") {
                $TimeSeconds = $TimeSeconds + (4 * 3600)
                $Theatre = "PersianGulf"
            } Elseif ($theatreString -Match "Normandy") {
                $TimeSeconds = $TimeSeconds + (2 * 3600)
                $Theatre = "Normandy"
            } Elseif ($theatreString -Match "Nevada") {
                $TimeSeconds = $TimeSeconds - (7 * 3600)
                $Theatre = "Nevada"
            } Else {
                Write-Log "ERROR" "Theatre not found!" $Log
            }
            Write-Log "INFO" "Theatre: $Theatre" $Log

            # Making sure time makes sense.
            If ($TimeSeconds -gt 86400) {$TimeSeconds = $TimeSeconds - 86400}
            Elseif ($TimeSeconds -lt 0) {$TimeSeconds = $TimeSeconds + 86400}
        }
        Write-Log "INFO" "Time: $TimeHHMMSS $TimeSeconds" $Log
    } Else {Write-Log "INFO" "Time disabled." $Log}
} Catch {Write-Log "ERROR" "Time function failed!" $Log}

##############
# END TIME CONVERSION
##############

Write-Log "INFO" "Exporting weather..." $Log

If (($null -eq (GetMissionElement("`"preset`""))) -and $cloudPreset) {
    Write-Log "INFO" "Creating cloud preset line." $Log
    $mission = Add-Element -ArrayIn $mission -InsertIndex (GetMissionElement("`"base`"") + 1) -InputString "`t`t`t[`"preset`"] = `"$cloudPreset`","
}

# Exporting ground wind speed
Try {
If ($mission[(GetMissionElement("atGround")) + 2] -match "speed" -and $windSpeedGround) {
    $mission[(GetMissionElement("atGround")) + 2] = "`t`t`t`t[`"speed`"] = $WindSpeedGround,"
    Write-Log "INFO" "Ground wind speed exported." $Log
}} Catch {Write-Log "ERROR" "Ground wind speed export failed!" $Log}

# Exporting ground wind direction
Try {
If ($mission[(GetMissionElement("atGround")) + 3] -match "dir" -and $windDirGround) {
    $mission[(GetMissionElement("atGround")) + 3] = "`t`t`t`t[`"dir`"] = $WindDirGround,"
    Write-Log "INFO" "Ground wind direction exported." $Log
}} Catch {Write-Log "ERROR" "Ground wind direction export failed!" $Log}

# Exporting 2000m wind speed
Try {
If ($mission[(GetMissionElement("at2000")) + 2] -match "speed" -and $windSpeed2000) {
    $mission[(GetMissionElement("at2000")) + 2] = "`t`t`t`t[`"speed`"] = $windSpeed2000,"
    Write-Log "INFO" "Wind speed 2000m exported." $Log
}} Catch {Write-Log "ERROR" "Wind speed 2000m export failed!" $Log}

# Exporting 2000m wind direction
Try {
If ($mission[(GetMissionElement("at2000")) + 3] -match "dir" -and $windDir2000) {
    $mission[(GetMissionElement("at2000")) + 3] = "`t`t`t`t[`"dir`"] = $windDir2000,"
    Write-Log "INFO" "Wind direction 2000m exported." $Log
}} Catch {Write-Log "ERROR" "Wind direction 2000m export failed!" $Log}

# Exporting 8000m wind speed
Try {
If ($mission[(GetMissionElement("at8000")) + 2] -match "speed" -and $windSpeed8000) {
    $mission[(GetMissionElement("at8000")) + 2] = "`t`t`t`t[`"speed`"] = $windSpeed8000,"
    Write-Log "INFO" "Wind speed 8000m exported." $Log
}} Catch {Write-Log "ERROR" "Wind speed 8000m export failed!" $Log}

# Exporting 8000m wind direction
Try {
If ($mission[(GetMissionElement("at8000")) + 3] -match "dir" -and $windSpeed8000) {
    $mission[(GetMissionElement("at8000")) + 3] = "`t`t`t`t[`"dir`"] = $windDir8000,"
    Write-Log "INFO" "Wind direction 8000m exported." $Log
}} Catch {Write-Log "ERROR" "Wind direction 8000m export failed!" $Log}

# Exporting turbulence
Try {
If ($mission[(GetMissionElement("groundTurbulence"))] -match "groundTurbulence" -and $Turbulence) {
    $mission[(GetMissionElement("groundTurbulence"))] = "`t`t[`"groundTurbulence`"] = $Turbulence,"
    Write-Log "INFO" "Turbulence exported." $Log
}} Catch {Write-Log "ERROR" "Turbulence export failed!" $Log}

# Exporting temperature
Try {
If ($mission[(GetMissionElement("temperature"))] -match "temperature" -and $Temperature) {
    $mission[(GetMissionElement("temperature"))] = "`t`t`t[`"temperature`"] = $Temperature"
    Write-Log "INFO" "Temperature exported." $Log
}} Catch {Write-Log "ERROR" "Temperature export failed!" $Log}

# Exporting pressure
Try {
If ($mission[(GetMissionElement("qnh"))] -match "qnh" -and $Pressure) {
    $mission[(GetMissionElement("qnh"))] = "`t`t`[`"qnh`"] = $Pressure,"
    Write-Log "INFO" "Pressure exported." $Log
}} Catch {Write-Log "ERROR" "Pressure export failed!" $Log}

# Exporting cloud height
Try {
If ($mission[(GetMissionElement("clouds")) + 3] -match "thickness" -and $cloudHeight) {
    $mission[(GetMissionElement("clouds")) + 3] = "`t`t`t[`"thickness`"] = $cloudHeight,"
    Write-Log "INFO" "Exported cloud height." $Log
}} Catch {Write-Log "ERROR" "Cloud height export failed!" $Log}

# Exporting cloud coverage
Try {
If ($mission[(GetMissionElement("`"density`""))] -match "density" -and ($cloudCoverage -gt -1)) {
    $mission[(GetMissionElement("`"density`""))] = "`t`t`t[`"density`"] = $cloudCoverage,"
    Write-Log "INFO" "Exported cloud coverage." $Log
}} Catch {Write-Log "ERROR" "Cloud coverage export failed!" $Log}

# Exporting cloud base
Try {
If ($mission[(GetMissionElement("`"base`""))] -match "base" -and $cloudBaseMSL) {
    $mission[(GetMissionElement("`"base`""))] = "`t`t`t[`"base`"] = $cloudBaseMSL,"
    Write-Log "INFO" "Exported cloud base." $Log
}} Catch {Write-Log "ERROR" "Cloud base export failed!" $Log}

# Exporting precipitation
Try {
If ($mission[(GetMissionElement("`"iprecptns`""))] -match "iprecptns" -and $Precipitation -ge 0) {
    $mission[(GetMissionElement("`"iprecptns`""))] = "`t`t`t[`"iprecptns`"] = $Precipitation,"
    Write-Log "INFO" "Exported precipitation." $Log
}} Catch {Write-Log "ERROR" "Precipitation export failed!"}

# Enabling fog in mission if fog present
Try {
If ($mission[(GetMissionElement("enable_fog"))] -match "enable_fog" -and $FogVisibility) {
    $mission[(GetMissionElement("enable_fog"))] = "`t`t[`"enable_fog`"] = true,"
    Write-Log "INFO" "Fog enabled." $Log
}} Catch {Write-Log "ERROR" "Fog enable failed!" $Log}

# Disable fog in mission if fog is not present
Try {
If ($mission[(GetMissionElement("enable_fog"))] -match "enable_fog" -and !$FogVisibility) {
    $mission[(GetMissionElement("enable_fog"))] = "`t`t[`"enable_fog`"] = false,"
    $mission[(GetMissionElement("`"fog`"")) + 2] = "`t`t`t[`"thickness`"] = 0,"
    $mission[(GetMissionElement("`"fog`"")) + 3] = "`t`t`t[`"visibility`"] = 0,"
    Write-Log "INFO" "Fog disabled." $Log
}} Catch {Write-Log "ERROR" "Fog disable failed!" $Log}

# Exporting fog height
Try {
If ($mission[(GetMissionElement("`"fog`"")) + 2] -match "thickness" -and $FogHeight) {
    $mission[(GetMissionElement("`"fog`"")) + 2] = "`t`t`t[`"thickness`"] = $FogHeight,"
    Write-Log "INFO" "Exported fog height." $Log
}} Catch {Write-Log "ERROR" "Fog height export failed!" $Log}

# Exporting fog visibility
Try {
If ($mission[(GetMissionElement("`"fog`"")) + 3] -match "visibility" -and $FogVisibility) {
    $mission[(GetMissionElement("`"fog`"")) + 3] = "`t`t`t[`"visibility`"] = $FogVisibility,"
    Write-Log "INFO" "Exported fog visibility." $Log
}} Catch {Write-Log "ERROR" "Fog visibility export failed!" $Log}

# Enabling dust in mission if dust present
Try {
If ($mission[(GetMissionElement("enable_dust"))] -match "enable_dust" -and $DustVisibility) {
    $mission[(GetMissionElement("enable_dust"))] = "`t`t[`"enable_dust`"] = true,"
    Write-Log "INFO" "Dust Enabled." $Log
}} Catch {Write-Log "ERROR" "Dust enable failed!" $Log}

# Disabling dust in mission if dust is not present
Try {
If ($mission[(GetMissionElement("enable_dust"))] -match "enable_dust" -and !$DustVisibility) {
    $mission[(GetMissionElement("enable_dust"))] = "`t`t[`"enable_dust`"] = false,"
    $mission[(GetMissionElement("dust_density"))] = "`t`t[`"dust_density`"] = 0,"
    Write-Log "INFO" "Dust Disabled." $Log
}} Catch {Write-Log "ERROR" "Dust disable failed!" $Log}

# Exporting dust visibility
Try {
If ($mission[(GetMissionElement("dust_density"))] -match "dust_density" -and $DustVisibility) {
    $mission[(GetMissionElement("dust_density"))] = "`t`t[`"dust_density`"] = $DustVisibility,"
    Write-Log "INFO" "Exported Dust Visibility." $Log
}} Catch {Write-Log "ERROR" "Dust visibility export failed!" $Log}

# Exporting weather preset
Try {
If ($mission[(GetMissionElement("`"preset`""))] -match "preset" -and $cloudPreset) {
    $mission[(GetMissionElement("`"preset`""))] = "`t`t`t[`"preset`"] = `"$cloudPreset`","
    Write-Log "INFO" "Exported Weather Preset." $Log
}} Catch {Write-Log "ERROR" "Weather Preset export failed!" $Log}

# Exporting mission year.
Try {
If ($mission[(GetMissionElement("Year"))] -match "Year" -and $Year) {
    $mission[(GetMissionElement("Year"))] = "`t`t[`"Year`"] = $Year,"
    Write-Log "INFO" "Exported Year." $Log
}} Catch {Write-Log "ERROR" "Year export failed!"}

# Exporting mission day.
Try {
If ($mission[(GetMissionElement("Day"))] -match "Day" -and $Day) {
    $mission[(GetMissionElement("Day"))] = "`t`t[`"Day`"] = $Day,"
    Write-Log "INFO" "Exported Day." $Log
}} Catch {Write-Log "ERROR" "Day export failed!"}

# Exporting mission month.
Try {
If ($mission[(GetMissionElement("Month"))] -match "Month" -and $Month) {
    $mission[(GetMissionElement("Month"))] = "`t`t[`"Month`"] = $Month,"
    Write-Log "INFO" "Exported Month." $Log
}} Catch {Write-Log "ERROR" "Month export failed!"}

# Exporting mission start time.
Try {
    If ($mission[(GetMissionElement("currentKey")) + 1] -match "start_time" -and $TimeSeconds) {
    $mission[(GetMissionElement("currentKey")) + 1] = "`t`t[`"start_time`"] = $TimeSeconds,"
    Write-Log "INFO" "Exported Start Time." $Log
}} Catch {Write-Log "ERROR" "Start Time export failed!"}

#currentKey
#start_time
#forcedOptions

Write-Log "INFO" "Finished Export." $Log
Try {Set-Content -Path "./TempMiz/mission" -Value $mission -Force} Catch {Write-Log "FATAL" "Mission export failed!"}

Try {
Compress-Archive -Path "./TempMiz/mission" -Update -DestinationPath $mizzip
$mizzip | Rename-Item -NewName {$mizzip -replace ".zip",".miz"} -Force # Renaming it to a .zip.
Remove-Item "./TempMiz" -Recurse -Force
} Catch {Write-Log "FATAL" "Zipping failed!" $Log}

Write-Log "INFO" "Script complete. Exiting..." $Log
Exit