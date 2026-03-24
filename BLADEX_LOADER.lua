-- BLADEX HUB - CARGADOR OFUSCADO v2
local _0x0, _0x1, _0x2, _0x3, _0x4, _0x5, _0x6, _0x7, _0x8, _0x9 = 
    game, getgenv, pcall, warn, print, error, task, tostring, pairs, ""

local _0xA = _0x0.PlaceId
local _0xB = {
    [106772177198260] = {_0x9.."\xF0\x9F\x8E\xA3 Reel a Brainrot", "https://raw.githubusercontent.com/martin009gonzg-cmd/BLADEX-PROJECT/refs/heads/main/REEL_A_BRAINROT"},
    [124473577469410] = {_0x9.."\xF0\x9F\x8E\xB2 Be a Lucky Block", "https://raw.githubusercontent.com/martin009gonzg-cmd/BLADEX-PROJECT/refs/heads/main/Be_a_Lucky_Block"},
}

local _0xC = _0xB[_0xA]
if not _0xC then
    _0x3("[BLADEX] \xE2\x9D\x8C Juego no soportado: ".._0x7(_0xA))
    return
end

_0x4("[BLADEX] \xE2\x9C\x85 Juego: ".._0xC[1])

local function _0xD(_0xE)
    local _0xF, _0x10 = _0x2(function() return _0x0:HttpGet(_0xE) end)
    return _0xF and _0x10 or (_0x3("[BLADEX] Error: ".._0x7(_0x10)) and nil)
end

local _0x11 = _0xD("https://pastebin.com/raw/ufVie1pF")
if not _0x11 then _0x5("[BLADEX] Error librer\xc3\xada") return end

local _0x12, _0x13 = _0x2(loadstring, _0x11)
if not _0x12 then _0x5("[BLADEX] Error compilar: ".._0x7(_0x13)) return end

local _0x14 = _0x13()
if _0x14 then 
    _0x1().Compkiller = _0x14 
    _0x1().Compkiller = _0x14
end

local _0x15 = _0x1().Compkiller
if not _0x15 then
    _0x6(2)
    _0x15 = _0x1().Compkiller
end
if not _0x15 then _0x5("[BLADEX] Compkiller no encontrado") return end

local _0x16 = _0xD(_0xC[2])
if not _0x16 then _0x5("[BLADEX] Error script") return end

local _0x17, _0x18 = _0x2(loadstring, _0x16)
if not _0x17 then _0x5("[BLADEX] Error: ".._0x7(_0x18)) return end

_0x1().Compkiller = _0x15
local _0x19, _0x1A = _0x2(_0x18)
if _0x19 then
    _0x4("\n╔════════════════════════════════╗\n║     BLADEX HUB CARGADO        ║\n║  Juego: ".._0xC[1].."\n║  Keybind: LEFT ALT            ║\n╚════════════════════════════════╝\n")
else
    _0x3("[BLADEX] Error: ".._0x7(_0x1A))
end
