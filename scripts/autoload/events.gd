extends Node
## Bus de senales global (registrado como autoload "Events").
##
## Un AUTOLOAD (o singleton) es un nodo que Godot instancia una sola vez al
## arrancar y cuelga de la raiz del arbol. Se accede por su nombre desde
## cualquier script, sin necesidad de referencias: `Events.player_died.emit()`.
##
## Lo usamos como tablon de anuncios: quien emite no conoce a quien escucha.
## Asi el HUD no depende del Player, ni la camara del arma, etc.

## El jugador acaba de entrar en escena. El HUD y la camara se enganchan aqui.
signal player_spawned(player: Node2D)

## Cambio alguna estadistica del jugador (vida, armadura, energia).
signal player_stats_changed

## El jugador murio.
signal player_died

## Murio un enemigo, en esa posicion del mundo (util para drops y contadores).
signal enemy_died(at: Vector2)

## Peticion de sacudida de camara. `strength` va en pixeles.
signal shake_requested(strength: float)

## Todos los enemigos de la sala han muerto.
signal room_cleared

## Texto breve para mostrar en el HUD.
signal message(text: String, seconds: float)
