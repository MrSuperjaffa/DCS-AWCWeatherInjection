Function MissionExport {
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
        $mission[(GetMissionElement("`"fog`"")) + 2] = @"
            ["thickness"] = 0,
"@
        $mission[(GetMissionElement("`"fog`"")) + 3] = @"
            ["visibility"] = 0,
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
        $mission[(GetMissionElement("dust_density"))] = @"
        ["dust_density"] = 0,
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

    # Exporting mission year.
    Try {
    If ($mission[(GetMissionElement("Year"))] -match "Year" -and $Year) {
        $mission[(GetMissionElement("Year"))] = @"
        ["Year"] = $Year,
"@
        Write-Log "INFO" "Exported Year." $Log
    }} Catch {Write-Log "ERROR" "Year export failed!" $Log}

    # Exporting mission day.
    Try {
    If ($mission[(GetMissionElement("Day"))] -match "Day" -and $Day) {
        $mission[(GetMissionElement("Day"))] = @"
        ["Day"] = $Day,
"@
        Write-Log "INFO" "Exported Day." $Log
    }} Catch {Write-Log "ERROR" "Day export failed!" $Log}

    # Exporting mission month.
    Try {
    If ($mission[(GetMissionElement("Month"))] -match "Month" -and $Month) {
        $mission[(GetMissionElement("Month"))] = @"
        ["Month"] = $Month,
"@
        Write-Log "INFO" "Exported Month." $Log
    }} Catch {Write-Log "ERROR" "Month export failed!" $Log}

    # Exporting mission start time.
    Try {
        If ($mission[(GetMissionElement("currentKey")) + 1] -match "start_time" -and $TimeSeconds) {
        $mission[(GetMissionElement("currentKey")) + 1] = @"
    ["start_time"] = $TimeSeconds,
"@
        Write-Log "INFO" "Exported Start Time." $Log
    }} Catch {Write-Log "ERROR" "Start Time export failed!" $Log}

    Try {Set-Content -Path "./TempMiz/mission" -Value $mission -Force} Catch {Write-Log "FATAL" "Mission export failed!"}
    Write-Log "INFO" "Finished Export." $Log
}