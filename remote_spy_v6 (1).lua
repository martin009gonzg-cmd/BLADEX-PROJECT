local Players     = game:GetService("Players")
local RepStorage  = game:GetService("ReplicatedStorage")
local UserInput   = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player      = Players.LocalPlayer

-- CONFIG
local CFG = {
    CAPTURE_CLIENT   = true,
    CAPTURE_RETURN   = true,
    CAPTURE_BINDABLE = true,
    PRINT_ENABLED    = true,
    GUI_ENABLED      = true,
    GUI_MAX_ENTRIES  = 120,
    GUI_TOGGLE_KEY   = Enum.KeyCode.Insert,
    MAX_STR          = 200,
    SPAM_WINDOW      = 4,
    SPAM_THRESHOLD   = 5,
    STEALTH          = true,
    FAKE_TRAFFIC     = false,
    WEBHOOK_URL      = "",
    BLACKLIST        = { "Heartbeat", "Ping", "EventsSnapshotUpdated" },
    WHITELIST        = {},
}

-- ESTADO
local logCount   = 0
local logs       = {}
local hookeados  = {}
local hookedBtns = {}
local spamTrack  = {}
local namecallOk = false
local hookFOk    = type(hookfunction)   == "function"
local newCCOk    = type(newcclosure)    == "function"
local hookMetaOk = type(hookmetamethod) == "function"

-- SERIALIZACIÓN  (display)
local function serial(v, depth)
    depth = depth or 0
    if depth > 5 then return "..." end
    local t = typeof(v)
    if     t == "nil"       then return "nil"
    elseif t == "boolean"   then return tostring(v)
    elseif t == "number"    then
        return v == math.floor(v) and tostring(math.floor(v)) or ("%.4f"):format(v)
    elseif t == "string"    then
        local s = v:sub(1, CFG.MAX_STR) .. (#v > CFG.MAX_STR and "..." or "")
        return '"' .. s:gsub('\\','\\\\'):gsub('"','\\"'):gsub("\n","\\n"):gsub("\t","\\t") .. '"'
    elseif t == "function"  then return "<fn>"
    elseif t == "thread"    then return "<thread>"
    elseif t == "Vector3"   then return ("V3(%g,%g,%g)"):format(v.X,v.Y,v.Z)
    elseif t == "Vector2"   then return ("V2(%g,%g)"):format(v.X,v.Y)
    elseif t == "CFrame"    then return ("CF(%g,%g,%g)"):format(v.Position.X,v.Position.Y,v.Position.Z)
    elseif t == "Color3"    then return ("RGB(%d,%d,%d)"):format(v.R*255,v.G*255,v.B*255)
    elseif t == "UDim2"     then return ("UD2(%g%%+%g,%g%%+%g)"):format(v.X.Scale*100,v.X.Offset,v.Y.Scale*100,v.Y.Offset)
    elseif t == "EnumItem"  then return tostring(v)
    elseif t == "BrickColor" then return ('BC("'..tostring(v)..'")')
    elseif t == "Instance"  then
        local cn,fp = "?","?"
        pcall(function() cn=v.ClassName end)
        pcall(function() fp=v:GetFullName() end)
        return cn..'("'..fp..'")'
    elseif t == "table"     then
        local parts, n = {}, 0
        for k,val in pairs(v) do
            n=n+1
            if n>30 then parts[#parts+1]="..."; break end
            local ks = type(k)=="string" and k or "["..tostring(k).."]"
            parts[#parts+1] = ks.."="..serial(val,depth+1)
        end
        return "{ "..table.concat(parts,", ").." }"
    end
    return tostring(v)
end

local function prettyArgs(args)
    if not args or #args == 0 then return {"  (ninguno)"} end
    local lines = {}
    for i,v in ipairs(args) do
        local t = typeof(v)
        if t == "table" then
            local cnt = 0; for _ in pairs(v) do cnt=cnt+1 end
            lines[#lines+1] = ("  [%d] table (%d keys) = %s"):format(i, cnt, argToCode(v,0))
            local n = 0
            for k,val in pairs(v) do
                n=n+1
                if n>30 then lines[#lines+1]="       ..."; break end
                local ks = type(k)=="string" and k or "["..tostring(k).."]"
                local vcode = argToCode(val,1)
                local vdisp = serial(val,1)
                local extra = (vcode ~= vdisp) and ("  -- "..vdisp) or ""
                lines[#lines+1] = "       "..ks.." = "..vcode..extra
            end
        else
            -- Show: type, display value, and Lua code if different
            local disp = serial(v)
            local code = argToCode(v)
            if code == disp then
                lines[#lines+1] = ("  [%d] (%s) %s"):format(i, t, disp)
            else
                lines[#lines+1] = ("  [%d] (%s) %s  -->  %s"):format(i, t, disp, code)
            end
        end
    end
    return lines
end

-- SERIALIZACIÓN A CÓDIGO LUA  (para el script generator)
local function argToCode(v, depth)
    depth = depth or 0
    if depth > 4 then return "nil" end
    local t = typeof(v)
    if     t == "nil"       then return "nil"
    elseif t == "boolean"   then return tostring(v)
    elseif t == "number"    then
        return v == math.floor(v) and tostring(math.floor(v)) or ("%.6g"):format(v)
    elseif t == "string"    then
        return '"' .. v:gsub('\\','\\\\'):gsub('"','\\"'):gsub("\n","\\n"):gsub("\t","\\t") .. '"'
    elseif t == "Vector3"   then return ("Vector3.new(%g,%g,%g)"):format(v.X,v.Y,v.Z)
    elseif t == "Vector2"   then return ("Vector2.new(%g,%g)"):format(v.X,v.Y)
    elseif t == "CFrame"    then return ("CFrame.new(%g,%g,%g)"):format(v.Position.X,v.Position.Y,v.Position.Z)
    elseif t == "Color3"    then return ("Color3.fromRGB(%d,%d,%d)"):format(v.R*255,v.G*255,v.B*255)
    elseif t == "EnumItem"  then return tostring(v)
    elseif t == "BrickColor" then return ('BrickColor.new("'..tostring(v)..'")')
    elseif t == "Instance"  then
        local fp = "?"
        pcall(function() fp=v:GetFullName() end)
        return ('game:GetService("Workspace") --[[ '..fp..' ]]')
    elseif t == "table"     then
        local parts, isArr = {}, true
        local n = 0
        for k in pairs(v) do
            n=n+1
            if type(k) ~= "number" then isArr=false end
        end
        if isArr then
            for i=1,n do
                parts[#parts+1] = argToCode(v[i], depth+1)
            end
        else
            for k,val in pairs(v) do
                local ks = type(k)=="string" and k or "["..argToCode(k,depth+1).."]"
                parts[#parts+1] = ks.." = "..argToCode(val,depth+1)
            end
        end
        return "{"..table.concat(parts,", ").."}"
    end
    return "nil --[[ "..tostring(v).." ]]"
end

-- Genera la ruta de WaitForChild para un remote dado su GetFullName
-- "ReplicatedStorage.Remotes.Sell" → 
-- game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Sell")
local function routeToCode(ruta)
    if not ruta or ruta == "?" then return 'RepStorage --[[ ruta desconocida ]]' end
    local parts = {}
    for seg in ruta:gmatch("[^%.]+") do parts[#parts+1]=seg end
    if #parts == 0 then return 'RepStorage' end
    local first = parts[1]
    -- Detectar servicio inicial
    local svcMap = {
        ReplicatedStorage = "RepStorage",
        Workspace = "workspace",
        Players = "Players",
    }
    local code = svcMap[first] or ('game:GetService("'..first..'")')
    for i=2,#parts do
        code = code .. ':WaitForChild("'..parts[i]..'")'
    end
    return code
end

-- Genera el snippet de una sola llamada a remote
local function remoteCallCode(entry, indent)
    indent = indent or "    "
    local args = entry.args or {}
    local argParts = {}
    for _,v in ipairs(args) do
        argParts[#argParts+1] = argToCode(v)
    end
    local argStr = table.concat(argParts, ", ")
    local method = (entry.metodo == "InvokeServer") and ":InvokeServer(" or ":FireServer("
    local varName = entry.nombre:gsub("[^%w]","_"):lower()
    return indent.."remotes."..varName..method..argStr..")"
end

-- SCRIPT BUILDER  (nucleo del generador)
local SB = {
    items    = {},   -- {id, entry, enabled, delay, loopEnabled}
    template = "loop",  -- "loop" | "once" | "conditional"
    loopDelay = 0.1,
    onGenerate = nil,  -- callback cuando se genera código nuevo
}

local function sbAdd(entry)
    -- Evitar duplicados por nombre+método
    for _,item in ipairs(SB.items) do
        if item.entry.nombre == entry.nombre and item.entry.metodo == entry.metodo then
            return false
        end
    end
    SB.items[#SB.items+1] = {
        id          = #SB.items+1,
        entry       = entry,
        enabled     = true,
        delay       = 0.1,
        label       = entry.nombre,
    }
    return true
end

local function sbRemove(idx)
    table.remove(SB.items, idx)
    for i,item in ipairs(SB.items) do item.id=i end
end

local TEMPLATES = {}

TEMPLATES.once = function(items)
    local L = {}
    L[#L+1] = "-- Script generado por Remote Spy v6"
    L[#L+1] = "-- Modo: ejecución única"
    L[#L+1] = ""
    L[#L+1] = "local RepStorage = game:GetService('ReplicatedStorage')"
    L[#L+1] = "local Players    = game:GetService('Players')"
    L[#L+1] = "local player     = Players.LocalPlayer"
    L[#L+1] = ""
    -- Declarar remotes
    L[#L+1] = "local remotes = {}"
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo ~= "SERVER->CLIENT" then
            local vn = item.entry.nombre:gsub("[^%w]","_"):lower()
            L[#L+1] = ("remotes.%s = %s"):format(vn, routeToCode(item.entry.ruta))
        end
    end
    L[#L+1] = ""
    L[#L+1] = "-- Llamadas"
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo ~= "SERVER->CLIENT" then
            L[#L+1] = remoteCallCode(item.entry, "")
            if item.delay > 0 then
                L[#L+1] = ("task.wait(%s)"):format(argToCode(item.delay))
            end
        end
    end
    return table.concat(L, "\n")
end

TEMPLATES.loop = function(items, loopDelay)
    local L = {}
    L[#L+1] = "-- Script generado por Remote Spy v6"
    L[#L+1] = "-- Modo: bucle infinito"
    L[#L+1] = ""
    L[#L+1] = "local RepStorage = game:GetService('ReplicatedStorage')"
    L[#L+1] = "local Players    = game:GetService('Players')"
    L[#L+1] = "local player     = Players.LocalPlayer"
    L[#L+1] = ""
    L[#L+1] = "local remotes = {}"
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo ~= "SERVER->CLIENT" then
            local vn = item.entry.nombre:gsub("[^%w]","_"):lower()
            L[#L+1] = ("remotes.%s = %s"):format(vn, routeToCode(item.entry.ruta))
        end
    end
    L[#L+1] = ""
    L[#L+1] = "while true do"
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo ~= "SERVER->CLIENT" then
            L[#L+1] = "    -- "..item.entry.nombre.." ("..item.entry.accion..")"
            L[#L+1] = remoteCallCode(item.entry, "    ")
            local d = item.delay > 0 and item.delay or loopDelay
            L[#L+1] = ("    task.wait(%s)"):format(argToCode(d))
        end
    end
    L[#L+1] = "end"
    return table.concat(L, "\n")
end

TEMPLATES.conditional = function(items)
    local L = {}
    L[#L+1] = "-- Script generado por Remote Spy v6"
    L[#L+1] = "-- Modo: condicional (personaliza las condiciones)"
    L[#L+1] = ""
    L[#L+1] = "local RepStorage = game:GetService('ReplicatedStorage')"
    L[#L+1] = "local Players    = game:GetService('Players')"
    L[#L+1] = "local player     = Players.LocalPlayer"
    L[#L+1] = ""
    L[#L+1] = "local remotes = {}"
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo ~= "SERVER->CLIENT" then
            local vn = item.entry.nombre:gsub("[^%w]","_"):lower()
            L[#L+1] = ("remotes.%s = %s"):format(vn, routeToCode(item.entry.ruta))
        end
    end
    L[#L+1] = ""
    L[#L+1] = "-- Conectar eventos del servidor"
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo == "SERVER->CLIENT" then
            local vn = item.entry.nombre:gsub("[^%w]","_"):lower()
            L[#L+1] = ("local re_%s = %s"):format(vn, routeToCode(item.entry.ruta))
            L[#L+1] = ("re_%s.OnClientEvent:Connect(function(...)"):format(vn)
            L[#L+1] = "    -- Recibido: "..item.entry.nombre
            L[#L+1] = "    print(...)"
            L[#L+1] = "end)"
            L[#L+1] = ""
        end
    end
    L[#L+1] = "while true do"
    L[#L+1] = "    task.wait(0.5)"
    L[#L+1] = "    -- TODO: añade tu condición"
    L[#L+1] = "    local condition = true"
    L[#L+1] = "    if condition then"
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo ~= "SERVER->CLIENT" then
            L[#L+1] = "        -- "..item.entry.nombre
            L[#L+1] = remoteCallCode(item.entry, "        ")
        end
    end
    L[#L+1] = "    end"
    L[#L+1] = "end"
    return table.concat(L, "\n")
end

TEMPLATES.autoFarm = function(items)
    -- Detecta sell/collect y rebirth automáticamente
    local sellItems, rebirthItems, otherItems = {},{},{}
    for _,item in ipairs(items) do
        if not item.enabled then
        elseif item.entry.accion:find("SELL") or item.entry.accion:find("COLLECT") or item.entry.accion:find("CASH") then
            sellItems[#sellItems+1] = item
        elseif item.entry.accion:find("REBIRTH") or item.entry.accion:find("PRESTIGE") then
            rebirthItems[#rebirthItems+1] = item
        elseif item.entry.metodo ~= "SERVER->CLIENT" then
            otherItems[#otherItems+1] = item
        end
    end

    local L = {}
    L[#L+1] = "-- Script generado por Remote Spy v6"
    L[#L+1] = "-- Modo: Auto Farm"
    L[#L+1] = ""
    L[#L+1] = "local RepStorage = game:GetService('ReplicatedStorage')"
    L[#L+1] = "local Players    = game:GetService('Players')"
    L[#L+1] = "local player     = Players.LocalPlayer"
    L[#L+1] = ""
    L[#L+1] = "-- Configuración"
    L[#L+1] = "local AUTO_SELL    = true"
    L[#L+1] = "local AUTO_REBIRTH = "..(#rebirthItems>0 and "true" or "false")
    L[#L+1] = "local SELL_EVERY   = 5    -- segundos entre ventas"
    L[#L+1] = "local REBIRTH_EVERY = 60  -- segundos entre rebirths"
    L[#L+1] = ""
    L[#L+1] = "local remotes = {}"
    for _,item in ipairs(items) do
        if item.entry.metodo ~= "SERVER->CLIENT" then
            local vn = item.entry.nombre:gsub("[^%w]","_"):lower()
            L[#L+1] = ("remotes.%s = %s"):format(vn, routeToCode(item.entry.ruta))
        end
    end
    L[#L+1] = ""
    L[#L+1] = "local lastSell    = 0"
    L[#L+1] = "local lastRebirth = 0"
    L[#L+1] = ""
    L[#L+1] = "while true do"
    L[#L+1] = "    task.wait(0.1)"
    L[#L+1] = "    local now = os.clock()"
    L[#L+1] = ""
    if #otherItems > 0 then
        L[#L+1] = "    -- Acciones principales"
        for _,item in ipairs(otherItems) do
            L[#L+1] = "    -- "..item.entry.nombre.." ("..item.entry.accion..")"
            L[#L+1] = remoteCallCode(item.entry,"    ")
        end
        L[#L+1] = ""
    end
    if #sellItems > 0 then
        L[#L+1] = "    -- Auto sell"
        L[#L+1] = "    if AUTO_SELL and (now - lastSell) >= SELL_EVERY then"
        L[#L+1] = "        lastSell = now"
        for _,item in ipairs(sellItems) do
            L[#L+1] = "        -- "..item.entry.nombre
            L[#L+1] = remoteCallCode(item.entry,"        ")
        end
        L[#L+1] = "    end"
        L[#L+1] = ""
    end
    if #rebirthItems > 0 then
        L[#L+1] = "    -- Auto rebirth"
        L[#L+1] = "    if AUTO_REBIRTH and (now - lastRebirth) >= REBIRTH_EVERY then"
        L[#L+1] = "        lastRebirth = now"
        for _,item in ipairs(rebirthItems) do
            L[#L+1] = "        -- "..item.entry.nombre
            L[#L+1] = remoteCallCode(item.entry,"        ")
        end
        L[#L+1] = "    end"
    end
    L[#L+1] = "end"
    return table.concat(L, "\n")
end

TEMPLATES.listener = function(items)
    -- Template para escuchar eventos del servidor y reaccionar
    local L = {}
    L[#L+1] = "-- Script generado por Remote Spy v6"
    L[#L+1] = "-- Modo: escuchar SERVER->CLIENT + reaccionar"
    L[#L+1] = ""
    L[#L+1] = "local RepStorage = game:GetService('ReplicatedStorage')"
    L[#L+1] = "local Players    = game:GetService('Players')"
    L[#L+1] = "local player     = Players.LocalPlayer"
    L[#L+1] = ""
    L[#L+1] = "local remotes = {}"
    for _,item in ipairs(items) do
        local vn = item.entry.nombre:gsub("[^%w]","_"):lower()
        L[#L+1] = ("remotes.%s = %s"):format(vn, routeToCode(item.entry.ruta))
    end
    L[#L+1] = ""
    -- Listeners para SERVER->CLIENT
    local hasListeners = false
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo == "SERVER->CLIENT" then
            hasListeners = true
            local vn = item.entry.nombre:gsub("[^%w]","_"):lower()
            local argCount = #(item.entry.args or {})
            local argNames = {}
            for i=1,argCount do argNames[#argNames+1]="arg"..i end
            local argSig = #argNames>0 and table.concat(argNames,", ") or "..."
            L[#L+1] = ("-- Evento: %s (%s)"):format(item.entry.nombre, item.entry.accion)
            L[#L+1] = ("remotes.%s.OnClientEvent:Connect(function(%s)"):format(vn, argSig)
            if argCount > 0 then
                for i,av in ipairs(item.entry.args or {}) do
                    L[#L+1] = ("    -- arg%d (%s) = %s"):format(i, typeof(av), argToCode(av))
                end
            end
            L[#L+1] = "    -- TODO: reaccionar al evento"
            L[#L+1] = "    print('Recibido: '..tostring("..argSig:gsub(", .*","").."))"
            L[#L+1] = "end)"
            L[#L+1] = ""
        end
    end
    if not hasListeners then
        L[#L+1] = "-- No hay remotes SERVER->CLIENT en la lista"
        L[#L+1] = "-- Anade remotes S->C desde el panel SPY (boton [+])"
    end
    -- También incluir FireServer calls si hay
    local hasFirers = false
    for _,item in ipairs(items) do
        if item.enabled and item.entry.metodo ~= "SERVER->CLIENT" then
            hasFirers = true; break
        end
    end
    if hasFirers then
        L[#L+1] = "-- Llamadas al servidor"
        for _,item in ipairs(items) do
            if item.enabled and item.entry.metodo ~= "SERVER->CLIENT" then
                L[#L+1] = "-- "..item.entry.nombre.." ("..item.entry.accion..")"
                L[#L+1] = remoteCallCode(item.entry, "")
            end
        end
    end
    return table.concat(L, "\n")
end

local function generateCode()
    if #SB.items == 0 then return "-- Sin remotes anadidos\n-- Usa el boton [+] en el panel SPY" end
    local fn = TEMPLATES[SB.template] or TEMPLATES.loop
    local ok, result = pcall(fn, SB.items, SB.loopDelay)
    if not ok then return "-- Error al generar: "..tostring(result) end
    return result
end

-- INFERENCIA DE ACCIÓN
local ACTIONS = {
    {"rebirth","REBIRTH"},   {"prestige","PRESTIGE"},
    {"sell","SELL"},          {"buy","BUY"},
    {"purchase","PURCHASE"},  {"shop","SHOP"},
    {"cash","CASH"},          {"collect","COLLECT"},
    {"coin","COIN"},          {"gem","GEM"},
    {"token","TOKEN"},        {"reward","REWARD"},
    {"claim","CLAIM"},        {"earn","EARN"},
    {"upgrade","UPGRADE"},    {"power","POWER"},
    {"boost","BOOST"},        {"enchant","ENCHANT"},
    {"evolve","EVOLVE"},      {"fuse","FUSE"},
    {"merge","MERGE"},        {"craft","CRAFT"},
    {"unlock","UNLOCK"},      {"level","LEVEL"},
    {"equip","EQUIP"},        {"unequip","UNEQUIP"},
    {"best","BEST"},          {"skin","SKIN"},
    {"cast","CAST"},          {"reel","REEL"},
    {"catch","CATCH"},        {"fish","FISH"},
    {"instant","INSTANT"},    {"rod","ROD"},
    {"pet","PET"},            {"egg","EGG"},
    {"hatch","HATCH"},        {"feed","FEED"},
    {"auto","AUTO"},          {"afk","AFK"},
    {"attack","ATTACK"},      {"damage","DAMAGE"},
    {"heal","HEAL"},          {"kill","KILL"},
    {"spawn","SPAWN"},        {"teleport","TELEPORT"},
    {"chat","CHAT"},          {"message","MESSAGE"},
    {"trade","TRADE"},        {"party","PARTY"},
    {"save","SAVE"},          {"load","LOAD"},
    {"sync","SYNC"},          {"update","UPDATE"},
    {"snapshot","SNAPSHOT"},  {"data","DATA"},
    {"config","CONFIG"},      {"init","INIT"},
    {"quest","QUEST"},        {"mission","MISSION"},
    {"daily","DAILY"},        {"complete","COMPLETE"},
    {"open","OPEN"},          {"close","CLOSE"},
    {"reset","RESET"},        {"delete","DELETE"},
    {"command","COMMAND"},    {"admin","ADMIN"},
    {"ban","BAN"},            {"kick","KICK"},
    {"click","CLICK"},        {"toggle","TOGGLE"},
    {"confirm","CONFIRM"},    {"select","SELECT"},
    {"brainrot","BRAINROT"},  {"give","GIVE"},
    {"report","REPORT"},      {"exploit","EXPLOIT"},
    {"warning","WARNING"},    {"mute","MUTE"},
    {"unban","UNBAN"},        {"god","GOD"},
    {"index","INDEX"},        {"plot","PLOT"},
}

local function inferir(s)
    if type(s) ~= "string" then return nil end
    local sl = s:lower()
    for _,e in ipairs(ACTIONS) do
        if sl:find(e[1],1,true) then return e[2] end
    end
    return nil
end

local function inferirAccion(nombre,ruta,args)
    local r = inferir(nombre) or inferir(ruta)
    if r then return r end
    for _,v in ipairs(args) do
        r = inferir(tostring(v))
        if r then return r end
        if type(v)=="table" then
            for k,val in pairs(v) do
                r = inferir(tostring(k)) or inferir(tostring(val))
                if r then return r end
            end
        end
    end
    return "UNKNOWN"
end

-- ANTI-SPAM
local function spamKey(metodo,nombre,args)
    local p = {metodo,nombre}
    for i=1,math.min(#args,3) do p[#p+1]=serial(args[i],0) end
    return table.concat(p,"|")
end

local function isSpam(key)
    local now  = os.clock()
    local info = spamTrack[key]
    if not info then
        spamTrack[key] = {count=1,last=now,suppressed=0,window=CFG.SPAM_WINDOW}
        return false
    end
    if now - info.last > info.window then
        if info.suppressed > 0 then
            print(("[spam] '%s' x%d ignorados"):format(key:sub(1,50),info.suppressed))
        end
        spamTrack[key] = {count=1,last=now,suppressed=0,window=math.min(info.window*1.5,30)}
        return false
    end
    info.count = info.count+1
    info.last  = now
    if info.count > CFG.SPAM_THRESHOLD then
        info.suppressed = info.suppressed+1
        return true
    end
    return false
end

-- FILTROS
local filters = { blacklist=CFG.BLACKLIST, whitelist=CFG.WHITELIST }

local function shouldLog(nombre)
    if #filters.whitelist > 0 then
        for _,w in ipairs(filters.whitelist) do if nombre==w then return true end end
        return false
    end
    for _,b in ipairs(filters.blacklist) do if nombre==b then return false end end
    return true
end

-- SANITIZAR ARGS
local SENSITIVE = {
    {p="token[=:][%w%-_]+",    m="token=[REDACTED]"},
    {p="key[=:][%w%-_]+",      m="key=[REDACTED]"},
    {p="password[=:][%w%-_]+", m="password=[REDACTED]"},
    {p="cookie[=:][%w%-_]+",   m="cookie=[REDACTED]"},
}

local function sanitizeArgs(args)
    local clean = {}
    for i,v in ipairs(args) do
        if type(v)=="string" then
            local s = v
            for _,sp in ipairs(SENSITIVE) do s=s:gsub(sp.p,sp.m) end
            clean[i] = s
        else
            clean[i] = v
        end
    end
    return clean
end

-- RATE LIMITER
local rlLimits = {}
local function checkRateLimit(nombre)
    local maxCalls, window = 20, 2
    local now = os.clock()
    local lim = rlLimits[nombre]
    if not lim then rlLimits[nombre]={last=now,count=1}; return true end
    if now - lim.last > window then lim.last=now; lim.count=1; return true end
    lim.count = lim.count+1
    if lim.count > maxCalls then
        if lim.count==maxCalls+1 then
            print(("[RateLimit] '%s' supero limite"):format(nombre))
        end
        return false
    end
    return true
end

-- DEEP INSPECTOR
local deepInspector = { enabled=false, maxDepth=6, maxItems=50 }

local function deepInspect(value, path, depth, visited)
    path=path or "root"; depth=depth or 0; visited=visited or {}
    if depth > deepInspector.maxDepth then return path.." = ..." end
    local t = typeof(value)
    if t == "table" then
        if visited[value] then return path.." = <circular>" end
        visited[value] = true
        local cnt=0; for _ in pairs(value) do cnt=cnt+1 end
        local lines = {path..(" = table{%d}"):format(cnt)}
        local n = 0
        for k,v in pairs(value) do
            n=n+1
            if n>deepInspector.maxItems then lines[#lines+1]="  ..."; break end
            lines[#lines+1] = deepInspect(v,path.."."..tostring(k),depth+1,visited)
        end
        return table.concat(lines,"\n")
    elseif t == "Instance" then
        local cn,fp="?","?"
        pcall(function() cn=value.ClassName end)
        pcall(function() fp=value:GetFullName() end)
        return path.." = "..cn..'("'..fp..'")'
    end
    return path.." = "..serial(value,depth)
end

-- MODIFICADORES DE ARGUMENTOS
local argModifiers = { list={}, enabled=true }

local function addArgumentModifier(pattern, argIndex, fn)
    argModifiers.list[#argModifiers.list+1] = {pattern=pattern,index=argIndex,fn=fn}
end

local function applyArgumentModifiers(remoteName, args)
    if not argModifiers.enabled or #argModifiers.list==0 then return args end
    local out = {}; for i,v in ipairs(args) do out[i]=v end
    for _,mod in ipairs(argModifiers.list) do
        if remoteName:find(mod.pattern) then
            if mod.index then
                if out[mod.index] ~= nil then
                    local ok,nv = pcall(mod.fn,out[mod.index])
                    if ok and nv~=nil and nv~=out[mod.index] then
                        print(("  [Modify] %s[%d] → %s"):format(remoteName,mod.index,serial(nv)))
                        out[mod.index] = nv
                    end
                end
            else
                for i,v in ipairs(out) do
                    local ok,nv = pcall(mod.fn,v,out,i)
                    if ok and nv~=nil and nv~=v then
                        print(("  [Modify] %s[%d] → %s"):format(remoteName,i,serial(nv)))
                        out[i] = nv
                    end
                end
            end
        end
    end
    return out
end

-- STACK TRACER
local stackTracer = { enabled=false, maxFrames=8 }

local function getStackTrace(startFrame)
    startFrame = startFrame or 3
    local frames = {}
    for i=startFrame,startFrame+stackTracer.maxFrames do
        local info = debug.getinfo and debug.getinfo(i,"Sln")
        if not info then break end
        local src = (info.short_src or "?"):gsub(".*[/\\]","")
        if not src:find("remote_spy",1,true) then
            frames[#frames+1] = ("  #%d %s:%d%s"):format(
                i-startFrame+1, src, info.currentline or 0,
                info.name and " fn:"..info.name or "")
        end
    end
    return #frames>0 and frames or {"  (no stack info)"}
end

-- INYECCIÓN DE CÓDIGO
local injector = { list={}, enabled=true }

local function addInjection(pattern, before, after, replace)
    injector.list[#injector.list+1] = {pattern=pattern,before=before,after=after,replace=replace}
end

local function applyInjections(remoteName, args, originalFn)
    if not injector.enabled then return originalFn(table.unpack(args)) end
    for _,inj in ipairs(injector.list) do
        if remoteName:find(inj.pattern) then
            if inj.before  then pcall(inj.before,args) end
            local ok,ret = true,nil
            if inj.replace then ok,ret=pcall(inj.replace,args)
            else ok,ret=pcall(originalFn,table.unpack(args)) end
            if inj.after then pcall(inj.after,args,ok and ret or nil) end
            return ok and ret or nil
        end
    end
    return originalFn(table.unpack(args))
end

-- HOOK PIPELINE
local pipeline = { stages={pre={},main={},post={}}, enabled=true }

local function addHookStage(stage, priority, fn)
    local s = pipeline.stages[stage]
    if not s then return end
    s[#s+1] = {priority=priority or 0, fn=fn}
    table.sort(s,function(a,b) return a.priority>b.priority end)
end

local function runPipeline(remoteName, args, originalFn)
    if not pipeline.enabled then return originalFn(table.unpack(args)) end
    for _,h in ipairs(pipeline.stages.pre) do
        local ok,res = pcall(h.fn,remoteName,args)
        if ok and res==false then return nil end
    end
    local result, overridden = nil, false
    for _,h in ipairs(pipeline.stages.main) do
        local ok,res = pcall(h.fn,remoteName,args)
        if ok and res~=nil then result=res; overridden=true; break end
    end
    if not overridden then result=originalFn(table.unpack(args)) end
    for _,h in ipairs(pipeline.stages.post) do pcall(h.fn,remoteName,args,result) end
    return result
end

-- HOOKS SELECTIVOS
local selectiveHooks = { list={}, cache={} }

local function addSelectiveHook(pattern, fn, method)
    selectiveHooks.list[#selectiveHooks.list+1] = {pattern=pattern,fn=fn,method=method or "both"}
end

local function runSelectiveHooks(remoteName, method, args)
    local now = os.clock()
    for _,sh in ipairs(selectiveHooks.list) do
        if sh.method=="both" or sh.method==method then
            local key    = sh.pattern.."|"..remoteName
            local cached = selectiveHooks.cache[key]
            local matched = false
            if cached and (now-cached.t)<5 then matched=cached.v
            else matched=remoteName:find(sh.pattern)~=nil
                 selectiveHooks.cache[key]={v=matched,t=now} end
            if matched then pcall(sh.fn,args) end
        end
    end
end

-- WEBHOOK
local IMPORTANT = {"admin","god","ban","kick","delete","give","unban","mute","warning","report","exploit"}

local function isImportant(nombre, args)
    local h = nombre:lower()
    for _,p in ipairs(IMPORTANT) do if h:find(p,1,true) then return true end end
    for _,v in ipairs(args) do
        local s = tostring(v):lower()
        for _,p in ipairs(IMPORTANT) do if s:find(p,1,true) then return true end end
    end
    return false
end

local function sendWebhook(msg)
    if CFG.WEBHOOK_URL=="" then return end
    pcall(function()
        HttpService:RequestAsync({
            Url=CFG.WEBHOOK_URL, Method="POST",
            Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode({content=msg:sub(1,1900)}),
        })
    end)
end

-- GRABADORA
local recorder = { recording=false, playing=false, events={}, startT=0 }

local function startRecording()
    recorder.recording=true; recorder.events={}; recorder.startT=os.clock()
    print("[Recorder] Iniciado")
end

local function stopRecording()
    recorder.recording=false
    print(("[Recorder] %d eventos guardados"):format(#recorder.events))
end

local function recordEvent(nombre, ruta, args)
    if not recorder.recording then return end
    recorder.events[#recorder.events+1] = {t=os.clock()-recorder.startT,name=nombre,ruta=ruta,args=args}
end

local function startPlayback()
    if #recorder.events==0 then print("[Recorder] Sin eventos"); return end
    recorder.playing=true
    print(("[Recorder] Reproduciendo %d eventos"):format(#recorder.events))
    task.spawn(function()
        local prev=0
        for _,ev in ipairs(recorder.events) do
            if not recorder.playing then break end
            local d=ev.t-prev; if d>0 then task.wait(d) end
            prev=ev.t
            local found=RepStorage:FindFirstChild(ev.name,true)
            if found then
                if found:IsA("RemoteEvent") then
                    pcall(function() found:FireServer(table.unpack(ev.args)) end)
                elseif found:IsA("RemoteFunction") then
                    pcall(function() found:InvokeServer(table.unpack(ev.args)) end)
                end
                print(("  Replay: %s"):format(ev.name))
            end
        end
        recorder.playing=false
        print("[Recorder] Completo")
    end)
end

-- ANÁLISIS DE TRÁFICO
local traffic = { counts={}, ts={}, window=60 }

local function recordTraffic(nombre)
    local now=os.clock(); local cutoff=now-traffic.window
    traffic.counts[nombre]=(traffic.counts[nombre] or 0)+1
    traffic.ts[nombre]=traffic.ts[nombre] or {}
    local t=traffic.ts[nombre]; t[#t+1]=now
    local i=1; while i<=#t and t[i]<cutoff do i=i+1 end
    if i>1 then local nt={}; for j=i,#t do nt[#nt+1]=t[j] end; traffic.ts[nombre]=nt end
end

local function analyzeTraffic()
    local sorted={}
    for name,cnt in pairs(traffic.counts) do
        sorted[#sorted+1]={name=name,total=cnt,recent=#(traffic.ts[name] or {})}
    end
    table.sort(sorted,function(a,b) return a.recent>b.recent end)
    print(("Top remotes (ultimo %ds):"):format(traffic.window))
    for i=1,math.min(5,#sorted) do
        local s=sorted[i]
        print(("  #%d %-28s reciente:%d total:%d"):format(i,s.name,s.recent,s.total))
    end
    return sorted
end

-- ESTADÍSTICAS
local stats = { total=0, byMethod={}, byAction={}, byRemote={}, startT=os.time() }

local function updateStats(metodo,nombre,accion)
    stats.total=stats.total+1
    stats.byMethod[metodo]=(stats.byMethod[metodo] or 0)+1
    stats.byAction[accion]=(stats.byAction[accion] or 0)+1
    stats.byRemote[nombre]=(stats.byRemote[nombre] or 0)+1
end

local function showStats()
    local up=os.time()-stats.startT
    local eps=up>0 and ("%.2f"):format(stats.total/up) or "0"
    print(("Activo: %ds  Total: %d  (%s ev/s)"):format(up,stats.total,eps))
    print("Metodos:")
    for m,c in pairs(stats.byMethod) do print(("  %-22s %d"):format(m,c)) end
    print("Top acciones:")
    local sa={}; for a,c in pairs(stats.byAction) do sa[#sa+1]={a,c} end
    table.sort(sa,function(a,b) return a[2]>b[2] end)
    for i=1,math.min(5,#sa) do print(("  %-24s %d"):format(sa[i][1],sa[i][2])) end
    print("Top remotes:")
    local sr={}; for n,c in pairs(stats.byRemote) do sr[#sr+1]={n,c} end
    table.sort(sr,function(a,b) return a[2]>b[2] end)
    for i=1,math.min(8,#sr) do print(("  %-28s %d"):format(sr[i][1],sr[i][2])) end
end

-- BÚSQUEDA
local liveSearch = { enabled=false, query="" }

local function searchLogs(query)
    local q=query:lower(); local found={}
    for _,e in ipairs(logs) do
        if (e.nombre..e.accion..e.ruta..serial(e.args)):lower():find(q,1,true) then
            found[#found+1]=e
        end
    end
    print(("'%s' -> %d resultado(s):"):format(query,#found))
    for _,e in ipairs(found) do
        print(("  #%d [%s] %s %s -> %s"):format(e.id,e.time,e.metodo,e.nombre,e.accion))
    end
    return found
end

local function startLiveSearch(query)
    liveSearch.enabled=true; liveSearch.query=query
    task.spawn(function()
        while liveSearch.enabled do
            task.wait(2)
            if liveSearch.enabled then searchLogs(liveSearch.query) end
        end
    end)
    print(("Live search: '%s'"):format(query))
end

-- EXPORTACIÓN
local function exportTxt(data)
    local L={}
    for _,e in ipairs(data) do
        L[#L+1]=("[%s] #%d %s %s -> %s"):format(e.time,e.id,e.metodo,e.nombre,e.accion)
        for _,l in ipairs(prettyArgs(e.args)) do L[#L+1]=l end
        L[#L+1]=string.rep("-",50)
    end
    return table.concat(L,"\n")
end

local function exportCsv(data)
    local L={"id,time,method,name,route,action,args"}
    for _,e in ipairs(data) do
        L[#L+1]=('%d,"%s","%s","%s","%s","%s","%s"'):format(
            e.id,e.time,e.metodo,e.nombre,e.ruta,e.accion,
            serial(e.args):gsub('"','""'))
    end
    return table.concat(L,"\n")
end

local function exportJson(data)
    local parts={}
    for _,e in ipairs(data) do
        local a={}; for _,v in ipairs(e.args) do a[#a+1]=serial(v) end
        parts[#parts+1]=('{"id":%d,"time":"%s","method":"%s","name":"%s",'..
            '"route":"%s","action":"%s","args":[%s]}'):format(
            e.id,e.time,e.metodo,e.nombre,e.ruta,e.accion,table.concat(a,","))
    end
    return "[\n"..table.concat(parts,",\n").."\n]"
end

local function exportHtml(data)
    local rows={}
    local MC={FireServer="#ff5555",InvokeServer="#ffb432",["SERVER->CLIENT"]="#55c8ff"}
    for _,e in ipairs(data) do
        local arg=serial(e.args):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
        local clr=MC[e.metodo] or "#aaffaa"
        rows[#rows+1]=('<tr><td>%d</td><td>%s</td><td style="color:%s">%s</td>'..
            '<td>%s</td><td>%s</td><td><small>%s</small></td></tr>'):format(
            e.id,e.time,clr,e.metodo,e.nombre,e.accion,arg)
    end
    return table.concat({
        '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Spy v6</title>',
        '<style>body{background:#111;color:#eee;font-family:monospace}',
        'table{width:100%;border-collapse:collapse}',
        'th{background:#333;padding:6px}td{padding:4px;border-bottom:1px solid #222}',
        'tr:hover{background:#1a1a2e}</style></head><body>',
        '<h2 style="color:#ff5555">Remote Spy v6</h2>',
        '<table><tr><th>#</th><th>Time</th><th>Method</th><th>Remote</th>',
        '<th>Action</th><th>Args</th></tr>',
        table.concat(rows),
        '</table></body></html>',
    },"")
end

local EXPORTERS = {txt=exportTxt,csv=exportCsv,json=exportJson,html=exportHtml}

local function exportFormat(fmt)
    local fn=EXPORTERS[fmt or "txt"]
    if not fn then print("Formato desconocido: "..tostring(fmt)); return end
    local out=fn(logs)
    local filename="spy_"..os.time().."."..fmt
    if type(writefile)=="function" then
        pcall(writefile,filename,out)
        print(("Guardado: '%s'"):format(filename))
    else
        print(out:sub(1,3000))
        if #out>3000 then print("... ("..#out.." chars)") end
    end
    return out
end

-- STEALTH
local stealth = { enabled=CFG.STEALTH, fakeTraffic=CFG.FAKE_TRAFFIC }

local function advancedHide()
    if not stealth.enabled then return end
    if type(getgc)=="function" then
        local ok,gc = pcall(getgc,true)
        if ok and gc then
            for _,v in ipairs(gc) do
                if type(v)=="table" and rawget(v,"_SPY_MARKER") then
                    rawset(v,"_SPY_MARKER",nil)
                end
            end
        end
    end
end

local function createFakeTraffic()
    if not stealth.fakeTraffic then return end
    task.spawn(function()
        while stealth.fakeTraffic do
            task.wait(math.random(3,8))
            pcall(function()
                for _,d in ipairs(RepStorage:GetDescendants()) do
                    if d:IsA("RemoteEvent") then d:FireServer(); break end
                end
            end)
        end
    end)
end

-- COLORES
local METHOD_COLOR = {
    FireServer          = Color3.fromRGB(255,80,80),
    InvokeServer        = Color3.fromRGB(255,180,50),
    ["SERVER->CLIENT"]  = Color3.fromRGB(80,200,255),
    BOTON               = Color3.fromRGB(150,255,150),
    BINDABLE            = Color3.fromRGB(200,150,255),
}

-- GUI  (panel SPY + panel BUILDER)
local GUI = {}

local function mkCorner(p,r) Instance.new("UICorner",p).CornerRadius=UDim.new(0,r or 6) end
local function mkPad(p,l) Instance.new("UIPadding",p).PaddingLeft=UDim.new(0,l or 5) end
local function mkStroke(p,c,t)
    local s=Instance.new("UIStroke",p); s.Color=c; s.Thickness=t or 1; return s
end

local function mkLabel(parent,txt,color,size,lo,bold)
    local l=Instance.new("TextLabel",parent)
    l.Size=UDim2.new(1,-6,0,0); l.AutomaticSize=Enum.AutomaticSize.Y
    l.BackgroundTransparency=1; l.Text=txt; l.TextColor3=color
    l.Font=bold and Enum.Font.GothamBold or Enum.Font.Code
    l.TextSize=size or 11; l.TextWrapped=true
    l.TextXAlignment=Enum.TextXAlignment.Left
    if lo then l.LayoutOrder=lo end
    return l
end

local function mkBtn(parent,txt,color,size,pos)
    local b=Instance.new("TextButton",parent)
    b.Size=size or UDim2.new(0,60,0,20)
    if pos then b.Position=pos end
    b.BackgroundColor3=color; b.Text=txt
    b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold
    b.TextSize=10; b.BorderSizePixel=0; b.AutoButtonColor=true
    mkCorner(b,4); return b
end

if CFG.GUI_ENABLED and player then
    local sg=Instance.new("ScreenGui")
    sg.Name="SpyV6"; sg.ResetOnSpawn=false
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.IgnoreGuiInset=true
    pcall(function()
        sg.Parent=(type(gethui)=="function" and gethui()) or player:WaitForChild("PlayerGui",5)
    end)

    -- Ventana principal
    local win=Instance.new("Frame",sg)
    win.Size=UDim2.new(0,520,0,420); win.Position=UDim2.new(1,-530,0,10)
    win.BackgroundColor3=Color3.fromRGB(10,10,16)
    win.BorderSizePixel=0; win.Active=true; win.Draggable=true
    mkCorner(win,8); mkStroke(win,Color3.fromRGB(180,40,40),1.5)

    -- Barra título
    local bar=Instance.new("Frame",win)
    bar.Size=UDim2.new(1,0,0,28); bar.BackgroundColor3=Color3.fromRGB(20,5,5)
    bar.BorderSizePixel=0; mkCorner(bar,8)

    local title=Instance.new("TextLabel",bar)
    title.Size=UDim2.new(0,160,1,0); title.Position=UDim2.new(0,8,0,0)
    title.BackgroundTransparency=1; title.Text="Remote Spy v6"
    title.TextColor3=Color3.fromRGB(255,60,60); title.Font=Enum.Font.GothamBold
    title.TextSize=13; title.TextXAlignment=Enum.TextXAlignment.Left

    local cntLbl=Instance.new("TextLabel",bar)
    cntLbl.Size=UDim2.new(0,45,1,0); cntLbl.Position=UDim2.new(1,-118,0,0)
    cntLbl.BackgroundTransparency=1; cntLbl.Text="#0"
    cntLbl.TextColor3=Color3.fromRGB(100,100,100); cntLbl.Font=Enum.Font.Gotham
    cntLbl.TextSize=11; cntLbl.TextXAlignment=Enum.TextXAlignment.Right
    GUI.counter=cntLbl

    local btnClose=mkBtn(bar,"x",Color3.fromRGB(200,40,40),UDim2.new(0,22,0,22),UDim2.new(1,-26,0,3))
    btnClose.TextSize=15
    btnClose.MouseButton1Click:Connect(function() win.Visible=false end)

    local btnClr=mkBtn(bar,"CLR",Color3.fromRGB(40,40,60),UDim2.new(0,36,0,18),UDim2.new(1,-67,0,5))
    btnClr.TextColor3=Color3.fromRGB(200,200,200)

    -- Tabs
    local tabBar=Instance.new("Frame",win)
    tabBar.Size=UDim2.new(1,0,0,26); tabBar.Position=UDim2.new(0,0,0,28)
    tabBar.BackgroundColor3=Color3.fromRGB(15,15,22); tabBar.BorderSizePixel=0

    local tl=Instance.new("UIListLayout",tabBar)
    tl.FillDirection=Enum.FillDirection.Horizontal
    tl.SortOrder=Enum.SortOrder.LayoutOrder; tl.Padding=UDim.new(0,2)
    Instance.new("UIPadding",tabBar).PaddingLeft=UDim.new(0,4)

    -- Contenidos de tabs
    local tabSpy     = Instance.new("Frame",win)
    tabSpy.Size      = UDim2.new(1,0,1,-54); tabSpy.Position=UDim2.new(0,0,0,54)
    tabSpy.BackgroundTransparency=1; tabSpy.BorderSizePixel=0

    local tabBuilder = Instance.new("Frame",win)
    tabBuilder.Size  = UDim2.new(1,0,1,-54); tabBuilder.Position=UDim2.new(0,0,0,54)
    tabBuilder.BackgroundTransparency=1; tabBuilder.BorderSizePixel=0
    tabBuilder.Visible=false

    local function setTab(name)
        tabSpy.Visible     = (name=="spy")
        tabBuilder.Visible = (name=="builder")
    end

    local function makeTab(label,name,lo)
        local tb=Instance.new("TextButton",tabBar)
        tb.Size=UDim2.new(0,88,1,-4); tb.LayoutOrder=lo
        tb.BackgroundColor3=Color3.fromRGB(30,30,40); tb.Text=label
        tb.TextColor3=Color3.fromRGB(200,200,200); tb.Font=Enum.Font.GothamBold
        tb.TextSize=11; tb.BorderSizePixel=0
        mkCorner(tb,4)
        tb.MouseButton1Click:Connect(function()
            setTab(name)
            tb.BackgroundColor3=Color3.fromRGB(180,40,40)
            tb.TextColor3=Color3.new(1,1,1)
        end)
        return tb
    end
    local tabBtnSpy = makeTab("SPY","spy",1)
    tabBtnSpy.BackgroundColor3=Color3.fromRGB(180,40,40)
    tabBtnSpy.TextColor3=Color3.new(1,1,1)
    makeTab("SCRIPT BUILDER","builder",2)

    -- TAB SPY

    -- Filtro de texto
    local fBar=Instance.new("Frame",tabSpy)
    fBar.Size=UDim2.new(1,-8,0,22); fBar.Position=UDim2.new(0,4,0,2)
    fBar.BackgroundColor3=Color3.fromRGB(18,18,28); fBar.BorderSizePixel=0
    mkCorner(fBar,4)

    local filterBox=Instance.new("TextBox",fBar)
    filterBox.Size=UDim2.new(1,-8,1,-4); filterBox.Position=UDim2.new(0,4,0,2)
    filterBox.BackgroundTransparency=1; filterBox.Text=""
    filterBox.PlaceholderText="Filtrar por nombre, accion..."
    filterBox.TextColor3=Color3.fromRGB(220,220,220)
    filterBox.PlaceholderColor3=Color3.fromRGB(70,70,70)
    filterBox.Font=Enum.Font.Code; filterBox.TextSize=11
    filterBox.TextXAlignment=Enum.TextXAlignment.Left
    filterBox.ClearTextOnFocus=false
    GUI.filterBox=filterBox

    -- Botones de tipo
    local typeBar=Instance.new("Frame",tabSpy)
    typeBar.Size=UDim2.new(1,-8,0,20); typeBar.Position=UDim2.new(0,4,0,26)
    typeBar.BackgroundTransparency=1
    local tl2=Instance.new("UIListLayout",typeBar)
    tl2.FillDirection=Enum.FillDirection.Horizontal
    tl2.SortOrder=Enum.SortOrder.LayoutOrder; tl2.Padding=UDim.new(0,3)

    local activeFilters={FireServer=true,InvokeServer=true,["SERVER->CLIENT"]=true,BOTON=true,BINDABLE=true}
    GUI.activeFilters=activeFilters

    for _,typ in ipairs({"FireServer","InvokeServer","SERVER->CLIENT","BOTON","BINDABLE"}) do
        local lbl={FireServer="Fire",InvokeServer="Invoke",["SERVER->CLIENT"]="S→C",BOTON="Btn",BINDABLE="Bind"}
        local tb=Instance.new("TextButton",typeBar)
        tb.Size=UDim2.new(0,68,1,0); tb.BackgroundColor3=METHOD_COLOR[typ]
        tb.Text=lbl[typ]; tb.Font=Enum.Font.GothamBold; tb.TextSize=9
        tb.BorderSizePixel=0; tb.BackgroundTransparency=0.2
        mkCorner(tb,3)
        local function ref()
            tb.BackgroundTransparency=activeFilters[typ] and 0.1 or 0.75
            tb.TextColor3=activeFilters[typ] and Color3.fromRGB(10,10,10) or Color3.fromRGB(120,120,120)
        end
        tb.MouseButton1Click:Connect(function() activeFilters[typ]=not activeFilters[typ]; ref() end)
    end

    -- Scroll spy
    local scroll=Instance.new("ScrollingFrame",tabSpy)
    scroll.Size=UDim2.new(1,-8,1,-50); scroll.Position=UDim2.new(0,4,0,48)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=4; scroll.ScrollBarImageColor3=Color3.fromRGB(200,40,40)
    scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    local sl=Instance.new("UIListLayout",scroll)
    sl.SortOrder=Enum.SortOrder.LayoutOrder; sl.Padding=UDim.new(0,2)
    GUI.scroll=scroll; GUI.entries={}

    local function applyFilter()
        local q=(filterBox.Text or ""):lower()
        for _,e in ipairs(GUI.entries) do
            e.frame.Visible=(q=="" or e.text:lower():find(q,1,true)) and activeFilters[e.metodo]==true
        end
    end
    filterBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)
    GUI.applyFilter=applyFilter

    btnClr.MouseButton1Click:Connect(function()
        for _,e in ipairs(GUI.entries) do pcall(function() e.frame:Destroy() end) end
        GUI.entries={}
    end)

    -- TAB BUILDER

    -- Panel izquierdo: lista de remotes añadidos
    local leftPanel=Instance.new("Frame",tabBuilder)
    leftPanel.Size=UDim2.new(0,170,1,-4); leftPanel.Position=UDim2.new(0,4,0,2)
    leftPanel.BackgroundColor3=Color3.fromRGB(14,14,22); leftPanel.BorderSizePixel=0
    mkCorner(leftPanel,6)

    local leftTitle=Instance.new("TextLabel",leftPanel)
    leftTitle.Size=UDim2.new(1,0,0,22); leftTitle.BackgroundColor3=Color3.fromRGB(20,5,5)
    leftTitle.BorderSizePixel=0; leftTitle.Text="Remotes añadidos"
    leftTitle.TextColor3=Color3.fromRGB(255,80,80); leftTitle.Font=Enum.Font.GothamBold
    leftTitle.TextSize=11; mkCorner(leftTitle,6)

    local leftScroll=Instance.new("ScrollingFrame",leftPanel)
    leftScroll.Size=UDim2.new(1,-4,1,-60); leftScroll.Position=UDim2.new(0,2,0,24)
    leftScroll.BackgroundTransparency=1; leftScroll.BorderSizePixel=0
    leftScroll.ScrollBarThickness=3; leftScroll.ScrollBarImageColor3=Color3.fromRGB(180,40,40)
    leftScroll.CanvasSize=UDim2.new(0,0,0,0); leftScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    local lsl=Instance.new("UIListLayout",leftScroll)
    lsl.SortOrder=Enum.SortOrder.LayoutOrder; lsl.Padding=UDim.new(0,2)
    GUI.builderList=leftScroll

    -- Opciones de template
    local optFrame=Instance.new("Frame",leftPanel)
    optFrame.Size=UDim2.new(1,-4,0,56); optFrame.Position=UDim2.new(0,2,1,-58)
    optFrame.BackgroundColor3=Color3.fromRGB(18,18,28); optFrame.BorderSizePixel=0
    mkCorner(optFrame,4)

    local optLayout=Instance.new("UIListLayout",optFrame)
    optLayout.SortOrder=Enum.SortOrder.LayoutOrder; optLayout.Padding=UDim.new(0,2)
    Instance.new("UIPadding",optFrame).PaddingLeft=UDim.new(0,4)

    local optTitle=Instance.new("TextLabel",optFrame)
    optTitle.Size=UDim2.new(1,0,0,14); optTitle.BackgroundTransparency=1
    optTitle.Text="Template:"; optTitle.TextColor3=Color3.fromRGB(150,150,150)
    optTitle.Font=Enum.Font.GothamBold; optTitle.TextSize=10
    optTitle.TextXAlignment=Enum.TextXAlignment.Left; optTitle.LayoutOrder=1

    local templates={"loop","once","conditional","autoFarm","listener"}
    local templateBtns={}
    local templateRow=Instance.new("Frame",optFrame)
    templateRow.Size=UDim2.new(1,-4,0,18); templateRow.BackgroundTransparency=1
    templateRow.LayoutOrder=2
    local trl=Instance.new("UIListLayout",templateRow)
    trl.FillDirection=Enum.FillDirection.Horizontal
    trl.SortOrder=Enum.SortOrder.LayoutOrder; trl.Padding=UDim.new(0,2)

    local function refreshTemplateBtns()
        for _,tb in ipairs(templateBtns) do
            tb.btn.BackgroundColor3 = tb.name==SB.template
                and Color3.fromRGB(180,40,40) or Color3.fromRGB(40,40,60)
        end
    end

    local tLabels={loop="Loop",once="Once",conditional="Cond",autoFarm="Farm",listener="Listen"}
    for _,tname in ipairs(templates) do
        local tb2=Instance.new("TextButton",templateRow)
        tb2.Size=UDim2.new(0,36,1,0); tb2.BackgroundColor3=Color3.fromRGB(40,40,60)
        tb2.Text=tLabels[tname]; tb2.TextColor3=Color3.new(1,1,1)
        tb2.Font=Enum.Font.GothamBold; tb2.TextSize=8; tb2.BorderSizePixel=0
        mkCorner(tb2,3)
        templateBtns[#templateBtns+1]={btn=tb2,name=tname}
        tb2.MouseButton1Click:Connect(function()
            SB.template=tname
            refreshTemplateBtns()
            if GUI.refreshBuilder then GUI.refreshBuilder() end
        end)
    end
    refreshTemplateBtns()

    -- Delay row
    local delayRow=Instance.new("Frame",optFrame)
    delayRow.Size=UDim2.new(1,-4,0,18); delayRow.BackgroundTransparency=1; delayRow.LayoutOrder=3
    local dlbl=Instance.new("TextLabel",delayRow)
    dlbl.Size=UDim2.new(0,70,1,0); dlbl.BackgroundTransparency=1
    dlbl.Text="Delay (s):"..SB.loopDelay; dlbl.TextColor3=Color3.fromRGB(150,150,150)
    dlbl.Font=Enum.Font.GothamBold; dlbl.TextSize=9
    dlbl.TextXAlignment=Enum.TextXAlignment.Left
    local dbox=Instance.new("TextBox",delayRow)
    dbox.Size=UDim2.new(0,50,1,0); dbox.Position=UDim2.new(0,74,0,0)
    dbox.BackgroundColor3=Color3.fromRGB(20,20,35); dbox.TextColor3=Color3.new(1,1,1)
    dbox.Font=Enum.Font.Code; dbox.TextSize=10; dbox.Text=tostring(SB.loopDelay)
    dbox.BorderSizePixel=0; mkCorner(dbox,3)
    dbox:GetPropertyChangedSignal("Text"):Connect(function()
        local n=tonumber(dbox.Text)
        if n and n>=0 then
            SB.loopDelay=n
            dlbl.Text="Delay (s):"..n
            if GUI.refreshBuilder then GUI.refreshBuilder() end
        end
    end)

    -- Panel derecho: preview del código
    local rightPanel=Instance.new("Frame",tabBuilder)
    rightPanel.Size=UDim2.new(1,-182,1,-4); rightPanel.Position=UDim2.new(0,178,0,2)
    rightPanel.BackgroundColor3=Color3.fromRGB(12,12,20); rightPanel.BorderSizePixel=0
    mkCorner(rightPanel,6)

    local rightTitle=Instance.new("Frame",rightPanel)
    rightTitle.Size=UDim2.new(1,0,0,26); rightTitle.BackgroundColor3=Color3.fromRGB(18,5,5)
    rightTitle.BorderSizePixel=0; mkCorner(rightTitle,6)

    local rtLbl=Instance.new("TextLabel",rightTitle)
    rtLbl.Size=UDim2.new(0.6,0,1,0); rtLbl.Position=UDim2.new(0,8,0,0)
    rtLbl.BackgroundTransparency=1; rtLbl.Text="Codigo generado"
    rtLbl.TextColor3=Color3.fromRGB(255,80,80); rtLbl.Font=Enum.Font.GothamBold
    rtLbl.TextSize=12; rtLbl.TextXAlignment=Enum.TextXAlignment.Left

    local btnCopy=mkBtn(rightTitle,"COPIAR",Color3.fromRGB(40,160,40),UDim2.new(0,60,0,18),UDim2.new(1,-130,0,4))
    local btnSave=mkBtn(rightTitle,"GUARDAR",Color3.fromRGB(40,80,180),UDim2.new(0,68,0,18),UDim2.new(1,-64,0,4))

    local codeScroll=Instance.new("ScrollingFrame",rightPanel)
    codeScroll.Size=UDim2.new(1,-6,1,-32); codeScroll.Position=UDim2.new(0,3,0,28)
    codeScroll.BackgroundTransparency=1; codeScroll.BorderSizePixel=0
    codeScroll.ScrollBarThickness=4; codeScroll.ScrollBarImageColor3=Color3.fromRGB(40,160,40)
    codeScroll.CanvasSize=UDim2.new(0,0,0,0); codeScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    local csl=Instance.new("UIListLayout",codeScroll)
    csl.SortOrder=Enum.SortOrder.LayoutOrder; csl.Padding=UDim.new(0,0)

    local codeLbl=Instance.new("TextLabel",codeScroll)
    codeLbl.Size=UDim2.new(1,-8,0,0); codeLbl.AutomaticSize=Enum.AutomaticSize.Y
    codeLbl.BackgroundTransparency=1; codeLbl.Text="-- Sin remotes\n-- Usa [+] en el panel SPY"
    codeLbl.TextColor3=Color3.fromRGB(140,220,140); codeLbl.Font=Enum.Font.Code
    codeLbl.TextSize=11; codeLbl.TextWrapped=true; codeLbl.TextXAlignment=Enum.TextXAlignment.Left
    codeLbl.LayoutOrder=1; Instance.new("UIPadding",codeScroll).PaddingLeft=UDim.new(0,6)
    GUI.codeLbl=codeLbl

    -- Refresca la lista de remotes y el código
    local function refreshBuilder()
        -- Limpiar lista
        for _,c in ipairs(leftScroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        -- Reconstruir lista de items
        for idx,item in ipairs(SB.items) do
            local row=Instance.new("Frame",leftScroll)
            row.Size=UDim2.new(1,-4,0,36); row.BackgroundColor3=Color3.fromRGB(20,20,30)
            row.BorderSizePixel=0; row.LayoutOrder=idx
            mkCorner(row,4); mkPad(row,4)

            -- Toggle enable
            local toggleBtn=Instance.new("TextButton",row)
            toggleBtn.Size=UDim2.new(0,14,0,14); toggleBtn.Position=UDim2.new(1,-18,0,4)
            toggleBtn.BackgroundColor3=item.enabled and Color3.fromRGB(40,180,40) or Color3.fromRGB(100,100,100)
            toggleBtn.Text=""; toggleBtn.BorderSizePixel=0
            mkCorner(toggleBtn,3)
            toggleBtn.MouseButton1Click:Connect(function()
                item.enabled=not item.enabled
                toggleBtn.BackgroundColor3=item.enabled and Color3.fromRGB(40,180,40) or Color3.fromRGB(100,100,100)
                refreshBuilder()
            end)

            -- Botón quitar
            local rmBtn=Instance.new("TextButton",row)
            rmBtn.Size=UDim2.new(0,14,0,14); rmBtn.Position=UDim2.new(1,-18,0,20)
            rmBtn.BackgroundColor3=Color3.fromRGB(180,40,40); rmBtn.Text="x"
            rmBtn.TextColor3=Color3.new(1,1,1); rmBtn.Font=Enum.Font.GothamBold
            rmBtn.TextSize=9; rmBtn.BorderSizePixel=0
            mkCorner(rmBtn,3)
            rmBtn.MouseButton1Click:Connect(function()
                sbRemove(idx)
                refreshBuilder()
            end)

            -- Nombre + método
            local nameLbl=Instance.new("TextLabel",row)
            nameLbl.Size=UDim2.new(1,-24,0,16); nameLbl.Position=UDim2.new(0,0,0,2)
            nameLbl.BackgroundTransparency=1; nameLbl.Text=item.entry.nombre
            nameLbl.TextColor3=item.enabled and Color3.fromRGB(220,220,220) or Color3.fromRGB(100,100,100)
            nameLbl.Font=Enum.Font.GothamBold; nameLbl.TextSize=10
            nameLbl.TextXAlignment=Enum.TextXAlignment.Left; nameLbl.TextTruncate=Enum.TextTruncate.AtEnd

            local metLbl=Instance.new("TextLabel",row)
            metLbl.Size=UDim2.new(1,-24,0,14); metLbl.Position=UDim2.new(0,0,0,20)
            metLbl.BackgroundTransparency=1
            metLbl.Text=item.entry.metodo.." | "..item.entry.accion
            metLbl.TextColor3=METHOD_COLOR[item.entry.metodo] or Color3.fromRGB(150,150,150)
            metLbl.Font=Enum.Font.Code; metLbl.TextSize=9
            metLbl.TextXAlignment=Enum.TextXAlignment.Left; metLbl.TextTruncate=Enum.TextTruncate.AtEnd
        end

        -- Actualizar código
        local code=generateCode()
        codeLbl.Text=code
    end
    GUI.refreshBuilder=refreshBuilder

    -- COPIAR / GUARDAR
    btnCopy.MouseButton1Click:Connect(function()
        local code=generateCode()
        if type(setclipboard)=="function" then
            pcall(setclipboard,code)
            print("[Builder] Codigo copiado al clipboard")
            btnCopy.Text="OK!"
            task.delay(1.5,function() if btnCopy and btnCopy.Parent then btnCopy.Text="COPIAR" end end)
        else
            print("[Builder] setclipboard no disponible — imprimiendo:")
            print(code)
        end
    end)

    btnSave.MouseButton1Click:Connect(function()
        local code=generateCode()
        local fname="script_"..os.time()..".lua"
        if type(writefile)=="function" then
            pcall(writefile,fname,code)
            print(("[Builder] Guardado: %s"):format(fname))
            btnSave.Text="OK!"
            task.delay(1.5,function() if btnSave and btnSave.Parent then btnSave.Text="GUARDAR" end end)
        else
            print("[Builder] writefile no disponible")
        end
    end)

    -- Toggle Insert
    UserInput.InputBegan:Connect(function(inp,gpe)
        if not gpe and inp.KeyCode==CFG.GUI_TOGGLE_KEY then
            win.Visible=not win.Visible
        end
    end)

    GUI.win=win
    GUI.refreshBuilder=refreshBuilder
end

-- COLA DE GUI  (task.spawn raíz → sin "lacking capability Plugin")
local guiQueue={}

task.spawn(function()
    while true do
        task.wait(0.05)
        if #guiQueue>0 then
            for _=1,math.min(10,#guiQueue) do
                local item=table.remove(guiQueue,1)
                if item and GUI.scroll then
                    pcall(function()
                        local clr=METHOD_COLOR[item.metodo] or Color3.fromRGB(200,200,200)
                        local callLine=remoteCallCode({nombre=item.nombre,ruta=item.ruta or "?",metodo=item.metodo,args=item.args or {}}, "")
                        local header=("[%s] %s  %s"):format(item.metodo,item.nombre,item.accion)
                        local argTxt=callLine.."\n"..table.concat(item.argsLines," | "):sub(1,350)

                        local row=Instance.new("Frame",GUI.scroll)
                        row.Size=UDim2.new(1,-6,0,0); row.AutomaticSize=Enum.AutomaticSize.Y
                        row.BackgroundColor3=Color3.fromRGB(16,16,24)
                        row.BorderSizePixel=0; row.LayoutOrder=item.logId
                        mkCorner(row,4); mkPad(row,5)
                        local il=Instance.new("UIListLayout",row)
                        il.SortOrder=Enum.SortOrder.LayoutOrder; il.Padding=UDim.new(0,0)

                        -- Header
                        local hl=Instance.new("TextLabel",row)
                        hl.Size=UDim2.new(1,-30,0,0); hl.AutomaticSize=Enum.AutomaticSize.Y
                        hl.BackgroundTransparency=1; hl.Text=header; hl.TextColor3=clr
                        hl.Font=Enum.Font.GothamBold; hl.TextSize=11; hl.TextWrapped=true
                        hl.TextXAlignment=Enum.TextXAlignment.Left; hl.LayoutOrder=1

                        -- Args
                        local al=Instance.new("TextLabel",row)
                        al.Size=UDim2.new(1,-6,0,0); al.AutomaticSize=Enum.AutomaticSize.Y
                        al.BackgroundTransparency=1; al.Text=argTxt
                        al.TextColor3=Color3.fromRGB(130,130,130); al.Font=Enum.Font.Code
                        al.TextSize=10; al.TextWrapped=true
                        al.TextXAlignment=Enum.TextXAlignment.Left; al.LayoutOrder=2

                        -- Botón [+] añadir al builder
                        local addBtn=Instance.new("TextButton",row)
                        addBtn.Size=UDim2.new(0,22,0,16); addBtn.Position=UDim2.new(1,-26,0,2)
                        addBtn.BackgroundColor3=Color3.fromRGB(40,140,40); addBtn.Text="+"
                        addBtn.TextColor3=Color3.new(1,1,1); addBtn.Font=Enum.Font.GothamBold
                        addBtn.TextSize=13; addBtn.BorderSizePixel=0; addBtn.ZIndex=3
                        mkCorner(addBtn,3)

                        addBtn.MouseButton1Click:Connect(function()
                            -- Busca la entrada original en logs
                            local entry=nil
                            for i=#logs,1,-1 do
                                if logs[i].nombre==item.nombre and logs[i].metodo==item.metodo then
                                    entry=logs[i]; break
                                end
                            end
                            if entry then
                                local added=sbAdd(entry)
                                if added then
                                    addBtn.BackgroundColor3=Color3.fromRGB(40,180,40)
                                    addBtn.Text="✓"
                                    print(("[Builder] Añadido: %s"):format(item.nombre))
                                    if GUI.refreshBuilder then
                                        task.defer(GUI.refreshBuilder)
                                    end
                                else
                                    addBtn.Text="!"
                                    addBtn.BackgroundColor3=Color3.fromRGB(180,140,0)
                                    print(("[Builder] Ya existe: %s"):format(item.nombre))
                                end
                            end
                        end)

                        -- Click fila = colapsar args
                        local expanded=true
                        row.InputBegan:Connect(function(inp)
                            if inp.UserInputType==Enum.UserInputType.MouseButton2 then
                                expanded=not expanded; al.Visible=expanded
                            end
                        end)

                        local entry={frame=row,metodo=item.metodo,nombre=item.nombre,text=header..argTxt}
                        GUI.entries[#GUI.entries+1]=entry
                        if #GUI.entries>CFG.GUI_MAX_ENTRIES then
                            local old=table.remove(GUI.entries,1)
                            pcall(function() old.frame:Destroy() end)
                        end

                        if GUI.applyFilter then GUI.applyFilter() end
                        if GUI.counter then GUI.counter.Text="#"..item.logId end
                        pcall(function()
                            GUI.scroll.CanvasPosition=Vector2.new(0,GUI.scroll.AbsoluteCanvasSize.Y)
                        end)
                    end)
                end
            end
        end
    end
end)

local function addGuiEntry(metodo,nombre,ruta,args,accion,argsLines)
    guiQueue[#guiQueue+1]={
        metodo=metodo,nombre=nombre,ruta=ruta,args=args,
        accion=accion,argsLines=argsLines,logId=logCount,
    }
end

-- LOG CENTRAL
local function log(metodo, nombre, ruta, args, retVals)
    args=args or {}; retVals=retVals or {}
    if not shouldLog(nombre) then return end
    if isSpam(spamKey(metodo,nombre,args)) then return end
    if not checkRateLimit(nombre) then return end

    local cleanArgs=sanitizeArgs(args)
    logCount=logCount+1
    local hora=os.date("%H:%M:%S")
    local accion=inferirAccion(nombre,ruta,cleanArgs)

    table.insert(logs,{
        id=logCount,time=hora,metodo=metodo,nombre=nombre,
        ruta=ruta,accion=accion,args=cleanArgs,retVals=retVals,
    })
    if #logs>600 then table.remove(logs,1) end

    updateStats(metodo,nombre,accion)
    recordTraffic(nombre)
    recordEvent(nombre,ruta,cleanArgs)
    runSelectiveHooks(nombre,metodo,cleanArgs)

    if isImportant(nombre,cleanArgs) then
        task.defer(function()
            sendWebhook(("[%s] %s | %s | %s"):format(hora,metodo,nombre,accion))
        end)
    end

    if deepInspector.enabled then
        task.defer(function()
            for i,v in ipairs(cleanArgs) do print(deepInspect(v,"arg["..i.."]")) end
        end)
    end

    if stackTracer.enabled then
        local frames=getStackTrace(4)
        task.defer(function()
            print("  StackTrace:")
            for _,f in ipairs(frames) do print(f) end
        end)
    end

    if CFG.PRINT_ENABLED then
        print("")
        print(("[%s] #%d %s -> %s"):format(hora,logCount,metodo,accion))
        print(("  Remote : %s"):format(nombre))
        print(("  Ruta   : %s"):format(ruta))
        -- Linea de codigo lista para usar
        local callLine = remoteCallCode({
            nombre=nombre, ruta=ruta, metodo=metodo, args=cleanArgs
        }, "")
        print(("  Codigo : %s"):format(callLine))
        print(("  Args   : (%d)"):format(#cleanArgs))
        for _,l in ipairs(prettyArgs(cleanArgs)) do print(l) end
        if #retVals>0 then
            print("  Return :")
            for _,l in ipairs(prettyArgs(retVals)) do print(l) end
            -- Mostrar como variable tambien
            local retParts = {}
            for _,rv in ipairs(retVals) do retParts[#retParts+1]=argToCode(rv) end
            print(("  Return Codigo: local result = %s"):format(table.concat(retParts,", ")))
        end
    end

    addGuiEntry(metodo,nombre,ruta,cleanArgs,accion,prettyArgs(cleanArgs))
end

-- HOOK 1: __namecall
pcall(function()
    local mt=getrawmetatable(game)
    local oldCall=rawget(mt,"__namecall")
    setreadonly(mt,false)
    mt.__namecall=newcclosure(function(self,...)
        local ok,met=pcall(getnamecallmethod)
        if ok and (met=="FireServer" or met=="InvokeServer") then
            if typeof(self)=="Instance" then
                local isRE,isRF=false,false
                pcall(function() isRE=self:IsA("RemoteEvent") end)
                pcall(function() isRF=self:IsA("RemoteFunction") end)
                if isRE or isRF then
                    local nombre="?"
                    pcall(function() nombre=rawget(self,"Name") or self.Name end)
                    local ruta="?"
                    pcall(function() ruta=self:GetFullName() end)
                    local capturedArgs={...}
                    task.defer(function()
                        local modArgs=applyArgumentModifiers(nombre,capturedArgs)
                        local cleanArgs=sanitizeArgs(modArgs)
                        if not shouldLog(nombre) then return end
                        if isSpam(spamKey(met,nombre,cleanArgs)) then return end
                        if not checkRateLimit(nombre) then return end
                        logCount=logCount+1
                        local hora=os.date("%H:%M:%S")
                        local accion=inferirAccion(nombre,ruta,cleanArgs)
                        table.insert(logs,{
                            id=logCount,time=hora,metodo=met,nombre=nombre,
                            ruta=ruta,accion=accion,args=cleanArgs,retVals={},
                        })
                        if #logs>600 then table.remove(logs,1) end
                        updateStats(met,nombre,accion)
                        recordTraffic(nombre)
                        recordEvent(nombre,ruta,cleanArgs)
                        runSelectiveHooks(nombre,met,cleanArgs)
                        if isImportant(nombre,cleanArgs) then
                            task.defer(function()
                                sendWebhook(("[%s] %s | %s | %s"):format(hora,met,nombre,accion))
                            end)
                        end
                        if CFG.PRINT_ENABLED then
                            print("")
                            print(("[%s] #%d %s -> %s"):format(hora,logCount,met,accion))
                            print(("  Remote : %s"):format(nombre))
                            print(("  Ruta   : %s"):format(ruta))
                            local callLine=remoteCallCode({nombre=nombre,ruta=ruta,metodo=met,args=cleanArgs},"")
                            print(("  Codigo : %s"):format(callLine))
                            print(("  Args   : (%d)"):format(#cleanArgs))
                            for _,l in ipairs(prettyArgs(cleanArgs)) do print(l) end
                        end
                        addGuiEntry(met,nombre,ruta,cleanArgs,accion,prettyArgs(cleanArgs))
                    end)
                end
            end
        end
        return oldCall(self,...)
    end)
    setreadonly(mt,true)
    namecallOk=true
end)

-- HOOK 2: hookmetamethod (backup)
if not namecallOk and hookMetaOk and newCCOk then
    pcall(function()
        hookmetamethod(game,"__namecall",newcclosure(function(self,...)
            local met=getnamecallmethod()
            if met=="FireServer" or met=="InvokeServer" then
                local nombre,ruta="?","?"
                pcall(function() nombre=self.Name end)
                pcall(function() ruta=self:GetFullName() end)
                local capturedArgs={...}
                task.defer(function() log(met,nombre,ruta,capturedArgs) end)
            end
            return hookmetamethod(game,"__namecall",...)(self,...)
        end))
        namecallOk=true
    end)
end

-- HOOK 3: hookfunction por remote
local function hookRE(remote)
    if hookeados[remote] then return end
    hookeados[remote]=true
    local nombre,ruta=remote.Name,""
    pcall(function() ruta=remote:GetFullName() end)

    if not namecallOk and hookFOk and newCCOk then
        pcall(function()
            local orig=remote.FireServer
            hookfunction(orig,newcclosure(function(self,...)
                local capturedArgs={...}
                task.defer(function()
                    log("FireServer",nombre,ruta,applyArgumentModifiers(nombre,capturedArgs))
                end)
                return orig(self,table.unpack(capturedArgs))
            end))
        end)
    end

    if CFG.CAPTURE_CLIENT then
        pcall(function()
            remote.OnClientEvent:Connect(function(...)
                local capturedArgs={...}
                task.defer(function() log("SERVER->CLIENT",nombre,ruta,capturedArgs) end)
            end)
        end)
    end
end

local function hookRF(rf)
    if hookeados[rf] then return end
    hookeados[rf]=true
    local nombre,ruta=rf.Name,""
    pcall(function() ruta=rf:GetFullName() end)

    pcall(function()
        rf.OnClientInvoke=function(...)
            local capturedArgs={...}
            task.defer(function() log("SERVER->CLIENT(Invoke)",nombre,ruta,capturedArgs) end)
        end
    end)

    if namecallOk or not hookFOk or not newCCOk then return end
    pcall(function()
        local orig=rf.InvokeServer
        hookfunction(orig,newcclosure(function(self,...)
            local capturedArgs=applyArgumentModifiers(nombre,{...})
            if CFG.CAPTURE_RETURN then
                local rets=table.pack(orig(self,...)); local retList={}
                for i=1,rets.n do retList[i]=rets[i] end
                task.defer(function() log("InvokeServer",nombre,ruta,capturedArgs,retList) end)
                return table.unpack(retList)
            else
                task.defer(function() log("InvokeServer",nombre,ruta,capturedArgs) end)
                return orig(self,...)
            end
        end))
    end)
end

local function hookBE(be)
    if hookeados[be] or not CFG.CAPTURE_BINDABLE then return end
    hookeados[be]=true
    local nombre,ruta=be.Name,""
    pcall(function() ruta=be:GetFullName() end)
    pcall(function()
        be.Event:Connect(function(...)
            local capturedArgs={...}
            task.defer(function() log("BINDABLE",nombre,ruta,capturedArgs) end)
        end)
    end)
end

local function hookBF(bf)
    if hookeados[bf] or not CFG.CAPTURE_BINDABLE then return end
    if not hookFOk or not newCCOk then return end
    hookeados[bf]=true
    local nombre,ruta=bf.Name,""
    pcall(function() ruta=bf:GetFullName() end)
    pcall(function()
        local orig=bf.Invoke
        hookfunction(orig,newcclosure(function(self,...)
            local capturedArgs={...}
            local rets=table.pack(orig(self,...)); local retList={}
            for i=1,rets.n do retList[i]=rets[i] end
            task.defer(function() log("BINDABLE(Fn)",nombre,ruta,capturedArgs,retList) end)
            return table.unpack(retList)
        end))
    end)
end

-- ESCANEO
local function hookDesc(d)
    if     d:IsA("RemoteEvent")      then hookRE(d)
    elseif d:IsA("RemoteFunction")   then hookRF(d)
    elseif d:IsA("BindableEvent")    then hookBE(d)
    elseif d:IsA("BindableFunction") then hookBF(d)
    end
end

local function escanear(obj)
    pcall(function()
        for _,d in ipairs(obj:GetDescendants()) do hookDesc(d) end
    end)
end

local function watchContainer(c)
    escanear(c)
    c.DescendantAdded:Connect(function(d) task.wait(0.05); hookDesc(d) end)
end

local containers={RepStorage,workspace}
for _,svc in ipairs({"CoreGui","StarterGui","StarterPack"}) do
    pcall(function() containers[#containers+1]=game:GetService(svc) end)
end

print("Escaneando "..#containers.." contenedores...")
for _,c in ipairs(containers) do pcall(function() watchContainer(c) end) end

pcall(function()
    if player.Character then escanear(player.Character) end
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5); escanear(char)
        char.DescendantAdded:Connect(function(d) task.wait(0.05); hookDesc(d) end)
    end)
end)

-- BOTONES GUI
local function hookBoton(btn, ruta)
    if hookedBtns[btn] then return end
    hookedBtns[btn]=true
    local texto=""
    pcall(function() texto=btn:IsA("TextButton") and btn.Text or btn.Name end)
    btn.MouseButton1Click:Connect(function()
        task.defer(function() log("BOTON",btn.Name,ruta,{texto}) end)
    end)
end

local function hookBotones(obj, path)
    for _,h in ipairs(obj:GetChildren()) do
        local ruta=path.."/"..h.Name
        if h:IsA("TextButton") or h:IsA("ImageButton") then hookBoton(h,ruta) end
        if h:IsA("GuiObject")  or h:IsA("ScreenGui")   then hookBotones(h,ruta) end
    end
end

local pg=player:FindFirstChild("PlayerGui")
if pg then
    hookBotones(pg,"PlayerGui")
    pg.DescendantAdded:Connect(function(d)
        task.wait(0.1)
        if d:IsA("TextButton") or d:IsA("ImageButton") then hookBoton(d,d:GetFullName())
        elseif d:IsA("GuiObject") then task.wait(0.2); hookBotones(d,d:GetFullName()) end
    end)
end

-- RESPAWN
player.CharacterAdded:Connect(function()
    task.wait(2)
    print("Respawn -> re-escaneando...")
    hookeados={}
    for _,c in ipairs(containers) do pcall(function() escanear(c) end) end
    local pg2=player:FindFirstChild("PlayerGui")
    if pg2 then hookBotones(pg2,"PlayerGui") end
    print("Listo")
end)

-- SETUP
if stealth.enabled then advancedHide() end
if stealth.fakeTraffic then createFakeTraffic() end

addArgumentModifier(".*", nil, function(v)
    if type(v)=="string" and v:lower():find("token") then return "[REDACTED_TOKEN]" end
    return v
end)

-- COMANDOS
local CMD={}

CMD.help=function()
    print("Remote Spy v6 — comandos:")
    print('  spy("stats")             Estadisticas')
    print('  spy("traffic")           Top remotes')
    print('  spy("search","q")        Buscar')
    print('  spy("live","q")          Live search')
    print('  spy("live","stop")       Detener live search')
    print('  spy("last",N)            Ultimos N logs')
    print('  spy("export","fmt")      txt/csv/json/html')
    print('  spy("clear")             Limpiar')
    print('  spy("filter","bl","x")   Blacklist')
    print('  spy("filter","wl","x")   Whitelist')
    print('  spy("filter","reset")    Reset filtros')
    print('  spy("record/stop/play")  Grabadora')
    print('  spy("deep","on/off")     DeepInspect')
    print('  spy("stack","on/off")    StackTrace')
    print('  spy("stealth","on/off")  Stealth')
    print('  spy("webhook","url")     Discord webhook')
    print('  spy("build","gen")       Generar script builder')
    print('  spy("build","add","name") Añadir remote al builder')
    print('  spy("build","clear")     Limpiar builder')
    print('  spy("build","tmpl","x")  Cambiar template')
    print('  spy("build","copy")      Copiar codigo')
end

CMD.stats=showStats
CMD.traffic=analyzeTraffic
CMD.record=startRecording
CMD.stop=stopRecording
CMD.play=startPlayback

CMD.search=function(q) if q then searchLogs(q) else print("spy('search','query')") end end
CMD.live=function(q)
    if q=="stop" then liveSearch.enabled=false; print("Live search detenido")
    elseif q then startLiveSearch(q) end
end
CMD.last=function(n)
    n=tonumber(n) or 5
    for i=math.max(1,#logs-n+1),#logs do
        local e=logs[i]
        print(("--- #%d [%s] %s %s -> %s ---"):format(e.id,e.time,e.metodo,e.nombre,e.accion))
        for _,l in ipairs(prettyArgs(e.args)) do print(l) end
        if e.retVals and #e.retVals>0 then
            print("  Return:")
            for _,l in ipairs(prettyArgs(e.retVals)) do print(l) end
        end
    end
end
CMD.export=function(fmt) exportFormat(fmt or "txt") end
CMD.clear=function()
    logs={}; logCount=0; spamTrack={}; rlLimits={}
    if GUI.entries then
        for _,e in ipairs(GUI.entries) do pcall(function() e.frame:Destroy() end) end
        GUI.entries={}
    end
    print("Limpiado")
end
CMD.filter=function(action,value)
    if action=="bl" and value then
        filters.blacklist[#filters.blacklist+1]=value
        print(("Blacklist += '%s'"):format(value))
    elseif action=="wl" and value then
        filters.whitelist[#filters.whitelist+1]=value
        print(("Whitelist += '%s'"):format(value))
    elseif action=="reset" then
        filters.blacklist={}; filters.whitelist={}
        print("Filtros reseteados")
    end
end
CMD.deep=function(s) deepInspector.enabled=(s=="on"); print("DeepInspect: "..s) end
CMD.stack=function(s) stackTracer.enabled=(s=="on"); print("StackTrace: "..s) end
CMD.stealth=function(s)
    stealth.enabled=(s=="on")
    if stealth.enabled then advancedHide() end
    print("Stealth: "..s)
end
CMD.webhook=function(url)
    CFG.WEBHOOK_URL=url or ""
    print("Webhook: "..(CFG.WEBHOOK_URL=="" and "OFF" or "ON"))
end
CMD.hook=function(stage,priority,fn)
    if type(fn)~="function" then print("spy('hook','pre'/'post',prio,fn)"); return end
    addHookStage(stage,tonumber(priority) or 0,fn)
    print(("Pipeline '%s' p=%s añadido"):format(stage,tostring(priority)))
end
CMD.modify=function(pattern,index,fn)
    if type(fn)~="function" then print("spy('modify',pattern,idx,fn)"); return end
    addArgumentModifier(pattern,tonumber(index),fn)
    print(("ArgModifier '%s'[%s] añadido"):format(pattern,tostring(index)))
end
CMD.inject=function(pattern,before,after)
    addInjection(pattern,before,after,nil)
    print(("Injection '%s' añadida"):format(tostring(pattern)))
end

-- Comandos del builder
CMD.build=function(action,arg1,arg2)
    if action=="gen" or action=="generate" then
        local code=generateCode()
        print("=== SCRIPT GENERADO ===")
        print(code)
        print("=======================")
        return code
    elseif action=="add" and arg1 then
        -- Añadir por nombre de remote
        local entry=nil
        for i=#logs,1,-1 do
            if logs[i].nombre==arg1 then entry=logs[i]; break end
        end
        if entry then
            local added=sbAdd(entry)
            print(added and ("Builder: añadido '%s'"):format(arg1)
                         or ("Builder: '%s' ya existe"):format(arg1))
            if GUI.refreshBuilder then task.defer(GUI.refreshBuilder) end
        else
            print(("Builder: remote '%s' no encontrado en logs"):format(arg1))
        end
    elseif action=="clear" then
        SB.items={}
        if GUI.refreshBuilder then task.defer(GUI.refreshBuilder) end
        print("Builder: limpiado")
    elseif action=="tmpl" and arg1 then
        if TEMPLATES[arg1] then
            SB.template=arg1
            if GUI.refreshBuilder then task.defer(GUI.refreshBuilder) end
            print(("Builder: template -> %s"):format(arg1))
        else
            print("Templates: loop, once, conditional, autoFarm")
        end
    elseif action=="delay" and arg1 then
        SB.loopDelay=tonumber(arg1) or 0.1
        if GUI.refreshBuilder then task.defer(GUI.refreshBuilder) end
        print(("Builder: delay -> %s"):format(SB.loopDelay))
    elseif action=="copy" then
        local code=generateCode()
        if type(setclipboard)=="function" then
            pcall(setclipboard,code)
            print("Builder: copiado al clipboard")
        else
            print(code)
        end
    elseif action=="save" then
        local code=generateCode()
        local fname="script_"..os.time()..".lua"
        if type(writefile)=="function" then
            pcall(writefile,fname,code)
            print(("Builder: guardado '%s'"):format(fname))
        else
            print("writefile no disponible")
        end
    elseif action=="list" then
        if #SB.items==0 then print("Builder: vacio"); return end
        for i,item in ipairs(SB.items) do
            print(("#%d [%s] %s -> %s  enabled=%s"):format(
                i,item.entry.metodo,item.entry.nombre,
                item.entry.accion,tostring(item.enabled)))
        end
    else
        print("spy('build','gen/add/clear/tmpl/delay/copy/save/list')")
    end
end

local function spyDispatch(cmd,...)
    if not cmd then CMD.help(); return end
    local fn=CMD[cmd]
    if fn then fn(...)
    else print(("Comando desconocido: '%s'"):format(tostring(cmd))) end
end

if type(getgenv)=="function" then getgenv().spy=spyDispatch
else _G.spy=spyDispatch end

_G.SpyStats=showStats; _G.SpyClear=CMD.clear
_G.SpySearch=searchLogs; _G.SpyLast=CMD.last; _G.SpyExport=exportFormat

print("Remote Spy v6 activo")
print("  __namecall   : "..(namecallOk and "SI" or "NO"))
print("  hookfunction : "..(hookFOk and "SI" or "NO"))
print("  GUI + Builder: "..(GUI.scroll and "SI [Insert]" or "NO"))
print('  spy("help") para comandos')
