Function GetTDSWeather {
    Try {
        If ($InjectionSettings.Settings.General.AirportICAO) {
            Write-Log "INFO" "Fetching TDS Weather for $AirportICAO..." $Log
            [xml]$script:weatherxml = Invoke-WebRequest "https://www.aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml&hoursBeforeNow=3&mostRecent=true&stationString=$AirportICAO" -UseBasicParsing
            $debugMETAR = $weatherxml.response.data.metar.raw_text
            Write-Log "INFO" "TDS METAR: $debugMETAR" $Log
        }
    } Catch {Write-Log "FATAL" "Weather fetching failed!" $Log}
}

Function GenerateWeather {
    # Setting wind speed from XML elseif TDS else null
    [int]$script:windSpeedGround = $null
    If ($InjectionSettings.Settings.Weather.WindGroundSpeedKts) {
        [int]$windSpeedGround = $InjectionSettings.Settings.Weather.WindGroundSpeedKts
    } Elseif ($weatherxml.Response.Data.Metar.wind_speed_kt) {
        [int]$windSpeedGround = $weatherxml.Response.Data.Metar.Wind_speed_kt
    }# Else {
    #    [int]$windSpeedGround = $null
    #}

    # Checking wind speeds against user constraints
    If ($InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts -and ($WindSpeedGround -gt $InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts)) {
        $WindSpeedGround = $InjectionSettings.Settings.Constraints.MaxWindSpeed_Kts
        Write-Log "WARN" "Wind speed higher than max allowed! Setting maximum wind speed allowed!" $Log
    }

    [int]$script:windDirGround = $null
    # Setting wind direction from XML elseif TDS else null
    If ($InjectionSettings.Settings.Weather.WindGroundDir) {
        [int]$windDirGround = $InjectionSettings.Settings.Weather.WindGroundDir
    } Elseif ($weatherxml.Response.Data.Metar.Wind_dir_degrees) {
        [int]$windDirGround = $weatherxml.Response.Data.Metar.Wind_dir_degrees
    }# Else {
    #    [int]$windDirGround = $null
    #}

    [int]$script:windSpeed2000 = $null
    # Setting upper winds speeds and direction
    If ($InjectionSettings.Settings.Weather.Wind2000SpeedKts) {
        [int]$windSpeed2000 = $InjectionSettings.Settings.Weather.Wind2000SpeedKts
    } Elseif ($windSpeedGround) {
        [int]$windSpeed2000 = $windSpeedGround/1 + (get-Random -Maximum 10 -Minimum 1)
    }# Else {
    #    [int]$windSpeed2000 = $null
    #}

    [int]$script:windDir2000 = $null
    If ($InjectionSettings.Settings.Weather.Wind2000Dir) {
        [int]$windDir2000 = $InjectionSettings.Settings.Weather.Wind2000Dir
    } Elseif ($windDirGround) {
        [int]$windDir2000 = $windDirGround/1 + (get-Random -Maximum 90 -Minimum 1)
    }# Else {
    #    [int]$windDir2000 = $null
    #}

    [int]$script:windSpeed8000 = $null
    If ($InjectionSettings.Settings.Weather.Wind8000SpeedKts) {
        [int]$windSpeed8000 = $InjectionSettings.Settings.Weather.Wind8000SpeedKts
    } Elseif ($windSpeedGround) {
        [int]$windSpeed8000 = $windSpeedGround/1 + (get-Random -Maximum 20 -Minimum 5)
    }# Else {
    #    [int]$windSpeed8000 = $null
    #}

    [int]$script:windDir8000 = $null
    If ($InjectionSettings.Settings.Weather.Wind8000Dir) {
        [int]$windDir8000 = $InjectionSettings.Settings.Weather.Wind8000Dir
    } Elseif ($windDirGround) {
        [int]$windDir8000 = $windDirGround/1 + (get-Random -Maximum 180 -Minimum 1)
    }# Else {
    #    [int]$windDir8000 = $null
    #}

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
    [int]$script:Turbulence = $null
    If ($InjectionSettings.Settings.Weather.Turbulence) {
        [int]$Turbulence = $InjectionSettings.Weather.Turbulence
    } Elseif ($windSpeedGround) {
        [int]$Turbulence = $windSpeedGround * 1.3
    }# Else {
    #    [int]$Turbulence = $null
    #}
    Write-Log "INFO" "Turbulence: $Turbulence" $Log

    # Setting Temperature if XML elseif TDS else null3
    [int]$script:temperature = $null
    If ($InjectionSettings.Settings.Weather.Temperature_C){
        [int]$temperature = $InjectionSettings.Settings.Weather.Temperature_C
    } Elseif ($weatherxml.Response.Data.Metar.Temp_c) {
        [int]$temperature = $weatherxml.Response.Data.Metar.Temp_c
    }# Else {
    #    [int]$temperature = $null
    #}
    Write-Log "INFO" "Temperature: $temperature C" $Log

    # Setting Temperature if XML elseif TDS else null
    $script:pressure = $null
    If ($InjectionSettings.Settings.Weather.Altimeter_InHG) {
        $pressure = $InjectionSettings.Settings.Weather.Altimeter_InHG
    } ElseIf ($weatherxml.Response.Data.Metar.altim_in_hg) {
        $pressure = $weatherxml.Response.Data.Metar.altim_in_hg/1
    }# Else {
    #    $pressure = $null
    #}
    If ($pressure) {$pressure = [math]::Round($pressure,2)}
    #If ($pressure) {$pressure = "{0:n2}" -f $pressure}
    Write-Log "INFO" "Pressure: $pressure inHG" $Log

    # Setting cloud coverage 
    [int]$script:cloudCoverage = -1
    If ($InjectionSettings.Settings.Weather.CloudCoverage) {
        [int]$cloudCoverage = $InjectionSettings.Settings.Weather.CloudCoverage
    } Elseif ($weatherxml.Response.Data.Metar.Sky_Condition.Sky_Cover) {
        Switch -Wildcard ($weatherxml.Response.Data.Metar.Sky_condition.Sky_Cover) {
        "*SKC*" {[int]$cloudCoverage = "0"}
        "*CLR*" {[int]$cloudCoverage = "0"}
        "*CAVOK*" {[int]$cloudCoverage = "0"}
        "*FEW*" {[int]$cloudCoverage = "4"}
        "*SCT*" {[int]$cloudCoverage = "6"}
        "*BKN*" {[int]$cloudCoverage = "8"}
        "*OVC*" {[int]$cloudCoverage = "10"}
        "*OVX*" {[int]$cloudCoverage = "10"}
        "*VV*" {[int]$cloudCoverage = "10"}
        default {$cloudCoverage = "2"}}
    }# Else {
    #    [int]$cloudCoverage = -1
    #}

    # Checking cloud coverage against user constraints
    If ($InjectionSettings.Settings.Constraints.MaxCloudCoverage -and ($cloudCoverage -gt $InjectionSettings.Settings.Constraints.MaxCloudCoverage)) {
        $cloudCoverage = $InjectionSettings.Settings.Constraints.MaxCloudCoverage
        Write-Log "WARN" "Cloud coverage higher than max allowed! Setting max allowed value!" $Log
    }
    Write-Log "INFO" "Cloud Cover: $cloudCoverage" $Log

    # Grabbing station height MSL, this will be used to calculate cloud height MSL as all clouds are reported as AGL.
    [int]$script:stationHeight = $weatherxml.Response.Data.Metar.Elevation_m/1 * $FeetToMeters

    # Setting cloud base if XML elseif TDS else null
    $script:cloudBaseMSL = $null
    If ($InjectionSettings.Settings.Weather.CloudBase_FtMSL) {
        $cloudBaseMSL = $InjectionSettings.Settings.Weather.CloudBase_FtMSL
    } Elseif ($weatherxml.Response.Data.Metar.Sky_condition.Cloud_base_ft_agl) {
        $cloudBaseMSL = $null
        $cloudBaseMSL = $weatherxml.Response.Data.Metar.Sky_condition.Cloud_base_ft_agl | Measure-Object -Maximum
        $cloudBaseMSL = $cloudBaseMSL.Maximum + $stationHeight
    }# Else {
    #    $cloudBaseMSL = $null
    #}

    # Generating cloud height
    [int]$script:cloudHeight = Get-Random -Maximum "6562" -Minimum "656"

    # Setting precipitation based on known descriptors
    [int]$script:Precipitation = $null
    If ($InjectionSettings.Settings.Weather.Precipitation) {
        [int]$Precipitation = $InjectionSettings.Settings.Weather.Precipitation
    } Elseif ($weatherxml.Response.Data.Metar.Wx_string) {
        Switch -wildcard ($weatherxml.Response.Data.Metar.Wx_string) {
        "*RA*" {[int]$Precipitation = "1"}
        "*TS*" {[int]$Precipitation = "2"}
        "*SN*" {[int]$Precipitation = "3"}
        "*FZ*" {[int]$Precipitation = "4"} #This is for snowstorm, but a snowstorm in DCS is just a thunderstorm with snow so I have nothing to equate this too really
        default {[int]$Precipitation = "0"}}
    }# Else {
    #    [int]$Precipitation = $null
    #}

    # Setting fog visibility if XML elseif TDS else null
    [int]$script:FogVisibility = $null
    If ($InjectionSettings.Settings.Weather.FogVisibility_NM) {
        [int]$FogVisibility = $InjectionSettings.Settings.Weather.FogVisibility_NM/1 * $NMtoFeet
    } Elseif ($weatherxml.Response.Data.Metar.Visibility_statute_mi/1 -le 3) {
        [int]$FogVisibility = $weatherxml.Response.Data.Metar.Visibility_statute_mi/1 * $NMtoFeet
    }# Else {
    #    [int]$FogVisibility = $null
    #}

    # Checking fog visibility against user constraints
    If ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 -and $FogVisibility -gt ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 * 6076)) {
        $FogVisibility = $InjectionSettings.Settings.Constraints.MinimumVisibility_NM * 6076
        Write-Log "WARN" "Fog Visibility lower than minimum allowed. Setting minimum allowed value!" $Log
    }

    # Setting fog thickness
    # If the cloud base is close to the max fox height, the cloud base and fog heights will be matched
    # Else, it will be randomly generated
    [int]$script:FogHeight = $null
    If ($InjectionSettings.Settings.Weather.FogThickness_Ft) {
        [int]$FogHeight = $InjectionSettings.Settings.Weather.FogThickness_Ft
    } Elseif ($cloudBaseMSL -lt 5281 -and $weatherxml.Response.Data.Metar.Visibility_statute_mi -le 3 -and $cloudCoverage -ge 8) {
        [int]$FogHeight = 3281
        $cloudBaseMSL = 3281
    } Elseif ($FogVisibility) {
        [int]$FogHeight = Get-Random -Maximum 3281 -Minimum 0
    }# Else {
    #    [int]$FogHeight = $null
    #}

    Write-Log "INFO" "Cloud Base: $cloudBaseMSL Ft" $Log
    Write-Log "INFO" "Cloud Height: $cloudHeight Ft" $Log
    Write-Log "INFO" "Precipitation: $Precipitation" $Log

    Write-Log "INFO" "Fog Visibility: $FogVisibility Ft" $Log
    Write-Log "INFO" "Fog Height: $FogHeight Ft" $Log

    $script:Obscuration = $False
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

    # Setting dust visibility if XML elseif TDS elseif Random else null
    [int]$script:DustVisibility = $null
    If ($InjectionSettings.Settings.Weather.DustVisibility_Ft) {
        [int]$DustVisibility = $InjectionSettings.Settings.Weather.DustVisibility_Ft
    } Elseif ($Obscuration -eq $True -and $weatherxml.Response.Data.Metar.visibility_statute_mi -le 1.5) {
        [int]$DustVisibility = $weatherxml.Response.Data.Metar.Visibility_statute_mi/1 * 6076
    } Elseif ($Obscuration -eq $True) {
        [int]$DustVisibility = Get-Random -Maximum 9843 -Minimum 984
    }# Else {
    #    [int]$DustVisibility = $null
    #}
    Write-Log "INFO" "Dust Visibility: $DustVisibility Ft" $Log

    #Checking dust visibility against user constraints
    If ($DustVisibility -gt ($InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 * 6076)) {
        $DustVisibility = $InjectionSettings.Settings.Constraints.MinimumVisibility_NM/1 * 6076
        Write-Log "WARN" "Dust Visibility greater than allowed! Setting max allowed value!" $Log
    }

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
}