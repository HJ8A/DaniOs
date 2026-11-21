-- Phantomat × Caelestia — escritorio infinito con switch de modos.
--
-- Basado en examples/spatialoverview.lua de kaolti/phantomat (pensado para
-- Omarchy), adaptado a Caelestia. Docs: vault EverSystemOs →
-- 02-PROYECTOS/Activos/Phantomat - Escritorio Infinito.
--
--   SUPER + CTRL + I   switch: Modo Caelestia (mosaico) ↔ Modo Infinito (lienzo)
--   SUPER + CTRL + G   (infinito) mapa alejado + buscar ↔ vista normal
--   SUPER + T          (infinito) la ventana llena la pantalla con margen / vuelve
--   SUPER + O          (infinito) fijar ventana a la pantalla / devolverla al lienzo
--
-- Cada atajo redefinido aquí hace en Modo Caelestia EXACTAMENTE lo que hace hoy
-- (mismos dispatchers que hyprland/keybinds.lua y hypr-user.lua). La sesión
-- arranca siempre en Modo Caelestia: el lienzo solo se abre con el switch.
--
-- Edita y corre `hyprctl reload`, o ajusta el look en vivo con CTRL + , en el
-- mapa (se guarda en spatialoverview-tuning.lua, que gana sobre esto).

local loaded = false
for _, plugin in ipairs(hl.get_loaded_plugins()) do
  if plugin.name == "spatialoverview" then
    loaded = true
    break
  end
end
-- Sin el plugin (p. ej. tras un update de Hyprland, antes de recompilar) no se
-- aplica nada: Modo Caelestia queda intacto.
if not loaded then
  return
end

local home = os.getenv("HOME")
local mode_script = home .. "/.config/phantomat/phantomat-mode.sh"
local SO = hl.plugin.spatialoverview
local fn = require("utils.functions") -- el mismo módulo que usa keybinds.lua de Caelestia

hl.config({
  plugin = {
    spatialoverview = {
      layout = "grid",
      scale = 0.36,
      workspace_gap = 0,
      grid = { columns = 3, stagger = 0.0 },

      input = {
        pan_sensitivity = 1.0,
        drag_threshold = 10,
        touchpad_scroll_factor = 1.0,
        scroll_event_delay = 160,
      },

      animation = { enabled = true, speed = 8.0, bezier = "spatialOverviewEase" },

      distortion = {
        enabled = true,
        strength = 0.14,
        edge_scale = 1.08,
        feather = 0.025,
        transition_power = 1.0,
        edge_blur = 0.0,
        edge_blur_start = 0.45,
        vignette = 0.0,
        chromatic = 0.0,
      },

      workspace_outline = { enabled = false },

      canvas = {
        enabled = true,
        desktop_mode = true,
        persistent = true,
        initial_zoom = 0.72,
        min_zoom = 0.05,
        max_zoom = 2.5,
        zoom_step = 0.12,
        auto_float = true,
        auto_place = true,
        open_filled = true, -- caelestia-h: ventanas nuevas llenas, en anillo desde el centro del lienzo
        placement_gap = 40, -- ventanas nunca pegadas
        space_pan = false,
        direct_input = true,
        hover_focus = true,
        minimap_enabled = true,
        minimap_width = 240,
        minimap_height = 150,
        minimap_margin = 24,
        minimap_opacity = 0.72,
        arrange_context_grouping = true,
        arrange_size_similarity = 0.12,
        arrange_resize_limit = 0.15,
        grid_enabled = true,
        grid_size = 80,
        grid_width = 1,
        grid_opacity = 0.16,
        grid_style = 1,
        grid_dot_size = 3.2,
        background_dim = 0.35,
        viewport_enabled = false,
        float_on_drag = true,
        allow_window_overflow = true,
        snap_viewport_on_pan = true,
        commit_viewport_on_close = true,
        snap_enabled = true,
        remember_layout = true,
      },

      navigator = {
        enabled = true,
        labels = true,
        dim_unmatched = 0.7,
        pointer = true,
        accent = "auto", -- color del borde activo = esquema de Caelestia
        mono_font = "JetBrainsMono Nerd Font",
        hud_scale = 1.0,
        width = 720,
        top = 0.075,
        rows = 6,
        row_height = 58,
        rounding = 11,
        panel_opacity = 0.94,
        uppercase = true,
        letter_spacing = 1.0,
        query_size = 17,
        title_size = 14,
        detail_size = 10.5,
        corner_size = 12,
        label_size = 10.5,
        corner_labels = true,
        search_height = 60,
        search_border = 1.5,
        search_border_opacity = 0.85,
        search_border_color = "accent",
        search_glow = 0.3,
      },

      parallax = { enabled = true, strength = 0.06, depth = 0.12, desktop = false },

      -- Mientras el mapa está abierto, la capa de paneles de Caelestia
      -- (volumen/brillo, utilidades, dashboard) se desvanece y no recibe el
      -- mouse; a 100% funcionan normal. La barra y el borde los oculta el
      -- switch (phantomat-mode.sh).
      chrome_animation = {
        enabled = true,
        top_namespace = "caelestia-drawers",
        bottom_namespace = "",
        top_travel = 0.0,
        top_scale = 1.0,
        opacity = 0.0,
      },

      wallpaper = 0,
      blur = false,
      blur_strength = 0.7,
      shadow = { enabled = false, range = 36 },
    },
  },
})

hl.curve("spatialOverviewEase", {
  type = "bezier",
  points = { { 0.22, 1.0 }, { 0.36, 1.0 } },
})

-- Ajustes del tuner en vivo (CTRL + , en el mapa).
if SO.tuning_file then
  local ok, tuned = pcall(dofile, SO.tuning_file())
  if ok and type(tuned) == "table" then
    local tree = {}
    for key, value in pairs(tuned) do
      local node, parts = tree, {}
      for part in string.gmatch(key, "[^:]+") do
        parts[#parts + 1] = part
      end
      for i = 1, #parts - 1 do
        node[parts[i]] = node[parts[i]] or {}
        node = node[parts[i]]
      end
      node[parts[#parts]] = value
    end
    hl.config({ plugin = { spatialoverview = tree } })
  end
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function bind(keys, description, action, opts)
  opts = opts or {}
  opts.description = description -- aparece en el Keybinds Viewer (Super + H)
  hl.bind(keys, action, opts)
end

local function rebind(keys, description, action, opts)
  hl.unbind(keys)
  bind(keys, description, action, opts)
end

-- Ejecuta una acción del plugin YA. SO._dispatch corre al momento en
-- cualquier contexto (atajo, hyprctl eval); SO.canvas(...) fuera de un atajo
-- solo construye el dispatcher sin ejecutarlo. Lanza error si falla.
local function now(name, arg)
  return SO._dispatch(name, arg)
end

-- ¿Modo Infinito? Lo decide el switch: phantomat-mode.sh crea este archivo al
-- entrar y lo borra al salir. No se pregunta al plugin porque con una ventana
-- en pantalla completa el lienzo de esa pantalla "se aparta" y parecería
-- Modo Caelestia (así Super+F volvía a mostrar la barra).
local state_dir = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/phantomat"
local mode_file = state_dir .. "/caelestia-chrome.json"
local function infinite()
  local f = io.open(mode_file)
  if f then f:close() return true end
  return false
end

local function run(actions)
  for _, a in ipairs(actions) do
    if type(a) == "function" then a() else hl.dispatch(a) end
  end
end

-- En Modo Infinito ejecuta `canvas_action` (string para SO.canvas o función);
-- en Modo Caelestia ejecuta `caelestia` (lista de dispatchers/funciones),
-- que es lo mismo que el atajo hace hoy.
local function by_mode(canvas_action, caelestia)
  return function()
    if infinite() then
      if type(canvas_action) == "function" then
        canvas_action()
      elseif canvas_action ~= "noop" then
        pcall(now, "canvas", canvas_action)
      end
    elseif caelestia then
      run(caelestia)
    end
  end
end

-- ── Switch de modos ──────────────────────────────────────────────────────────

bind("SUPER + CTRL + I", "Switch: Modo Caelestia ↔ Modo Infinito", function()
  hl.exec_cmd(mode_script .. (infinite() and " caelestia" or " infinite"))
end)

-- Red de seguridad: si la sesión anterior terminó en Modo Infinito, devolver
-- barra y borde (la sesión siempre arranca en Modo Caelestia).
hl.on("hyprland.start", function()
  hl.exec_cmd(mode_script .. " restore")
end)

-- Apps que una regla manda a un workspace especial (Spotify → música, ...):
-- en Modo Infinito los especiales no funcionan, así que la ventana se trae al
-- lienzo; al volver a Caelestia regresa a su workspace especial.
hl.on("window.open", function(win)
  if not infinite() or not win or not win.workspace then return end
  local ws = tostring(win.workspace.name or "")
  if ws:sub(1, 8) == "special:" then
    hl.exec_cmd(mode_script .. " adopt " .. tostring(win.address) .. " " .. ws)
  end
end)

-- ── Atajos del Modo Infinito (en Caelestia no hacen nada) ────────────────────

bind("SUPER + CTRL + G", "Infinito: mapa ↔ vista normal", function()
  if infinite() then pcall(now, "overview", "toggle all") end
end)
bind("SUPER + T", "Infinito: llenar pantalla con margen / volver", by_mode("fill", nil))
bind("SUPER + O", "Infinito: fijar ventana a la pantalla / soltar", by_mode("pin", nil))

-- ── Atajos que cambian según el modo ─────────────────────────────────────────

for _, dir in ipairs({ "left", "right", "up", "down" }) do
  -- Ir a la ventana de ese lado; si no hay, no se mueve; la cámara la sigue.
  rebind("SUPER + " .. dir, "Foco " .. dir .. " (infinito: ventana vecina)",
    by_mode(function() pcall(now, "navigate", dir) end, { hl.dsp.focus({ direction = dir }) }))
  -- Empujar la ventana un paso de grilla / mover ventana.
  rebind("SUPER + SHIFT + " .. dir, "Mover ventana " .. dir .. " (infinito: empujar)",
    by_mode("nudge " .. dir, { hl.dsp.window.move({ direction = dir }) }), { repeating = true })
end

-- Super + Tab: en Infinito alterna entre la ventana actual y la anterior
-- (como en el navegador; la cámara la sigue). En Caelestia, igual que hoy
-- (hypr-user.lua): siguiente ventana.
rebind("SUPER + TAB", "Siguiente ventana (infinito: alternar con la anterior)",
  by_mode(function() hl.dispatch(hl.dsp.focus({ last = true })) end, { hl.dsp.window.cycle_next() }))

-- Super + Space: en Infinito no hace nada. Pasar una ventana a mosaico en el
-- lienzo la parte a media pantalla y luego, al volver a flotar, tapa a otras.
rebind("SUPER + Space", "Toggle flotante (infinito: nada)",
  by_mode("noop", { hl.dsp.window.float() }))

rebind("ALT + TAB", "Ventanas recientes / ciclar",
  by_mode("switch next", { hl.dsp.window.cycle_next() }), { repeating = true })
rebind("SHIFT + ALT + TAB", "Ventanas recientes (atrás) / ciclar atrás",
  by_mode("switch prev", { hl.dsp.window.cycle_next({ next = false }) }), { repeating = true })

-- Super + F: en Caelestia igual que hypr-user.lua (fullscreen + alternar barra);
-- en Infinito solo fullscreen (la barra ya está oculta y no debe reaparecer).
rebind("SUPER + F", "Fullscreen (Caelestia: + ocultar barra)", function()
  hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" }))
  if not infinite() then
    hl.dispatch(hl.dsp.exec_cmd("caelestia shell drawers toggle bar"))
  end
end)

-- Mosaico y grupos no existen en el lienzo. Grupos en el lienzo crashean
-- Hyprland al salir → en Infinito no hacen nada.
rebind("SUPER + G", "Crear/alternar grupo (infinito: nada)", by_mode("noop", { hl.dsp.group.toggle() }))
rebind("SUPER + J", "Toggle split (infinito: nada)", by_mode("noop", { hl.dsp.layout("togglesplit") }))

-- Workspaces especiales: en Infinito no se usan (sus ventanas viven en el
-- lienzo). En Caelestia, lo mismo que keybinds.lua (fn.toggle abre sus apps).
for _, sp in ipairs({
  { "SUPER + S", "specialws", "Workspace especial" },
  { "SUPER + M", "music", "Música (DaniOS Music)" },
  { "SUPER + ALT + M", "spotify", "Spotify (motor de audio)" },
  { "SUPER + D", "communication", "Comunicación" },
  { "SUPER + R", "todo", "Todo" },
  { "CTRL + SHIFT + Escape", "sysmon", "Monitor del sistema" },
}) do
  rebind(sp[1], sp[3] .. " (infinito: nada)", by_mode("noop", { fn.toggle(sp[2]) }))
end
rebind("SUPER + SHIFT + S", "Mover ventana a especial (infinito: nada)",
  by_mode("noop", { hl.dsp.window.move({ workspace = "special:special" }) }))

-- Workspaces: en Infinito no se usan (decisión 2026-11-11).
for i = 1, 10 do
  local key = tostring(i % 10)
  rebind("SUPER + " .. key, "Ir a workspace " .. i .. " (infinito: nada)",
    by_mode("noop", { fn.wsaction("focus", "", i) }))
  rebind("SUPER + SHIFT + " .. key, "Mover ventana a workspace " .. i .. " (infinito: nada)",
    by_mode("noop", { fn.wsaction("move", "", i) }))
end
rebind("SUPER + mouse_down", "Workspace siguiente (infinito: nada)",
  by_mode("noop", { hl.dsp.focus({ workspace = "+1" }) }))
rebind("SUPER + mouse_up", "Workspace anterior (infinito: nada)",
  by_mode("noop", { hl.dsp.focus({ workspace = "-1" }) }))
