-- Distribución de monitores, genérica para cualquier máquina.
--
-- Pone el portátil a la izquierda o a la derecha de TODOS los monitores
-- externos, calculando las posiciones a partir de la resolución y la escala
-- reales de cada pantalla. Funciona con 1, 2, 3... monitores sin tocar nada.
--
--   SUPER + M  → cambia el portátil de lado (se recuerda entre reinicios)
--
-- Los externos se ordenan entre sí según su posición actual. Si quieres fijar
-- algo concreto para un monitor (resolución, escala, rotación...), añade una
-- regla abajo en `overrides` usando su nombre o "desc:<descripción>"
-- (ver `hyprctl monitors`).

local DEFAULT_SIDE = "right" -- "left" o "right"

-- Ejemplo: overrides["desc:Samsung Electric Company S24D330 0x5A5A5131"] = { scale = 1 }
local overrides = {}

local state_file = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
    .. "/hypr/laptop_side"

local function read_side()
    local f = io.open(state_file, "r")
    if not f then return DEFAULT_SIDE end
    local side = f:read("l")
    f:close()
    return (side == "left" or side == "right") and side or DEFAULT_SIDE
end

local function save_side(side)
    os.execute("mkdir -p '" .. state_file:match("(.*)/") .. "'")
    local f = io.open(state_file, "w")
    if f then
        f:write(side)
        f:close()
    end
end

local laptop_side = read_side()

local function is_laptop(m)
    return m.name:match("^eDP") or m.name:match("^LVDS") or m.name:match("^DSI")
end

local function override_for(m)
    return overrides[m.name] or overrides["desc:" .. m.description] or {}
end

-- Ancho en el escritorio = píxeles / escala (girado 90º/270º usa el alto)
local function logical_width(m)
    local px = (m.transform % 2 == 1) and m.height or m.width
    return math.floor(px / m.scale + 0.5)
end

local function place(m, x)
    local o = override_for(m)
    hl.monitor({
        output    = m.name,
        mode      = o.mode or "preferred",
        position  = x .. "x0",
        scale     = o.scale or m.scale,
        transform = o.transform,
    })
end

local function arrange()
    local laptop, externals = nil, {}
    for _, m in ipairs(hl.get_monitors()) do
        if is_laptop(m) then
            laptop = m
        else
            table.insert(externals, m)
        end
    end
    table.sort(externals, function(a, b) return a.x < b.x end)

    local x = 0
    if laptop and laptop_side == "left" then
        place(laptop, x)
        x = x + logical_width(laptop)
    end
    for _, m in ipairs(externals) do
        place(m, x)
        x = x + logical_width(m)
    end
    if laptop and laptop_side == "right" then
        place(laptop, x)
    end
end

-- Regla base para cualquier pantalla; arrange() la refina con posiciones exactas
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.on("hyprland.start", arrange)
hl.on("config.reloaded", arrange)
hl.on("monitor.added", arrange)
hl.on("monitor.removed", arrange)

hl.bind("SUPER + M", function()
    laptop_side = (laptop_side == "right") and "left" or "right"
    save_side(laptop_side)
    arrange()
end)

-- Tapa del portátil: apagar la pantalla al cerrar y recolocar al abrir
local lid_closed_output = nil

hl.bind("switch:on:Lid Switch", function()
    for _, m in ipairs(hl.get_monitors()) do
        if is_laptop(m) then
            lid_closed_output = m.name
            hl.monitor({ output = m.name, disabled = true })
        end
    end
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
    if lid_closed_output then
        hl.monitor({ output = lid_closed_output, mode = "preferred", position = "auto", scale = "auto" })
        lid_closed_output = nil
    end
    hl.timer(arrange, { timeout = 500, type = "oneshot" })
end, { locked = true })
