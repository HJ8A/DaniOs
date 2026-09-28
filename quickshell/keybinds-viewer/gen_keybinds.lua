-- Generates a JSON array of {key, label, category} by reading the actual
-- merged variables (variables.lua + hypr-vars.lua overrides), the same way
-- hyprland.lua itself does. This stays dynamic: if a keybind variable is
-- remapped, this picks up the new key automatically. The category/label
-- text is maintained here (variable names rarely change upstream).

local home = os.getenv("HOME")
package.path = package.path
    .. ";" .. home .. "/.config/caelestia/?.lua"
    .. ";" .. home .. "/.local/share/caelestia/hypr/?.lua"

local vars = require("variables")
local ok, overrides = pcall(require, "hypr-vars")
if ok and type(overrides) == "table" then
    for k, v in pairs(overrides) do
        vars[k] = v
    end
end

-- category, label per variable name
local MAP = {
    -- Apps
    kbTerminal         = { "Apps", "Terminal" },
    kbBrowser          = { "Apps", "Browser" },
    kbEditor           = { "Apps", "Editor" },
    kbFileExplorer     = { "Apps", "File explorer" },
    kbAudioSettings    = { "Apps", "Ajustes de audio" },

    -- Shell
    kbLauncher         = { "Shell", "Launcher (tap)" },
    kbSession          = { "Shell", "Session panel" },
    kbShowSidebar      = { "Shell", "Sidebar" },
    kbClearNotifs      = { "Shell", "Limpiar notificaciones" },
    kbShowPanels       = { "Shell", "Mostrar todos los paneles" },
    kbLock             = { "Shell", "Bloquear pantalla" },
    kbRestoreLock      = { "Shell", "Restaurar bloqueo" },
    kbSleep            = { "Shell", "Suspender (suspend-then-hibernate)" },

    -- Ventanas
    kbWindowCycleNext          = { "Ventanas", "Ciclar siguiente ventana" },
    kbWindowCyclePrev          = { "Ventanas", "Ciclar anterior ventana" },
    kbWindowDecreaseWidth      = { "Ventanas", "Reducir ancho" },
    kbWindowIncreaseWidth      = { "Ventanas", "Aumentar ancho" },
    kbWindowDecreaseHeight     = { "Ventanas", "Reducir alto" },
    kbWindowIncreaseHeight     = { "Ventanas", "Aumentar alto" },
    kbMoveWindow               = { "Ventanas", "Mover ventana (teclado)" },
    kbResizeWindow             = { "Ventanas", "Redimensionar ventana (teclado)" },
    kbCenterWindow             = { "Ventanas", "Centrar ventana" },
    kbNormalizeWindow          = { "Ventanas", "Centrar + resize 55%x70%" },
    kbWindowPip                = { "Ventanas", "Picture-in-picture" },
    kbPinWindow                = { "Ventanas", "Pin ventana" },
    kbWindowFullscreen         = { "Ventanas", "Fullscreen" },
    kbWindowBorderedFullscreen = { "Ventanas", "Fullscreen con bordes (maximized)" },
    kbToggleWindowFloating     = { "Ventanas", "Toggle floating" },
    kbCloseWindow              = { "Ventanas", "Cerrar ventana" },

    -- Grupos
    kbUngroup              = { "Grupos", "Sacar ventana del grupo" },
    kbToggleGroup          = { "Grupos", "Crear/alternar grupo" },
    kbGroupLockActive      = { "Grupos", "Bloquear grupo activo" },
    kbWindowGroupCycleNext = { "Grupos", "Ciclar siguiente en el grupo" },
    kbWindowGroupCyclePrev = { "Grupos", "Ciclar anterior en el grupo" },

    -- Workspaces
    kbNextWs               = { "Workspaces", "Workspace siguiente" },
    kbPrevWs               = { "Workspaces", "Workspace anterior" },
    kbNextWsGroup          = { "Workspaces", "Grupo de workspaces siguiente" },
    kbPrevWsGroup          = { "Workspaces", "Grupo de workspaces anterior" },
    kbMoveWinToWsNext      = { "Workspaces", "Mover ventana a workspace siguiente" },
    kbMoveWinToWsPrev      = { "Workspaces", "Mover ventana a workspace anterior" },
    kbMoveWinToWsSpecial   = { "Workspaces", "Mover ventana a special workspace" },
    kbMoveWinFromWsSpecial = { "Workspaces", "Sacar ventana de special workspace" },

    -- Especiales
    kbSpecialWs       = { "Especiales", "Toggle special workspace" },
    kbSystemMonitorWs = { "Especiales", "Monitor del sistema (btop)" },
    kbMusicWs         = { "Especiales", "Música" },
    kbCommunicationWs = { "Especiales", "Comunicación" },
    kbTodoWs          = { "Especiales", "Todo" },

    -- Screenshots
    kbScreenshot       = { "Screenshots", "Captura -> Swappy" },
    kbScreenshotFreeze = { "Screenshots", "Captura congelada" },
    kbScreenshotRegion = { "Screenshots", "Captura de región" },
    kbRecord           = { "Screenshots", "Grabar pantalla" },
    kbRecordSound      = { "Screenshots", "Grabar pantalla + audio" },
    kbRecordRegion     = { "Screenshots", "Grabar región" },
    kbColorPicker      = { "Screenshots", "Color picker" },

    -- Media
    kbMediaToggle = { "Media", "Play/Pause" },
    kbMediaNext   = { "Media", "Siguiente canción" },
    kbMediaPrev   = { "Media", "Canción anterior" },
    kbMediaStop   = { "Media", "Detener" },
    kbVolumeMute  = { "Media", "Mute audio" },

    -- Sistema
    kbClipboard            = { "Sistema", "Historial de portapapeles" },
    kbClipboardDel         = { "Sistema", "Borrar del portapapeles" },
    kbClipboardPasteLatest = { "Sistema", "Pegar el último item copiado" },
    kbEmoji                = { "Sistema", "Emoji picker" },
}

local rows = {}

local function add(key, category, label)
    if type(key) == "table" then
        for _, k in ipairs(key) do
            rows[#rows + 1] = { key = k, category = category, label = label }
        end
    elseif type(key) == "string" and key ~= "" then
        rows[#rows + 1] = { key = key, category = category, label = label }
    end
end

for varName, info in pairs(MAP) do
    add(vars[varName], info[1], info[2])
end

-- Modifier-only vars combined with 1-9, 0
local function add_digits(varName, category, label)
    local mod = vars[varName]
    if type(mod) ~= "string" or mod == "" then return end
    for i = 1, 9 do
        add(mod .. " + " .. i, category, label .. " " .. i)
    end
    add(mod .. " + 0", category, label .. " 10")
end

add_digits("kbGoToWs", "Workspaces", "Ir al workspace")
add_digits("kbMoveWinToWs", "Workspaces", "Mover ventana al workspace")
add_digits("kbGoToWsGroup", "Workspaces", "Ir al grupo de workspaces")
add_digits("kbMoveWinToWsGroup", "Workspaces", "Mover ventana al grupo de workspaces")

-- JSON output (manual, no library needed for this simple flat structure)
local function jsonstr(s)
    return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local parts = {}
for _, r in ipairs(rows) do
    parts[#parts + 1] = string.format('{"key":%s,"category":%s,"label":%s}',
        jsonstr(r.key), jsonstr(r.category), jsonstr(r.label))
end

print("[" .. table.concat(parts, ",") .. "]")
