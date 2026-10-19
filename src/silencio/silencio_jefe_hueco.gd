class_name SilencioJefeHueco
extends SilencioSala

## SALA DEL JEFE, VACIA (provisoria). Aqui va "El Pacto de Silencio" (diseno_E3, seccion 5), que hace OTRO
## agente: script src/enemies/bosses/boss_pacto_silencio.gd, entrada "pacto_silencio" en boss_damage.json
## y en boss_picker. Mientras no exista, esta sala solo tiene la puerta que avanza (el portal de salida,
## main.open_exit), como la salida de S4. Sin enemigos, sin botin, sin premio (decision 1 de la 9.1).
##
## Para el agente del jefe: reemplaza SilencioJefeHueco por tu sala en Silencio._make_sala("jefe") (clave
## "jefe" de CHAIN_FONDO, 16x12 tiles, luz 0.35). El piso ya declara "boss": "pacto_silencio" en
## 85_silencio_fondo.json. Las luces del circulo: S3 las apaga y S6 B deja la 0 encendida
## (Silencio.circle_set / circle_relight).

const EXIT_AT := Vector2(0, 0)  # relativo al centro de la sala


func start() -> void:
	main.open_exit(room, int(get_node("/root/RunManager").current_floor), EXIT_AT, tr("SIL_S4_SALIDA"))
