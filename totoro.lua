-- totoro.lua
--
-- Small program to get the weather forecast for a location and turn
-- on two LEDs that will illuminate Totoro's eyes if it is going to
-- rain, hail or snow today
--
-- Copyright (c) 2017-2022 John Graham-Cumming

local config = require("totoro-config")

-- This is only used when running 'make check' and these lines are
-- removed by 'make upload'

local dummy = require("dummy") -- TEST_ONLY
local wifi = dummy -- TEST_ONLY
local http = dummy -- TEST_ONLY
local tmr = dummy -- TEST_ONLY
local cjson = dummy -- TEST_ONLY
local ws2812 = dummy -- TEST_ONLY
local node = dummy -- TEST_ONLY

-- The LED strip used takes the colors in the order (G, R, B)

local red = string.char(0, 255, 0)
local blue = string.char(0, 0, 255)
local green = string.char(255, 0, 0)
local yellow = string.char(255, 255, 0)
local white = string.char(255, 255, 255)
local black = string.char(0, 0, 0)

-- Count of number of getForecast failures

local failures = 0

-- setLED sets the appropriate LED color on the two LEDs
local function setLED(c)
  ws2812.write(c .. c)
end

local color = {black, black}
local current

-- led sets the two LED colors that will illuminate the eyes
local function led(c0, c1) 
   color[1] = c0
   color[2] = c1
   current = 0
   setLED(color[current+1])
end

-- connectWifi connects to the WiFi network defined above as a station
-- This will try to connect for 30 seconds and then give up
local function connectWifi()
   led(yellow, black)
   wifi.setmode(wifi.STATION)

   local cfg = {}
   cfg.ssid = config.SSID
   cfg.pwd  = config.PASS
   wifi.sta.config(cfg)

   wifi.sta.connect()

   local i = 30

   tmr.alarm(1, 1000, tmr.ALARM_AUTO, function()
      if wifi.sta.getip() ~= nil then
         tmr.stop(1)
      else
         i = i - 1
         if i == 0 then
            tmr.stop(1)
        end
      end
   end)

   dummy.run(1) -- TEST_ONLY

   return i == 0
end

local api = "http://api.ipma.pt/open-data/forecast/meteorology/cities/daily/hp-daily-forecast-day0.json"

-- update sets the LED to the current value and swaps the value for
-- the next update
local function update() 
   if color[0] == color[1] then return end

   setLED(color[current+1])
   current = 1 - current
end

-- setEyes reads the JSON response from the API and extracts the
-- weather for the day and updates the eye LED colors
local function setEyes(code, data)
   if code == 200 then
      local ok, p = pcall(cjson.decode, data)
      if ok and p ~= nil then
         if p.data == nil then return end

         -- Extract the weather for the city we want
         --
         -- A single data point looks like this
         --
         -- {
            --   "precipitaProb": "3.0", 
            --   "tMin": 8, 
            --   "tMax": 18, 
            --   "predWindDir": "NW", 
            --   "idWeatherType": 2, 
            --   "classWindSpeed": 1, 
            --   "longitude": "-9.1286", 
            --   "globalIdLocal": 1110600, 
            --   "latitude": "38.7660"
           -- } 
         --

         for _, c in ipairs(p.data) do
            if c.globalIdLocal == config.IPMA then

               -- Once the city has been found it's just a matter of
               -- translating the weather type to a simplified weather
               -- type displayable by Totoro values we look for are:
               --
               -- Type            API Response          Weather
               -- ----            ------------          -------
               -- Heavy rain:     8, 9, 11, 14          0
               -- Hail:           21                    1
               -- Light rain:     6, 7, 10, 12, 13, 15  2
               -- Sleet or snow:  18                    3
               -- Sun:            1, 2, 3               4
               -- Thunder:        19, 20, 23            5
         
               -- Note because Lua arrays actually start at one looking
               -- up in this array is done by adding 1 to the weather
               -- code returned by IPMA
               --               
               --                 0, 1  2  3    4    5  6  7  8  9 10 11 12 13 14 15   16   17 18 19 20 21   22 23   24   25   26   27   28   29 
               local weather = {nil, 4, 4, 4, nil, nil, 2, 2, 0, 0, 2, 0, 2, 2, 0, 2, nil, nil, 3, 5, 5, 1, nil, 5, nil, nil, nil, nil, nil, nil}

               p = weather[c.idWeatherType+1]

               if     p == 0 then led(red, red)
               elseif p == 1 then led(white, black)
               elseif p == 2 then led(blue, blue)
               elseif p == 3 then led(white, white)
               elseif p == 4 then led(yellow, yellow)
               elseif p == 5 then led(white, red)
               else led(black, black)
               end

               failures = 0
               return
            end
         end
      end
   end

   -- If there's an API failure of some sort flash red/blue

   failures = failures + 1
   led(red, blue)
end

-- getForecast calls the IMPA API for the defined location and then calls
-- setEyes with the JSON response or error code
local function getForecast()
   led(green, black)
   http.get(api, nil, setEyes)
end

-- watchdog resets Totoro if there hasn't been a successful forecast for
-- five minutes
local function watchdog()
   if failures == 5 then
      node.restart()
   end
end

-- Connect to WiFi and then every minute get the latest weather forecast

ws2812.init()
tmr.alarm(0, 500, tmr.ALARM_AUTO, update)

connectWifi()

tmr.alarm(2, 1*60*1000, tmr.ALARM_AUTO, watchdog)
tmr.alarm(3, 1*60*1000, tmr.ALARM_AUTO, getForecast)

dummy.run(0) -- TEST_ONLY
