-----------------------------------------------------------------------
--  DIBUJO DE TEXTO 3D
-----------------------------------------------------------------------

local function draw3DText(coords, text, scale, color)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(color.r, color.g, color.b, color.a or 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(x, y)
end

-----------------------------------------------------------------------
--  NOMBRE SOBRE LA CABEZA
-----------------------------------------------------------------------

if Config.Overhead.enabled then
    CreateThread(function()
        local cfg = Config.Overhead
        while true do
            local sleep = 500
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)

            for _, playerIdx in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(playerIdx)
                if ped ~= myPed and ped ~= 0 and not IsEntityDead(ped) then
                    local coords = GetEntityCoords(ped)
                    local dist = #(myCoords - coords)

                    if dist <= cfg.distance then
                        sleep = 0
                        local serverId = GetPlayerServerId(playerIdx)
                        local friend = GetFriendInfo(serverId)

                        -- Si lleva máscara ocultante, no es identificable:
                        -- se trata como un desconocido aunque sea amigo.
                        if friend and IsPedMasked(ped) then
                            friend = nil
                        end

                        local text, color
                        if friend then
                            if cfg.showFriendName then
                                text  = friend.name
                                color = cfg.color
                            end
                        elseif cfg.showUnknown then
                            text  = Config.UnknownLabel
                            color = cfg.unknownColor
                        end

                        if text then
                            local head = coords + vector3(0.0, 0.0, cfg.height)
                            -- Atenúa la opacidad con la distancia
                            local fade = 1.0 - (dist / cfg.distance) * 0.45
                            local c = { r = color.r, g = color.g, b = color.b, a = math.floor((color.a or 215) * fade) }
                            draw3DText(head, text, cfg.scale, c)
                        end
                    end
                end
            end

            Wait(sleep)
        end
    end)
end
