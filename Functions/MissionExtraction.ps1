Function FindMission {
    If ($InjectionSettings.Settings.Setup.Mission) {
        If (Test-Path $Mission) {
            $script:miz = $Mission
            Write-Log "INFO" "Fetched Mission: $miz" $Log
        }
    } Elseif (Test-Path (Join-Path -path $SavedGamesFolder -childPath "Config\serverSettings.lua")) {
        Write-Log "INFO" "Found Saved Games Folder: $SavedGamesFolder" $Log
        $serverConfigLocation = Join-Path -Path $SavedGamesFolder -ChildPath "Config\serverSettings.lua"
        $serverConfig = Get-Content $serverConfigLocation
        If($serverConfig) {Write-Log "INFO" "Found Server Config: $serverConfigLocation" $Log}
        $script:miz = $ServerConfig[(GetSettingsElement(".miz"))]|%{$_.split('"')[1]}
        Write-Log "INFO" "Fetched Mission: $miz" $Log
    }
}

Function UnzipMiz {
    Write-Log "INFO" "Unzipping miz..." $Log
    Try {
        # Gets the latest modified mission in the mission folder.
        $miz | Rename-Item -NewName {$miz -replace ".miz",".zip"} -PassThru |  Set-Variable -Name Mizzip # Renaming it to a .zip.
        Get-ChildItem -Path $mizzip | Expand-Archive -DestinationPath "./TempMiz" -Force # Extracting it into ./TempMiz for editing.
        $script:mission = Get-Content ./TempMiz/mission # Finally getting the contents of the mission.
        $script:mizzip = $mizzip.fullname
    } Catch {Write-Log "FATAL" "Mission extraction failed!" $Log}
}

Function ZipMiz {
    Write-Log "INFO" "Zipping miz..." $Log
    Try {
        Compress-Archive -Path "./TempMiz/mission" -Update -DestinationPath $mizzip
        $mizzip | Rename-Item -NewName {$mizzip -replace ".zip",".miz"} -Force # Renaming it to a .zip.
        Remove-Item "./TempMiz" -Recurse -Force
    } Catch {Write-Log "FATAL" "Zipping failed!" $Log}
}