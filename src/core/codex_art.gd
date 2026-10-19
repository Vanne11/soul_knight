class_name CodexArt

## Imagen de cada entrada del codice (menu y aviso de desbloqueo).

## Lamina ilustrada (IA, tools/gen_codex_art.py) de la entrada, o null si no tiene:
## entonces el detalle sigue usando image() (sprite del juego). Se guarda por id de entrada.
static func illustration(e) -> Texture2D:
	var path := "res://assets/sprites/codex/%s.png" % e.id
	return load(path) if ResourceLoader.exists(path) else null

## Imagen de una entrada del codice, deducida de lo que la desbloquea.
static func image(e) -> Texture2D:
	if e.sprite:
		return e.sprite
	var uc = e.unlock_condition if e.unlock_condition is Dictionary else {}
	var target: String = str(uc.get("target_id", ""))
	var path := ""
	match e.category:
		LoreEntry.Category.ITEM:
			path = "res://assets/sprites/items/%s.png" % target
		LoreEntry.Category.ENEMY:
			var v: String = _enemy_variants().get(target, "")
			if v != "":
				path = EnemyArt.file(v, "%s_idle_00.png" % v)
		LoreEntry.Category.CHARACTER:
			path = "res://assets/sprites/player/%s/portrait.png" % target.trim_prefix("play_")
	if path == "" or not ResourceLoader.exists(path):
		path = CODEX_ART.get(e.id, "")
	return load(path) if path != "" and ResourceLoader.exists(path) else null

## Entradas sin objeto/bicho propio: su ilustracion de la intro o de pantalla.
const CODEX_ART := {
	"world_intro": "res://assets/sprites/intro/slide_00.png",
	"copia_seguridad": "res://assets/sprites/intro/slide_04.png",
	"guerra_fria": "res://assets/sprites/intro/slide_01.png",
	"alergia_hormonal": "res://assets/sprites/intro/slide_02.png",
	"floor_anatomy": "res://assets/sprites/intro/slide_00.png",
	"loc_selva": "res://assets/sprites/intro/slide_06.png",
	"loc_penelandia": "res://assets/sprites/intro/slide_00.png",
	"loc_vulvania": "res://assets/sprites/intro/slide_00.png",
	"loc_perineo": "res://assets/sprites/intro/slide_01.png",
	"loc_palacio": "res://assets/sprites/intro/slide_04.png",
	"puerta_hormonal": "res://assets/sprites/intro/slide_07.png",
	"player_identity": "res://assets/sprites/intro/slide_08.png",
	"death_meaning": "res://assets/sprites/ui/screens/gameover.png",
	"final_censura": "res://assets/sprites/ui/screens/victory.png",
	"drunk_secret": "res://assets/sprites/items/whiskey.png",
	"intoxication_mechanic": "res://assets/sprites/items/absinthe.png",
	"boss_phases": "res://assets/sprites/intro/slide_03.png",
}

## Nombre visible del enemigo -> variante de sprite (rosters y jefes de cada piso).
static func _enemy_variants() -> Dictionary:
	var m := {}
	for f in RunManager.FLOORS:
		for pair in [["roster", "names"], ["alt_roster", "alt_names"]]:
			if f.has(pair[0]):
				for i in f[pair[0]].size():
					m[f[pair[1]][i]] = f[pair[0]][i]
		for x in f.get("extra", []):
			m[x.name] = x.variant
		if f.boss_name != "":
			m[f.boss_name] = f.boss
		if str(f.get("boss_alt_name", "")) != "":
			m[f.boss_alt_name] = f.boss_alt
		if str(f.get("secret_boss_name", "")) != "":
			m[f.secret_boss_name] = f.secret_boss
	return m

## Miniatura size x size sin suavizar (escala entera si cabe, vecino mas cercano);
## en silueta negra si aun no se descubrio.
static func thumb(tex: Texture2D, size: int, silhouette: bool, integer_scale := false) -> Texture2D:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x > 0:
		img = img.get_region(used)
	var k := minf(float(size) / img.get_width(), float(size) / img.get_height())
	if integer_scale and k >= 1.0:
		k = floorf(k)  # ampliar en multiplos enteros: pixeles todos del mismo tamano
	var w := maxi(1, int(img.get_width() * k))
	var h := maxi(1, int(img.get_height() * k))
	img.resize(w, h, Image.INTERPOLATE_NEAREST)
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((size - w) / 2, (size - h) / 2))
	if silhouette:
		for y in size:
			for x in size:
				var c := out.get_pixel(x, y)
				if c.a > 0.0:
					out.set_pixel(x, y, Color(0.05, 0.03, 0.08, c.a))
	return ImageTexture.create_from_image(out)
