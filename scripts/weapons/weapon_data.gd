class_name WeaponData
extends Resource
## Definicion de un arma: solo DATOS, sin comportamiento.
##
## Un Resource es un objeto serializable que vive en un archivo .tres. Cambiar
## el balance del juego se convierte asi en editar un archivo, no en tocar
## codigo: cada arma nueva es un .tres mas. Es la base para las decenas de
## armas que tiene un roguelite.

@export var display_name: String = "Pistola"
@export var texture: Texture2D

@export_group("Disparo")
@export var damage: int = 2
## Disparos por segundo.
@export var fire_rate: float = 4.5
## Proyectiles por disparo (una escopeta pondria 5).
@export var bullet_count: int = 1
## Dispersion aleatoria en grados, a cada lado.
@export var spread_deg: float = 3.0
## Cuantos enemigos atraviesa antes de desaparecer.
@export var pierce: int = 0

@export_group("Proyectil")
@export var bullet_scene: PackedScene
@export var bullet_texture: Texture2D
@export var bullet_speed: float = 230.0
## Segundos de vida del proyectil (define el alcance).
@export var bullet_life: float = 1.6
## Empujon que recibe el enemigo alcanzado.
@export var knockback: float = 90.0

@export_group("Coste y feedback")
## Energia consumida por disparo (la energia se regenera sola, como en SK).
@export var energy_cost: float = 3.0
## Retroceso que empuja al tirador hacia atras.
@export var recoil: float = 30.0
## Sacudida de camara por disparo, en pixeles.
@export var shake: float = 1.2
