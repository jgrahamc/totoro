-- init.lua
--
-- Run the Totoro program after a short delay (see 
-- https://nodemcu.readthedocs.io/en/master/en/lua-developer-faq/#how-do-i-avoid-a-panic-loop-in-initlua for why)
--
-- Copyright (c) 2017 John Graham-Cumming

local tmr = require("dummy") -- TEST_ONLY

tmr.alarm(3, 5000, tmr.ALARM_SINGLE, function()
   local totoro = require("totoro")
end)

tmr.run(3) -- TEST_ONLY
