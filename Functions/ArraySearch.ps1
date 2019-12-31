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