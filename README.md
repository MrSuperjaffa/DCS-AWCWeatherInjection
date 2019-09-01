
# AWCWeatherInjection for Windows & DCS World
Version 0.6.0 by Mr_Superjaffa#5430

The goal of this project is to provide weather and time injection to DCS World missions using Aviation Weather Centre's Text Data Service.

#### Requirements
1. Powershell 5.0 or Higher.
2. DCS World 2.5.5 or Higher.

#### Install:
1. Extract the zip contents into any folder.
2. Open up `WeatherInjectionSettings.xml` and configure it to your liking.
3. Run it via the `AWCWeatherInjectionStart.bat`.

#### Usage:

The script grabs data from AWC's Text Data Service. You can see an example here: [AWC TDS](https://www.aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml&hoursBeforeNow=3&mostRecent=true&stationString=OMDB). Additionaly, the script will search your `serverConfig.lua` for the first active mission and use that. Specifying a mission in the config will override this function.

#### Uninstall
1. Simply delete it.

#### Limitations

1. GPU data is system wide, not application specific. Everything else is fine.
