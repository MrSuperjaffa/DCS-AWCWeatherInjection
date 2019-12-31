Function ConvertTime {
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
}