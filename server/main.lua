local qbx = exports.qbx_core

-- Caché en memoria de amistades:  Friends[citizenid] = { [friendCid] = true, ... }
local Friends = {}

-- Solicitudes pendientes:  Pending[targetSrc] = { fromSrc, fromCid, fromName, expireAt }
local Pending = {}

-----------------------------------------------------------------------
--  HELPERS
-----------------------------------------------------------------------

---@param src number
---@return table|nil player, string|nil citizenid
local function getPlayer(src)
    local player = qbx:GetPlayer(src)
    if not player then return nil, nil end
    return player, player.PlayerData.citizenid
end

---Nombre formateado de un jugador (online) según Config.NameFormat
local function getName(player)
    return Config.NameFormat(player.PlayerData.charinfo)
end

---Source de un jugador online a partir de su citizenid (nil si está offline)
local function getSourceByCid(cid)
    local player = qbx:GetPlayerByCitizenId(cid)
    return player and player.PlayerData.source or nil
end

---¿Son amigos estos dos citizenids?
local function areFriends(cidA, cidB)
    return Friends[cidA] ~= nil and Friends[cidA][cidB] == true
end

---Envía al cliente su set de amigos ONLINE ya resueltos { id, cid, name }
---y refresca su statebag. El cliente indexa por server id para el overhead
---y el ox_target, así que solo enviamos amigos conectados (los offline no
---tienen ped ni server id).
local function syncClient(src, cid)
    local list = {}
    if Friends[cid] then
        for friendCid in pairs(Friends[cid]) do
            local online = qbx:GetPlayerByCitizenId(friendCid)
            if online then
                list[#list + 1] = {
                    id   = online.PlayerData.source,
                    cid  = friendCid,
                    name = getName(online),
                }
            end
        end
    end
    TriggerClientEvent('amigos:client:setFriends', src, list)
end

---Avisa a los amigos ONLINE del personaje `cid` de que el server id `src`
---deja de representar a ese personaje (se desconecta o cambia de personaje),
---para que limpien su FriendById y no muestren un nombre obsoleto.
local function notifyFriendsOffline(cid, src)
    if not cid or not Friends[cid] then return end
    for friendCid in pairs(Friends[cid]) do
        local friendSrc = getSourceByCid(friendCid)
        if friendSrc then
            TriggerClientEvent('amigos:client:friendOffline', friendSrc, src)
        end
    end
end

---Carga las amistades de un cid desde la BD a la caché.
local function loadFriends(cid)
    Friends[cid] = {}
    local rows = MySQL.query.await('SELECT friend_citizenid FROM player_friends WHERE citizenid = ?', { cid })
    if rows then
        for i = 1, #rows do
            Friends[cid][rows[i].friend_citizenid] = true
        end
    end
end

local function countFriends(cid)
    local n = 0
    if Friends[cid] then
        for _ in pairs(Friends[cid]) do n = n + 1 end
    end
    return n
end

-----------------------------------------------------------------------
--  RESOLUCIÓN DE NOMBRES (núcleo para overhead y chat)
-----------------------------------------------------------------------

---Nombre del jugador `targetSrc` tal y como lo ve `viewerSrc`.
---Devuelve el nombre real si son amigos (o es uno mismo); si no, Config.UnknownLabel.
---@param viewerSrc number  Quién mira
---@param targetSrc number  A quién mira
---@return string
local function displayNameFor(viewerSrc, targetSrc)
    local target = qbx:GetPlayer(targetSrc)
    if not target then return Config.UnknownLabel end

    if viewerSrc == targetSrc then
        return getName(target)
    end

    local viewer = qbx:GetPlayer(viewerSrc)
    if viewer and areFriends(viewer.PlayerData.citizenid, target.PlayerData.citizenid) then
        return getName(target)
    end

    return Config.UnknownLabel
end

-----------------------------------------------------------------------
--  CREAR / ELIMINAR AMISTADES
-----------------------------------------------------------------------

local function addFriendship(srcA, cidA, srcB, cidB)
    -- Persistencia (ambas direcciones)
    MySQL.insert('INSERT IGNORE INTO player_friends (citizenid, friend_citizenid) VALUES (?, ?), (?, ?)', {
        cidA, cidB, cidB, cidA,
    })

    -- Caché
    Friends[cidA] = Friends[cidA] or {}
    Friends[cidB] = Friends[cidB] or {}
    Friends[cidA][cidB] = true
    Friends[cidB][cidA] = true

    -- Sincronizar clientes online
    if srcA then syncClient(srcA, cidA) end
    if srcB then syncClient(srcB, cidB) end
end

local function removeFriendship(cidA, cidB)
    MySQL.query('DELETE FROM player_friends WHERE (citizenid = ? AND friend_citizenid = ?) OR (citizenid = ? AND friend_citizenid = ?)', {
        cidA, cidB, cidB, cidA,
    })

    if Friends[cidA] then Friends[cidA][cidB] = nil end
    if Friends[cidB] then Friends[cidB][cidA] = nil end

    local srcA, srcB = getSourceByCid(cidA), getSourceByCid(cidB)
    if srcA then syncClient(srcA, cidA) end
    if srcB then syncClient(srcB, cidB) end
    return srcA, srcB
end

-----------------------------------------------------------------------
--  CARGA / DESCARGA DE JUGADORES
-----------------------------------------------------------------------

RegisterNetEvent('amigos:server:playerReady', function()
    local src = source
    local player, cid = getPlayer(src)
    if not player then return end

    -- Las amistades son por PERSONAJE (citizenid). Si el jugador venía de otro
    -- personaje en este mismo slot, avisamos a los amigos de aquel personaje
    -- de que su server id ya no lo representa, antes de cargar el nuevo.
    local prev = Player(src).state.amigos
    if prev and prev.cid and prev.cid ~= cid then
        notifyFriendsOffline(prev.cid, src)
    end

    if not Friends[cid] then loadFriends(cid) end

    -- Statebag con la info pública del personaje (cid + nombre real)
    Player(src).state:set('amigos', {
        cid  = cid,
        name = getName(player),
    }, true)

    syncClient(src, cid)

    -- Re-sincronizar a los amigos que YA estaban conectados para que vean
    -- a este personaje (su FriendById no se actualiza por sí solo).
    if Friends[cid] then
        for friendCid in pairs(Friends[cid]) do
            local friendSrc = getSourceByCid(friendCid)
            if friendSrc then syncClient(friendSrc, friendCid) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Pending[src] = nil

    -- Avisar a los amigos online para que quiten a este personaje de su
    -- FriendById (su server id quedaría obsoleto). Tomamos el cid del statebag.
    local info = Player(src).state.amigos
    notifyFriendsOffline(info and info.cid, src)

    -- Mantenemos la caché de amistades cargada por si reentra rápido; QBX no
    -- nos da el cid aquí de forma fiable, así que no la limpiamos.
end)

-----------------------------------------------------------------------
--  FLUJO DE SOLICITUDES DE AMISTAD
-----------------------------------------------------------------------

RegisterNetEvent('amigos:server:sendRequest', function(targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    local sender, senderCid = getPlayer(src)
    local target, targetCid = getPlayer(targetSrc)
    if not sender or not target then
        return qbx:Notify(src, Config.Text.notOnline, 'error')
    end

    if src == targetSrc then
        return qbx:Notify(src, Config.Text.cantAddSelf, 'error')
    end

    if areFriends(senderCid, targetCid) then
        return qbx:Notify(src, Config.Text.alreadyFriends, 'error')
    end

    if Config.MaxFriends > 0 and countFriends(senderCid) >= Config.MaxFriends then
        return qbx:Notify(src, Config.Text.maxFriends, 'error')
    end

    if Pending[targetSrc] and Pending[targetSrc].fromSrc == src then
        return qbx:Notify(src, Config.Text.requestPending, 'error')
    end

    Pending[targetSrc] = {
        fromSrc  = src,
        fromCid  = senderCid,
        fromName = getName(sender),
        expireAt = os.time() + Config.Requests.expire,
    }

    qbx:Notify(src, Config.Text.requestSent:format(getName(target)), 'success')
    TriggerClientEvent('amigos:client:incomingRequest', targetSrc, getName(sender))

    -- Caducidad
    SetTimeout(Config.Requests.expire * 1000, function()
        local req = Pending[targetSrc]
        if req and req.fromSrc == src and req.expireAt <= os.time() then
            Pending[targetSrc] = nil
        end
    end)
end)

RegisterNetEvent('amigos:server:respondRequest', function(accepted)
    local src = source
    local req = Pending[src]
    if not req then
        return qbx:Notify(src, Config.Text.requestExpired, 'error')
    end
    Pending[src] = nil

    if req.expireAt <= os.time() then
        return qbx:Notify(src, Config.Text.requestExpired, 'error')
    end

    local fromSrc = getSourceByCid(req.fromCid) -- puede haber cambiado de slot
    local target, targetCid = getPlayer(src)
    if not target then return end

    if not accepted then
        if fromSrc then
            qbx:Notify(fromSrc, Config.Text.declined:format(getName(target)), 'error')
        end
        return
    end

    -- Re-validar por si dejaron de estar online o ya son amigos
    if areFriends(req.fromCid, targetCid) then
        return qbx:Notify(src, Config.Text.alreadyFriends, 'inform')
    end

    addFriendship(fromSrc, req.fromCid, src, targetCid)

    qbx:Notify(src, Config.Text.nowFriends:format(req.fromName), 'success')
    if fromSrc then
        qbx:Notify(fromSrc, Config.Text.nowFriends:format(getName(target)), 'success')
    end
end)

RegisterNetEvent('amigos:server:removeFriend', function(targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc)

    local _, senderCid = getPlayer(src)
    if not senderCid then return end

    -- Permite eliminar tanto por source online como por cid (desde la lista)
    local targetCid
    if type(targetSrc) == 'number' then
        local t = qbx:GetPlayer(targetSrc)
        targetCid = t and t.PlayerData.citizenid
    end
    if not targetCid then return end

    if not areFriends(senderCid, targetCid) then
        return qbx:Notify(src, Config.Text.notFriends, 'error')
    end

    removeFriendship(senderCid, targetCid)

    local target = qbx:GetPlayer(targetSrc)
    qbx:Notify(src, Config.Text.removed:format(target and getName(target) or '...'), 'inform')
    if targetSrc then
        local sender = qbx:GetPlayer(src)
        qbx:Notify(targetSrc, Config.Text.removedBy:format(sender and getName(sender) or '...'), 'inform')
    end
end)

-- Eliminar amigo desde la lista (UI) usando el citizenid directamente.
RegisterNetEvent('amigos:server:removeFriendByCid', function(targetCid)
    local src = source
    local _, senderCid = getPlayer(src)
    if not senderCid or type(targetCid) ~= 'string' then return end
    if not areFriends(senderCid, targetCid) then
        return qbx:Notify(src, Config.Text.notFriends, 'error')
    end
    removeFriendship(senderCid, targetCid)
    qbx:Notify(src, Config.Text.removed:format(targetCid), 'inform')
end)

-----------------------------------------------------------------------
--  LISTA DE AMIGOS  (/amigos)
-----------------------------------------------------------------------

lib.callback.register('amigos:server:getList', function(src)
    local _, cid = getPlayer(src)
    if not cid or not Friends[cid] then return {} end

    local list = {}
    for friendCid in pairs(Friends[cid]) do
        local online = qbx:GetPlayerByCitizenId(friendCid)
        list[#list + 1] = {
            cid    = friendCid,
            name   = online and getName(online) or friendCid,
            online = online ~= nil,
        }
    end
    table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
    return list
end)

-----------------------------------------------------------------------
--  EXPORTS (servidor) — para integrar en chats, sistemas de voz, etc.
-----------------------------------------------------------------------

-- ¿Son amigos? (por citizenid)
exports('AreFriends', function(cidA, cidB)
    return areFriends(cidA, cidB)
end)

-- ¿El viewer y el target son amigos? (por source)
exports('IsFriendOf', function(viewerSrc, targetSrc)
    local _, a = getPlayer(viewerSrc)
    local _, b = getPlayer(targetSrc)
    if not a or not b then return false end
    return areFriends(a, b)
end)

-- Lista de citizenids amigos de un cid.
exports('GetFriends', function(cid)
    local list = {}
    if Friends[cid] then
        for friendCid in pairs(Friends[cid]) do
            list[#list + 1] = friendCid
        end
    end
    return list
end)

-- *** El export clave para chats ***
-- Nombre de `targetSrc` tal y como debe verlo `viewerSrc`.
-- Devuelve el nombre real si son amigos, o Config.UnknownLabel si no.
exports('GetDisplayNameForViewer', function(viewerSrc, targetSrc)
    return displayNameFor(viewerSrc, targetSrc)
end)
