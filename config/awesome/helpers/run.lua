local awful = require("awful")

local tostring = tostring
local string = string
local ipairs = ipairs
local math = math
local os = os

local _run = {}

function _run.run_once_pgrep(cmd)
	local findme = cmd
	local firstspace = cmd:find(" ")
	if firstspace then
		findme = cmd:sub(0, firstspace - 1)
	end
	-- `easy_async_with_shell` exige un callback: sin él, al terminar el
	-- comando Awesome truena en awful/spawn.lua:459 con
	-- "attempt to call a nil value (upvalue 'callback')". Esto salía en
	-- cada arranque del log (autostart llama a run_once_pgrep para mpd
	-- y mpDris2). El callback vacío no cambia el comportamiento: el
	-- shell ya arranca la app si pgrep no la encuentra.
	awful.spawn.easy_async_with_shell(string.format("pgrep -u $USER -x %s > /dev/null || (%s)", findme, cmd), function() end)
end

function _run.run_once_ps(findme, cmd)
	awful.spawn.easy_async_with_shell(string.format("ps -C %s|wc -l", findme), function(stdout)
		if tonumber(stdout) ~= 2 then
			awful.spawn(cmd, false)
		end
	end)
end

function _run.run_once_grep(command)
	awful.spawn.easy_async_with_shell(string.format("ps aux | grep '%s' | grep -v 'grep'", command), function(stdout)
		if stdout == "" or stdout == nil then
			awful.spawn(command, false)
		end
	end)
end

function _run.check_if_running(command, running_callback, not_running_callback)
	awful.spawn.easy_async_with_shell(string.format("ps aux | grep '%s' | grep -v 'grep'", command), function(stdout)
		if stdout == "" or stdout == nil then
			if not_running_callback ~= nil then
				not_running_callback()
			end
		else
			if running_callback ~= nil then
				running_callback()
			end
		end
	end)
end

return _run
