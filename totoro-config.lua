-- totoro-config.lua
--
-- Configuration of WiFi parameters, MetOffice weather location

local _M = {}

-- SSID and WPA2 password for WiFi network

_M.SSID = ""
_M.PASS = ""

-- The location to get weather for and the MetOffice API key
--
-- To get a KEY visit http://www.metoffice.gov.uk/datapoint and
-- register. See also http://www.metoffice.gov.uk/datapoint/api

_M.LOCATION = ""
_M.KEY = ""

return _M
