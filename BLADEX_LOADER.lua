local function _()
    local _0 = {}
    local _1 = game
    local _2 = getgenv
    local _3 = pcall
    local _4 = warn
    local _5 = print
    local _6 = error
    local _7 = task.wait
    local _8 = tostring
    local _9 = pairs
    
    -- Juegos soportados
    _0[99435399946069] = {"https://raw.githubusercontent.com/martin009gonzg-cmd/BLADEX-PROJECT/refs/heads/main/REEL_A_BRAINROT", "[NEW] Reel a Brainrot! [GAME]"}
    
    local _a = "https://pastebin.com/raw/ufVie1pF"
    local _b = _1.PlaceId
    local _c = _0[_b]
    
    if not _c then
        _4("[BLADEX] Juego no soportado: " .. _8(_b))
        _5("[BLADEX] Juegos disponibles:")
        for _d, _e in _9(_0) do
            _5("  -> " .. _8(_d) .. " - " .. _e[2])
        end
        return
    end
    
    local _f = _c[1]
    local _g = _c[2]
    
    _5("[BLADEX] Juego: " .. _g)
    _5("[BLADEX] Iniciando cargador...")
    
    local function _h(_i)
        local _j, _k = _3(function()
            return _1:HttpGet(_i)
        end)
        if _j then
            return _k
        end
        _4("[BLADEX] Error en URL: " .. _8(_i))
        _4("[BLADEX] Detalle: " .. _8(_k))
        return nil
    end
    
    _5("[BLADEX] Descargando libreria Compkiller...")
    local _l = _h(_a)
    if not _l then
        _6("[BLADEX] Fallo la libreria")
        return
    end
    
    local _m, _n = _3(loadstring, _l)
    if not _m then
        _6("[BLADEX] Error al compilar: " .. _8(_n))
        return
    end
    
    local _o = _n()
    if _o then
        _2().Compkiller = _o
    end
    
    local _p = _2().Compkiller
    if not _p then
        _5("[BLADEX] Esperando inicializacion...")
        _7(2)
        _p = _2().Compkiller
    end
    
    if not _p then
        _6("[BLADEX] No se encontro Compkiller")
        return
    end
    
    _5("[BLADEX] Libreria version: " .. _8(_p.Version or "2.6"))
    _5("[BLADEX] Descargando script del juego...")
    
    local _q = _h(_f)
    if not _q then
        _6("[BLADEX] Fallo el script principal")
        return
    end
    
    local _r, _s = _3(loadstring, _q)
    if not _r then
        _6("[BLADEX] Error al compilar script: " .. _8(_s))
        return
    end
    
    _2().Compkiller = _p
    
    _5("[BLADEX] Ejecutando " .. _g .. "...")
    
    local _t, _u = _3(_s)
    if _t then
        _5("")
        _5("██████╗ ██╗      █████╗ ██████╗ ███████╗██╗  ██╗")
        _5("██╔══██╗██║     ██╔══██╗██╔══██╗██╔════╝╚██╗██╔╝")
        _5("██████╔╝██║     ███████║██║  ██║█████╗   ╚███╔╝ ")
        _5("██╔══██╗██║     ██╔══██║██║  ██║██╔══╝   ██╔██╗ ")
        _5("██████╔╝███████╗██║  ██║██████╔╝███████╗██╔╝ ██╗")
        _5("╚═════╝ ╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝")
        _5("")
        _5("                          ✨ BLADEX CARGADO ✨")
        _5("")
    else
        _4("[BLADEX] Error en ejecucion: " .. _8(_u))
    end
end
_()
