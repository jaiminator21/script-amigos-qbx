# script-amigos-qbx

Sistema de **amigos** para Qbox (`qbx_core`).

- Nombre **"Desconocido"** sobre la cabeza de quienes no son tus amigos.
- Nombre real sobre tus amigos (configurable para **no mostrar nada**).
- Solicitudes de amistad mediante **ox_target**.
- **Exports** para que tu chat (`/me`, `/do`, etc.) muestre *Desconocido* en lugar del nombre cuando no hay amistad.

## Dependencias

- `qbx_core`
- `ox_lib`
- `ox_target`
- `oxmysql`

## Instalación

1. Copia la carpeta en `resources/` (p. ej. `[scripts]/script-amigos-qbx`).
2. Importa la base de datos:
   ```sql
   -- ejecuta amigos.sql en tu BD
   ```
3. Añade a tu `server.cfg`:
   ```cfg
   ensure script-amigos-qbx
   ```
4. Ajusta `config.lua` a tu gusto.

## Uso

| Acción | Cómo |
|--------|------|
| Añadir amigo | Apunta a un jugador con **ox_target** → *Añadir como amigo* |
| Aceptar/rechazar | Diálogo de `ox_lib` al recibir la solicitud |
| Eliminar amigo | **ox_target** → *Eliminar amigo*, o desde `/amigos` |
| Ver lista | Comando `/amigos` |

> Si quieres que tus amigos **no** muestren ningún nombre sobre la cabeza,
> pon `Config.Overhead.showFriendName = false`.

> Este recurso **no** registra `/me` ni `/do`: de eso se encarga tu chat,
> que debe llamar al export del cliente para resolver el nombre (ver abajo).

## Exports

### Servidor

```lua
local amigos = exports['script-amigos-qbx']

-- ¿Son amigos? (por citizenid)
amigos:AreFriends(cidA, cidB)            --> boolean

-- ¿viewer y target son amigos? (por source)
amigos:IsFriendOf(viewerSrc, targetSrc)  --> boolean

-- Lista de citizenids amigos de un cid
amigos:GetFriends(cid)                   --> string[]

-- *** El más importante para chats ***
-- Nombre de `targetSrc` tal y como debe verlo `viewerSrc`
-- (nombre real si son amigos, "Desconocido" si no)
amigos:GetDisplayNameForViewer(viewerSrc, targetSrc)  --> string
```

#### Ejemplo: integrar en un chat (servidor)

Cuando reenvíes un mensaje a cada destinatario, resuelve el nombre **por
destinatario**, porque cada uno puede ver al emisor de forma distinta:

```lua
RegisterCommand('say', function(source, args)
    local msg = table.concat(args, ' ')
    local amigos = exports['script-amigos-qbx']

    for _, viewer in ipairs(GetPlayers()) do
        viewer = tonumber(viewer)
        local name = amigos:GetDisplayNameForViewer(viewer, source)
        TriggerClientEvent('chat:addMessage', viewer, {
            color = { 255, 255, 255 },
            args  = { name, msg },
        })
    end
end, false)
```

### Cliente (para integrar en chats: /me, /do, etc.)

Este es el patrón que usan `abp_headFriend` y los chats tipo jgs: el chat
renderiza el mensaje en **cada cliente**, y cada cliente resuelve el nombre del
emisor según **su propia** amistad. Así, tú ves el nombre real de tu amigo y
otro jugador ve "Desconocido" — sin tocar el lado servidor del chat.

```lua
local amigos = exports['script-amigos-qbx']

amigos:IsFriend(serverId)                 --> boolean
amigos:GetDisplayName(serverId)           --> string (nombre o "Desconocido")
amigos:GetDisplayName(serverId, 'Anónimo')--> permite cambiar el texto de "desconocido"

-- Compatibilidad estilo abp_headFriend:
amigos:areFriends(serverId)               --> { friend=true, headtext='Nombre', unknown='Desconocido' } | false
```

#### Ejemplo: integrarlo en TU script de chat (cliente)

Donde tu chat construya el nombre del emisor de un `/me` o `/do`, sustitúyelo por:

```lua
-- senderId = server id del que escribe el /me o /do
local name = exports['script-amigos-qbx']:GetDisplayName(senderId)
-- ...y usa `name` al dibujar el mensaje
```

O, con la firma estilo abp (drop-in si ya usabas abp_headFriend):

```lua
local f = exports['script-amigos-qbx']:areFriends(senderId)
local name = f and f.headtext or 'Desconocido'
```

## Notas

- La amistad es **bidireccional**: se guardan ambas direcciones (`A→B` y `B→A`)
  para que las consultas por `citizenid` sean directas e indexadas.
- El servidor envía a cada cliente sus amigos **online** ya resueltos como
  `serverId → nombre`, y reenvía esa lista a los afectados en tiempo real
  cuando alguien **acepta una amistad, se conecta o se desconecta**. Así el
  nombre sobre la cabeza se actualiza al instante, sin recargar ni relogear.
