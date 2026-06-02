-----------------------------------------------------------------------
--  DIBUJO DE TEXTO 3D
-----------------------------------------------------------------------

-- Dibuja texto 3D y devuelve `true` si quedó EN PANTALLA (visible).
-- Devolver la visibilidad permite al bucle dormir cuando no hay nada que ver.
local function draw3DText(x3, y3, z3, text, scale, r, g, b, a)
    local onScreen, sx, sy = World3dToScreen2d(x3, y3, z3)
    if not onScreen then return false end

    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(sx, sy)
    return true
end

-----------------------------------------------------------------------
--  NOMBRE SOBRE LA CABEZA
-----------------------------------------------------------------------

-- Solo arrancamos el hilo si hay ALGO que pueda llegar a dibujarse alguna vez.
local canDrawFriends  = Config.Overhead.showFriendName
local canDrawUnknown  = Config.Overhead.showUnknown
local overheadActive  = Config.Overhead.enabled and (canDrawFriends or canDrawUnknown)

if overheadActive then
    CreateThread(function()
        local cfg      = Config.Overhead
        local maxDist  = cfg.distance
        local maxDistSq= maxDist * maxDist        -- comparamos al cuadrado (sin sqrt)
        local invDist  = 1.0 / maxDist            -- para el fade, sin dividir cada frame
        local height   = cfg.height
        local scale    = cfg.scale
        local fcol     = cfg.color                -- color amigo
        local ucol     = cfg.unknownColor         -- color desconocido
        local fBaseA   = fcol.a or 215
        local uBaseA   = ucol.a or 180
        local label    = Config.UnknownLabel

        while true do
            local myPed    = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            local mx, my, mz = myCoords.x, myCoords.y, myCoords.z

            local drewSomething = false   -- ¿algo VISIBLE en pantalla este frame?
            local someoneNear   = false   -- ¿alguien dentro de rango (aunque off-screen)?

            for _, playerIdx in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(playerIdx)
                if ped ~= myPed and ped ~= 0 and not IsEntityDead(ped) then
                    local pc = GetEntityCoords(ped)
                    local dx, dy, dz = pc.x - mx, pc.y - my, pc.z - mz
                    local distSq = dx * dx + dy * dy + dz * dz

                    if distSq <= maxDistSq then
                        someoneNear = true

                        local serverId = GetPlayerServerId(playerIdx)
                        local friend   = GetFriendInfo(serverId)

                        -- Máscara ocultante: un amigo enmascarado se trata como
                        -- desconocido (no identificable).
                        if friend and IsPedMasked(ped) then
                            friend = nil
                        end

                        local text, br, bg, bb, baseA
                        if friend then
                            if canDrawFriends then
                                text  = friend.name
                                br, bg, bb, baseA = fcol.r, fcol.g, fcol.b, fBaseA
                            end
                        elseif canDrawUnknown then
                            text  = label
                            br, bg, bb, baseA = ucol.r, ucol.g, ucol.b, uBaseA
                        end

                        if text then
                            -- Atenúa opacidad con la distancia (sqrt solo aquí).
                            local fade = 1.0 - (math.sqrt(distSq) * invDist) * 0.45
                            local a    = math.floor(baseA * fade)
                            if draw3DText(pc.x, pc.y, pc.z + height, text, scale, br, bg, bb, a) then
                                drewSomething = true
                            end
                        end
                    end
                end
            end

            -- Sleep adaptativo:
            --   - Algo visible en pantalla  -> 0  (el texto 3D necesita cada frame)
            --   - Gente cerca pero off-screen-> ~120 ms (responde al girar cámara)
            --   - Nadie cerca               -> 500 ms (reposo)
            if drewSomething then
                Wait(0)
            elseif someoneNear then
                Wait(120)
            else
                Wait(500)
            end
        end
    end)
end
