Config = {}

-----------------------------------------------------------------------
--  GENERAL
-----------------------------------------------------------------------

-- Texto que se muestra sobre la cabeza / en los chats cuando NO son amigos.
Config.UnknownLabel = 'Desconocido'

-- Máximo de amigos por personaje (0 = sin límite).
Config.MaxFriends = 100

-- Formato del nombre que verán los AMIGOS. Recibe el charinfo del jugador.
-- Devuelve el texto a mostrar.
Config.NameFormat = function(charinfo)
    return ('%s %s'):format(charinfo.firstname, charinfo.lastname)
end

-----------------------------------------------------------------------
--  NOMBRE SOBRE LA CABEZA (OVERHEAD)
-----------------------------------------------------------------------

Config.Overhead = {
    enabled        = true,        -- Activar/desactivar el texto sobre la cabeza
    distance       = 8.0,         -- Distancia máxima (metros) a la que se dibuja
    height         = 1.0,         -- Altura sobre la cabeza
    scale          = 0.40,        -- Tamaño del texto
    showUnknown    = true,        -- Mostrar "Desconocido" sobre los que NO son amigos
    showFriendName = true,        -- Mostrar el nombre sobre los AMIGOS
                                  --   true  = se ve el nombre del amigo
                                  --   false = no se muestra NADA sobre los amigos
    color          = { r = 255, g = 255, b = 255, a = 215 }, -- Color del nombre del amigo
    unknownColor   = { r = 200, g = 200, b = 200, a = 180 }, -- Color de "Desconocido"
}

-----------------------------------------------------------------------
--  OX_TARGET
-----------------------------------------------------------------------

Config.Target = {
    enabled   = true,
    distance  = 2.5,
    addIcon   = 'fas fa-user-plus',
    removeIcon= 'fas fa-user-minus',
}

-----------------------------------------------------------------------
--  SOLICITUDES DE AMISTAD
-----------------------------------------------------------------------

Config.Requests = {
    expire = 30,  -- Segundos que dura una solicitud antes de caducar
}

-----------------------------------------------------------------------
--  TEXTOS (locales)
-----------------------------------------------------------------------

Config.Text = {
    targetAdd        = 'Añadir como amigo',
    targetRemove     = 'Eliminar amigo',

    requestSent      = 'Solicitud de amistad enviada a %s',
    requestReceived  = '%s quiere ser tu amigo',
    requestDialog    = '¿Aceptas la solicitud de amistad de %s?',
    requestAccept    = 'Aceptar',
    requestDecline   = 'Rechazar',
    requestExpired   = 'La solicitud de amistad ha caducado',
    requestPending   = 'Esa persona ya tiene una solicitud pendiente tuya',

    nowFriends       = 'Ahora eres amigo de %s',
    declined         = '%s ha rechazado tu solicitud',
    removed          = 'Has eliminado a %s de tus amigos',
    removedBy        = '%s te ha eliminado de sus amigos',

    alreadyFriends   = 'Ya sois amigos',
    cantAddSelf      = 'No puedes añadirte a ti mismo',
    maxFriends       = 'Has alcanzado el máximo de amigos',
    notOnline        = 'Ese jugador ya no está disponible',
    notFriends       = 'No sois amigos',

    listTitle        = 'Mis amigos (%s)',
    listEmpty        = 'No tienes amigos todavía',
    listOnline       = 'En línea',
    listOffline      = 'Desconectado',
}
