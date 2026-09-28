local home = os.getenv("HOME")
package.path = package.path
    .. ";" .. home .. "/.config/caelestia/?.lua"
    .. ";" .. home .. "/.local/share/caelestia/hypr/?.lua"

local vars = require("variables")

local ok, overrides = pcall(require, "hypr-vars")
if ok and type(overrides) == "table" and overrides.windowOpacity then
    print(overrides.windowOpacity)
else
    print(vars.windowOpacity)
end
