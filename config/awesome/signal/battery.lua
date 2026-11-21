local awful = require "awful"
local gobject = require "gears.object"
local gtable = require "gears.table"
local gtimer = require "gears.timer"
local wbase = require "wibox.widget.base"
local UPower = require("lgi").require "UPowerGlib"

local upower = {}
local instance = nil

-- Devuelve la lista de dispositivos UPower, o nil si el demonio no
-- responde. Sin este pcall, un fallo de D-Bus/UPower tumba toda la
-- configuración de Awesome al arrancar.
local function safe_get_devices()
  local ok, devices = pcall(function()
    return UPower.Client():get_devices()
  end)
  if not ok or devices == nil then
    return nil
  end
  return devices
end

function upower.list_devices()
  local ret = {}
  local devices = safe_get_devices()
  if not devices then
    return ret
  end

  for _, device in ipairs(devices) do
    table.insert(ret, device:get_object_path())
  end

  return ret
end

function upower.get_device(path)
  local devices = safe_get_devices()
  if not devices then
    return nil
  end

  for _, device in ipairs(devices) do
    if device:get_object_path() == path then
      return device
    end
  end

  return nil
end

function upower.attach_to_device(args)
  args = gtable.crush({
    widget_template = wbase.empty_widget(),
    device_path = "",
    use_display_device = false,
  }, args or {})

  local widget = wbase.make_widget_from_value(args.widget_template)

  -- Resolver el dispositivo con pcall: si el path no existe (p. ej. una
  -- PC de escritorio sin batería) get_device devuelve nil y la línea
  -- widget.device.on_notify tronaba con "attempt to index a nil value",
  -- tumbando todo Awesome. Sin dispositivo, simplemente no se conecta nada.
  local ok, device = pcall(function()
    return args.use_display_device and UPower.Client():get_display_device()
      or upower.get_device(args.device_path)
  end)
  widget.device = ok and device or nil

  if not widget.device then
    return widget
  end

  widget.device.on_notify = function(d)
    widget:emit_signal("upower::update", d)
  end

  if args.instant_update then
    gtimer.delayed_call(widget.emit_signal, widget, "upower::update", widget.device)
  end

  return widget
end

local function new()
  local ret = gobject {}
  gtable.crush(ret, upower, true)

  if safe_get_devices() == nil then
    ret:emit_signal "no_devices"
  else
    awful.spawn.easy_async_with_shell("echo $(upower -e | grep 'BAT' | head -n 1)", function(stdout)
      local device = stdout:gsub("\n", "")
      if device == "" then
        ret:emit_signal "no_devices"
      else
        ret:emit_signal("raw_devices", device)
        ret
          .attach_to_device({
            device_path = stdout:gsub("\n", ""),
            instant_update = true,
          })
          :connect_signal("upower::update", function(_, device)
            local time_to_empty = device.time_to_empty / 60
            local time_to_full = device.time_to_full / 60
            ret:emit_signal(
              "update",
              tonumber(string.format("%.0f", device.percentage)),
              device.state,
              tonumber(string.format("%.0f", time_to_empty)),
              tonumber(string.format("%.0f", time_to_full)),
              device.battery_level
            )
          end)
      end
    end)
  end

  return ret
end

if not instance then
  instance = new()
end
return instance
