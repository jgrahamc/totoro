-- dummy.lua
--
-- Dummy module used for test stubbing so that its possible to run
-- the code through the lua interpreter to check syntax before 
-- upload

local _M = {}

-- Dummy wifi

function capture(cmd)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  return string.gsub(s, '[\n\r]+', ' ')
end

function _M.setmode(a)
end
_M.sta = { config = function(a) end,
           connect = function() end,
           getip = function(a) return capture("ipconfig getifaddr en0") end }

-- Dummy http

function _M.get(url, x, f)
    local b = capture("curl -s \"" .. url .. "\"")
    f(200, b)
end

-- Dummy tmr

_M.tmrs = {}

socket = require("socket")
function _M.delay(a)
    socket.sleep(a/1000)
end
function _M.alarm(a, b, c, f)
    _M.tmrs["x" .. a] = {cadence=b/100, callback=f, countdown=b/100}
end
function _M.stop(a)
   _M.tmrs["x" .. a] = {}
end
function _M.run(t0)
   local runnable
   repeat
      _M.delay(100)
      runnable = false
      for i, t in pairs(_M.tmrs) do
         if _M.tmrs[i].cadence ~= nil then
             if i == "x" .. t0 then runnable = true end
             _M.tmrs[i].countdown = _M.tmrs[i].countdown - 1
             if _M.tmrs[i].countdown == 0 then
                _M.tmrs[i].callback()
                _M.tmrs[i].countdown = _M.tmrs[i].cadence
             end
         end
      end
   until runnable == false
end

-- Dummy cjson

local cjson = require("cjson")

function _M.decode(x)
   return cjson.decode(x)
end

-- Dummy ws2812

function _M.init()
end
function _M.write(s)
   local r = '('
   for i = 1, #s do
      local c = s:sub(i,i)
	  r = r .. string.format("%02x", string.byte(c))
     if i == 3 then r = r .. ")(" end
   end
   io.write("\x1b[2J\x1b[1;1H" .. r .. ")\n")
   io.flush()
end

-- Dummy node

function _M.restart()
end


return _M
