-- ============================================
-- BLADEX HUB - CARGADOR DEFINITIVO v2
-- Soporta múltiples juegos automáticamente
-- ============================================

-- ✅ JUEGOS PERMITIDOS
local GAMES = {
    [106772177198260] = {
        name       = "🎣 Reel a Brainrot",
        script_url = "https://raw.githubusercontent.com/martin009gonzg-cmd/BLADEX-PROJECT/refs/heads/main/REEL_A_BRAINROT",
    },
    [124473577469410] = {
        name       = "🎲 Be a Lucky Block",
        script_url = "https://raw.githubusercontent.com/martin009gonzg-cmd/BLADEX-PROJECT/refs/heads/main/Be_a_Lucky_Block",
    },
}

local library_url = "https://pastebin.com/raw/ufVie1pF"

-- ══════════════════════════════════════════════
-- VERIFICAR JUEGO
-- ══════════════════════════════════════════════
local currentGame = GAMES[game.PlaceId]
if not currentGame then
    warn("[BLADEX] ❌ Este script no es compatible con el juego actual.")
    warn("[BLADEX] PlaceId detectado: " .. tostring(game.PlaceId))
    warn("[BLADEX] Juegos soportados:")
    for id, info in pairs(GAMES) do
        warn("  → PlaceId " .. tostring(id) .. " — " .. info.name)
    end
    return
end

print("[BLADEX] ✅ Juego verificado: " .. currentGame.name)
print("[BLADEX] Iniciando cargador...")

-- ══════════════════════════════════════════════
-- UTILIDAD
-- ══════════════════════════════════════════════
local function get_content(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok then return res end
    warn("[BLADEX] Error al obtener " .. url .. ": " .. tostring(res))
    return nil
end

-- ══════════════════════════════════════════════
-- 1. CARGAR LIBRERÍA COMPKILLER
-- ══════════════════════════════════════════════
print("[BLADEX] Descargando librería Compkiller...")
local lib_code = get_content(library_url)
if not lib_code then
    error("[BLADEX] No se pudo descargar la librería. Verifica tu conexión.")
    return
end

local exec_lib, lib_err = loadstring(lib_code)
if not exec_lib then
    error("[BLADEX] Error al compilar la librería: " .. tostring(lib_err))
    return
end

-- ✅ Capturar return de la librería
local libResult = exec_lib()
if libResult then
    getgenv().Compkiller = libResult
    _G.Compkiller        = libResult
end

local Compkiller = getgenv().Compkiller or _G.Compkiller
if not Compkiller then
    print("[BLADEX] Esperando inicialización de la librería...")
    task.wait(2)
    Compkiller = getgenv().Compkiller or _G.Compkiller
end

if not Compkiller then
    error("[BLADEX] No se pudo encontrar la librería Compkiller en el entorno global.")
    return
end

print("[BLADEX] ✅ Librería Compkiller cargada — Versión: " .. (Compkiller.Version or "2.6"))

-- ══════════════════════════════════════════════
-- 2. CARGAR SCRIPT DEL JUEGO ACTUAL
-- ══════════════════════════════════════════════
print("[BLADEX] Descargando script: " .. currentGame.name .. "...")
local script_code = get_content(currentGame.script_url)
if not script_code then
    error("[BLADEX] No se pudo descargar el script principal.")
    return
end

local exec_script, script_err = loadstring(script_code)
if not exec_script then
    error("[BLADEX] Error al compilar el script: " .. tostring(script_err))
    return
end

-- Asegurar disponibilidad global
getgenv().Compkiller = Compkiller
_G.Compkiller        = Compkiller

print("[BLADEX] Ejecutando " .. currentGame.name .. "...")
local ok, err = pcall(exec_script)
if ok then
    print("")
    print("╔════════════════════════════════════════════════╗")
    print("║         ✅ BLADEX HUB CARGADO EXITOSO          ║")
    print("╠════════════════════════════════════════════════╣")
    print("║  Juego  : " .. currentGame.name)
    print("║  Keybind: LEFT ALT — abrir / cerrar            ║")
    print("╚════════════════════════════════════════════════╝")
    print("")
else
    warn("[BLADEX] Error durante la ejecución: " .. tostring(err))
end
