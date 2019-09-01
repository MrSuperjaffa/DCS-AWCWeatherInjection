
# AWCWeatherInjection for Windows & DCS World
Version 0.6.0 by Mr_Superjaffa#5430

The goal of this project is to provide weather and time injection to DCS World missions using Aviation Weather Centre's Text Data Service.

![Main Image](docs/images/img1.png)

#### Requirements
1. Powershell 5.0 or Higher.
2. DCS World 2.5.5 or Higher.

#### Install:
1. Extract the zip contents into any folder.
2. Open up `WeatherInjectionSettings.xml` and configure it to your liking.
3. Run it via the `AWCWeatherInjectionStart.bat`.

#### Usage:

Use the `AWCWeatherInjectionStart.bat` for automated starts.

The script grabs data from AWC's Text Data Service. You can see an example here: [AWC TDS](https://www.aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml&hoursBeforeNow=3&mostRecent=true&stationString=OMDB). Additionaly, the script will search your `serverConfig.lua` for the first active mission and use that. Specifying a mission in the config will override this function.

Placing a value in the `WEATHER` and `TIME` section of the config will override any real world values.
Ex. `<WindGroundDir>230</WindGroundDir>`
This will force the ground winds to 230 degrees. Wind speed will remain unaffected, as will the generation of upper winds.

Use the constraints section to make sure weather doesn't get too extreme.

#### Uninstall
1. Simply delete it.

#### Limitations

1. The script will only grab the first mission in the `serverConfig.lua`.
