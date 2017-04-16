-- totoro.lua
--
-- Small program to get the weather forecast for a location and turn
-- on two LEDs that will illuminate Totoro's umbrella if it is going to
-- rain, hail or snow within the next 6 hours.
--
-- Copyright (c) 2017 John Graham-Cumming

local config = require("totoro-config")

-- This is only used when running 'make check' and these lines are
-- removed by 'make upload'

local dummy = require("dummy") -- TEST_ONLY
local wifi = dummy -- TEST_ONLY
local http = dummy -- TEST_ONLY
local tmr = dummy -- TEST_ONLY
local cjson = dummy -- TEST_ONLY
local ws2812 = dummy -- TEST_ONLY

-- The LED strip used takes the colors in the order (G, R, B)

local red = string.char(0, 255, 0)
local blue = string.char(0, 0, 255)
local green = string.char(255, 0, 0)
local yellow = string.char(255, 255, 0)
local white = string.char(255, 255, 255)
local black = string.char(0, 0, 0)

-- connectWifi connects to the WiFi network defined above as a station
-- This will try to connect for 30 seconds and then give up
function connectWifi()
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

local api = "http://datapoint.metoffice.gov.uk/public/data/val/wxfcs/all/json/"

-- setLED sets the appropriate LED color on the two LEDs
function setLED(c)
  ws2812.write(c .. c)
end

local color = {black, black}
local current

-- led sets the two LED colors that will illuminate the umbrella
function led(c0, c1) 
   color[1] = c0
   color[2] = c1
   current = 0
   setLED(color[current+1])
end

-- update sets the LED to the current value and swaps the value for the
-- next update
function update() 
   if color[0] == color[1] then return end

   setLED(color[current+1])
   current = 1 - current
end

-- getForecast calls the MetOffice API for the defined location and then calls
-- setUmbrella with the JSON response or error code
function getForecast()
   led(green, black)
   http.get(api .. config.LOCATION .. "?res=3hourly&key=" .. config.KEY, nil, setUmbrella)
end

-- setUmbrella reads the JSON response from the API and extracts the weather for the
-- next 6 hours and updates the umbrella LED colors
function setUmbrella(code, data)
   print(code, data)
   if code == 200 then
      local ok, p = pcall(cjson.decode, data)
      if ok and p ~= nil then
         local siterep = p.SiteRep
         if siterep == nil then return end
         local dv = siterep.DV
         if dv == nil then return end
         local loc = dv.Location
         if loc == nil then return end
         local period = loc.Period
         if period == nil then return end

         -- Extract the weather for each forecast three hour window
         -- by building a table and sorting it. 
         --
         -- A single Period item looks like this:
         --
         -- {"type": "Day",
         --  "Rep":  [{"F":"10","Pp":"6","T":"12","V":"GO","H":"75","U":"0",
         --            "G":"13","W":"7","$":"1080","D":"WSW","S":"9"},
         --           {"T":"9","V":"MO","H":"92","U":"0","F":"7","Pp":"5",
         --            "W":"7","$":"1260","D":"WSW","S":"4","G":"13"}],
         --   "value":"2017-03-08Z"}
         --
         -- This will turn into two entries in the t table as follows. The Key
         -- can be sorted just using table.sort()
         --
         -- Key                 Value
         -- ---                 -----
         -- 2017-03-08Z1800     7
         -- 2017-03-08Z2100     7

         local t = {}
         for unused0, p in ipairs(period) do
            if p.value ~= nil and p.Rep ~= nil then
               for unused1, r in ipairs(p.Rep) do
                  t[p.value .. string.format("%02d00", r["$"]/60)] = r.W
               end
            end
         end

         local keys = {}
         for d in pairs(t) do table.insert(keys, d) end
         table.sort(keys)

         -- To get the next six hours just need the first two forecasts. The weather
         -- values we look for are:
         --
         -- Type            API Response                        Weather Priority
         -- ----            ------------                        ----------------
         -- Heavy rain:    13, 14, 15, 28, 29                   0
         -- Hail:          19, 20, 21                           1
         -- Light rain:     9, 10, 11, 12                       2
         -- Sleet or snow: 16, 17, 18, 22, 23, 24, 25, 26, 27   3
         -- Sun:           1                                    4
         
         -- Note because Lua arrays actually start at one looking up in this array is done by adding
         -- 1 to the weather code returned by the Met Office.
         --             0,   1    2    3    4    5    6    7    8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 
         local pri = {nil,   4, nil, nil, nil, nil, nil, nil, nil, 2, 2, 2, 2, 0, 0, 0, 3, 3, 3, 1, 1, 1, 3, 3, 3, 3, 3, 3, 0, 0}

         local p
         if keys[1] ~= nil then p = pri[t[keys[1]]+1] end
         if keys[2] ~= nil and pri[t[keys[2]]+1] ~= nil then
            if p == nil or pri[t[keys[2]]+1] < p then p = pri[t[keys[2]]+1] end
         end

         if     p == 0 then led(red, red)
         elseif p == 1 then led(white, black)
         elseif p == 2 then led(blue, blue)
         elseif p == 3 then led(white, white)
         elseif p == 4 then led(yellow, yellow)
         else led(black, black)
         end
         return
      end
   end

   -- If there's an API failure of some sort flash red/blue

   led(red, blue)
end

-- Connect to WiFi and then every 30 minutes get the latest weather forecast

ws2812.init()
tmr.alarm(0, 500, tmr.ALARM_AUTO, update)

connectWifi()

getForecast()
tmr.alarm(2, 1*60*1000, tmr.ALARM_AUTO, getForecast)

dummy.run(0) -- TEST_ONLY
