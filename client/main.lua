local qbx = exports.qbx_core

-- Amigos ONLINE del jugador local, ya resueltos por el servidor:
--   FriendById[serverId] = { name = '...', cid = '...' }
FriendById = {}
-- citizenid del jugador local
MyCid = nil

-----------------------------------------------------------------------
--  HELPERS COMPARTIDOS (usados también por overhead.lua)
-----------------------------------------------------------------------

-- Info del amigo (nombre/cid) por su server id, o nil si no es amigo / offline.
function GetFriendInfo(serverId)
    return FriendById[serverId]
end

-- ¿El jugador local es amigo de este server id?
function IsFriendLocal(serverId)
    return FriendById[serverId] ~= nil
end

-----------------------------------------------------------------------
--  INICIALIZACIÓN / SINCRONIZACIÓN
-----------------------------------------------------------------------

local function init()
    local data = qbx:GetPlayerData()
    MyCid = data and data.citizenid or nil
    TriggerServerEvent('amigos:server:playerReady')
end

AddEventHandler('QBX:Client:OnPlayerLoaded', init)

RegisterNetEvent('amigos:client:setFriends', function(list)
    local map = {}
    for i = 1, #list do
        local f = list[i]
        map[f.id] = { name = f.name, cid = f.cid }
    end
    FriendById = map
end)

CreateThread(function()
    -- Si el recurso se reinicia con el jugador ya logueado
    if LocalPlayer.state.isLoggedIn then
        init()
    end
end)

-----------------------------------------------------------------------
--  SOLICITUD ENTRANTE (diálogo ox_lib)
-----------------------------------------------------------------------

RegisterNetEvent('amigos:client:incomingRequest', function(fromName)
    local accepted = lib.alertDialog({
        header   = Config.Text.requestReceived:format(fromName),
        content  = Config.Text.requestDialog:format(fromName),
        centered = true,
        cancel   = true,
        labels   = {
            cancel  = Config.Text.requestDecline,
            confirm = Config.Text.requestAccept,
        },
    })
    TriggerServerEvent('amigos:server:respondRequest', accepted == 'confirm')
end)

-----------------------------------------------------------------------
--  OX_TARGET (jugadores)
-----------------------------------------------------------------------

local function serverIdFromPed(entity)
    local playerIdx = NetworkGetPlayerIndexFromPed(entity)
    if playerIdx == -1 then return nil end
    return GetPlayerServerId(playerIdx)
end

if Config.Target.enabled then
    exports.ox_target:addGlobalPlayer({
        {
            name     = 'amigos_add',
            icon     = Config.Target.addIcon,
            label    = Config.Text.targetAdd,
            distance = Config.Target.distance,
            canInteract = function(entity)
                local sid = serverIdFromPed(entity)
                return sid ~= nil and not IsFriendLocal(sid)
            end,
            onSelect = function(data)
                local sid = serverIdFromPed(data.entity)
                if sid then TriggerServerEvent('amigos:server:sendRequest', sid) end
            end,
        },
        {
            name     = 'amigos_remove',
            icon     = Config.Target.removeIcon,
            label    = Config.Text.targetRemove,
            distance = Config.Target.distance,
            canInteract = function(entity)
                local sid = serverIdFromPed(entity)
                return sid ~= nil and IsFriendLocal(sid)
            end,
            onSelect = function(data)
                local sid = serverIdFromPed(data.entity)
                if sid then TriggerServerEvent('amigos:server:removeFriend', sid) end
            end,
        },
    })
end

-----------------------------------------------------------------------
--  LISTA DE AMIGOS  (/amigos)
-----------------------------------------------------------------------

local function openFriendList()
    local list = lib.callback.await('amigos:server:getList', false)
    if not list or #list == 0 then
        return lib.notify({ description = Config.Text.listEmpty, type = 'inform' })
    end

    local options = {}
    for i = 1, #list do
        local f = list[i]
        options[#options + 1] = {
            title       = f.name,
            description = f.online and Config.Text.listOnline or Config.Text.listOffline,
            icon        = f.online and 'user' or 'user-slash',
            iconColor   = f.online and '#3fb950' or '#8b949e',
            onSelect    = function()
                local confirm = lib.alertDialog({
                    header  = Config.Text.targetRemove,
                    content = ('%s — %s'):format(f.name, Config.Text.targetRemove),
                    centered = true,
                    cancel  = true,
                })
                if confirm == 'confirm' then
                    TriggerServerEvent('amigos:server:removeFriendByCid', f.cid)
                    Wait(250)
                    openFriendList()
                end
            end,
        }
    end

    lib.registerContext({
        id      = 'amigos_list',
        title   = Config.Text.listTitle:format(#list),
        options = options,
    })
    lib.showContext('amigos_list')
end

RegisterCommand('amigos', openFriendList, false)
RegisterKeyMapping('amigos', 'Abrir lista de amigos', 'keyboard', '')

-----------------------------------------------------------------------
--  EXPORTS (cliente)  —  para que OTROS scripts (chats, voz, etc.)
--  resuelvan el nombre del emisor según la amistad del jugador local.
--  Cada cliente resuelve "lo que ÉL ve": tú ves el nombre, otro ve
--  "Desconocido".  Es el patrón de abp_headFriend / jgs chat.
-----------------------------------------------------------------------

local function isLocal(serverId)
    return serverId == GetPlayerServerId(PlayerId())
end

-- ¿Es amigo del jugador local? (por server id) → boolean
exports('IsFriend', function(serverId)
    return IsFriendLocal(tonumber(serverId))
end)

-- *** Export principal para chats ***
-- Nombre de `serverId` tal y como lo ve el jugador local:
--   nombre real si es amigo (o eres tú), "Desconocido" si no.
-- Acepta un 2º arg opcional `unknownLabel` para sobrescribir el texto.
exports('GetDisplayName', function(serverId, unknownLabel)
    serverId = tonumber(serverId)
    if isLocal(serverId) then
        local data = qbx:GetPlayerData()
        if data and data.charinfo then return Config.NameFormat(data.charinfo) end
    end
    local info = GetFriendInfo(serverId)
    if info then return info.name end
    return unknownLabel or Config.UnknownLabel
end)

-- Compatibilidad estilo abp_headFriend.
-- Devuelve una tabla { friend, headtext, unknown } o `false` si no son amigos.
-- Uso típico en un chat:
--   local f = exports['script-amigos-qbx']:areFriends(senderId)
--   local name = f and f.headtext or "Desconocido"
exports('areFriends', function(serverId)
    serverId = tonumber(serverId)
    local info = GetFriendInfo(serverId)
    if not info then return false end
    return { friend = true, headtext = info.name, unknown = Config.UnknownLabel }
end)
