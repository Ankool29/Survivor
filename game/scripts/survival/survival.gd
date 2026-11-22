class_name Survival
extends RefCounted
## Temps, météo et besoins du joueur (étape 2). Une seconde réelle = une minute de jeu.

signal message(text: String)
signal died(cause: String)

const MIN_PER_DAY := 1440.0
const DAYS_PER_SEASON := 7
const SEASONS := ["printemps", "été", "automne", "hiver"]
const START_SEASON := 2          ## automne
const START_HOUR := 8.0
# Températures de jour / de nuit par saison (°C)
const TEMP_DAY := [14.0, 23.0, 14.0, 7.0]
const TEMP_NIGHT := [5.0, 13.0, 6.0, 0.0]
const WEATHERS := ["beau", "nuageux", "pluie", "brouillard"]
# Chances de chaque météo par saison
const WEATHER_ODDS := [[0.35, 0.3, 0.25, 0.1], [0.55, 0.25, 0.15, 0.05], [0.25, 0.3, 0.3, 0.15], [0.2, 0.35, 0.3, 0.15]]

var minutes := 0.0               ## minutes écoulées depuis le début de la partie
var weather := "beau"
var _weather_slot := -1
var seed_value := 0

var soif := 100.0
var faim := 100.0
var fatigue := 100.0             ## 100 = reposé
var chaleur := 100.0
var sante := 100.0
var mouille := 0.0               ## 0 sec, 1 trempé
var malade := 0.0                ## minutes de maladie restantes
var porte := ""                  ## vêtement porté
var sac := false                 ## sac à dos équipé
var torche := 0.0                ## minutes de torche restantes
var sleeping := false
var sleep_quality := 0.6
var dead := false
var cause := ""

# Statistiques de la partie
var distance_m := 0.0
var fouilles := 0

# Contexte fourni chaque image par le jeu
var running := false
var indoor := false
var near_fire := false
var sheltered := false

var _warned := {}


func start(s: int) -> void:
	seed_value = s
	minutes = START_HOUR * 60.0
	_pick_weather(true)


func day() -> int:
	return int((minutes + (START_SEASON * DAYS_PER_SEASON) * MIN_PER_DAY) / MIN_PER_DAY)


func hour() -> float:
	return fmod(minutes, MIN_PER_DAY) / 60.0


func season() -> int:
	return (day() / DAYS_PER_SEASON) % 4


func days_survived() -> int:
	return int((minutes - START_HOUR * 60.0) / MIN_PER_DAY)


## 0 la nuit, 1 en plein jour (transitions à l'aube et au crépuscule).
func daylight() -> float:
	var h := hour()
	if h < 5.5 or h > 21.5:
		return 0.0
	if h < 7.5:
		return (h - 5.5) / 2.0
	if h > 19.5:
		return (21.5 - h) / 2.0
	return 1.0


func outside_temp() -> float:
	var s := season()
	var h := hour()
	var k := (1.0 - cos((h - 4.0) / 24.0 * TAU)) * 0.5   # minimum vers 4 h, maximum vers 16 h
	var t := lerpf(TEMP_NIGHT[s], TEMP_DAY[s], k)
	if weather == "pluie":
		t -= 3.0
	return t


func felt_temp() -> float:
	var t := outside_temp() - 7.0 * mouille
	t += float(Items.info(porte).get("chaleur", 0))
	if indoor or sheltered:
		t += 4.0
	if near_fire:
		t += 12.0
	return t


func _pick_weather(force := false) -> void:
	var slot := int(minutes / 720.0)          # une météo par demi-journée
	if slot == _weather_slot and not force:
		return
	_weather_slot = slot
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, slot])
	var odds: Array = WEATHER_ODDS[season()]
	var x := r.randf()
	for i in odds.size():
		x -= odds[i]
		if x <= 0.0:
			weather = WEATHERS[i]
			return
	weather = WEATHERS[0]


## Avance le temps de dt secondes réelles (× speed en dormant).
func tick(dt: float, speed := 1.0) -> void:
	if dead:
		return
	var m := dt * speed              # minutes de jeu écoulées
	var h := m / 60.0
	minutes += m
	_pick_weather()
	# Soif, faim, fatigue
	var thirst_rate := 100.0 / 24.0 * (1.5 if running else 1.0) * (1.6 if malade > 0 else 1.0)
	if outside_temp() > 22.0:
		thirst_rate *= 1.3
	soif = maxf(0.0, soif - thirst_rate * h * (0.5 if sleeping else 1.0))
	faim = maxf(0.0, faim - 100.0 / 48.0 * h * (0.6 if sleeping else 1.0))
	if sleeping:
		fatigue = minf(100.0, fatigue + 100.0 / 7.0 * sleep_quality * h)
	else:
		fatigue = maxf(0.0, fatigue - 100.0 / 20.0 * h * (1.4 if running else 1.0))
	# Mouillé / séchage
	if weather == "pluie" and not indoor and not sheltered:
		mouille = minf(1.0, mouille + h * 1.5)
	else:
		mouille = maxf(0.0, mouille - h * (2.0 if near_fire else 0.4))
	# Chaleur
	var ft := felt_temp()
	if ft >= 10.0:
		chaleur = minf(100.0, chaleur + 20.0 * h)
	else:
		chaleur = maxf(0.0, chaleur - (10.0 - ft) * 0.8 * h)
	# Maladie, torche
	if malade > 0.0:
		malade = maxf(0.0, malade - m)
		sante -= 2.0 * h
		if malade == 0.0:
			message.emit("Tu te sens mieux.")
	if torche > 0.0:
		torche = maxf(0.0, torche - m)
		if torche == 0.0:
			message.emit("La torche s'est éteinte.")
	# Santé
	var hurt := 0.0
	var why := ""
	if soif <= 0.0:
		hurt += 10.0
		why = "la soif"
	if faim <= 0.0:
		hurt += 5.0
		why = "la faim" if why == "" else why
	if chaleur <= 0.0:
		hurt += 8.0
		why = "le froid" if why == "" else why
	if fatigue <= 0.0 and not sleeping:
		hurt += 3.0
		why = "l'épuisement" if why == "" else why
	if hurt > 0.0:
		sante -= hurt * h
	elif soif > 50 and faim > 50 and chaleur > 50 and malade == 0.0:
		sante += (4.0 if sleeping else 2.0) * h
	sante = minf(100.0, sante)
	if malade > 0.0 and why == "":
		why = "la maladie"
	_warn("soif", soif < 25, "Tu as soif.")
	_warn("faim", faim < 25, "Tu as faim.")
	_warn("fatigue", fatigue < 25, "Tu es épuisé.")
	_warn("chaleur", chaleur < 25, "Tu as froid.")
	if sante <= 0.0:
		sante = 0.0
		dead = true
		cause = why if why != "" else "tes blessures"
		died.emit(cause)


func _warn(key: String, cond: bool, text: String) -> void:
	if cond and not _warned.get(key, false):
		message.emit(text)
	_warned[key] = cond


func hurt(amount: float, why: String) -> void:
	sante -= amount
	if sante <= 0.0 and not dead:
		sante = 0.0
		dead = true
		cause = why
		died.emit(cause)


## Effet d'un objet consommé ; renvoie le texte à afficher.
func consume(id: String) -> String:
	var it := Items.info(id)
	faim = minf(100.0, faim + float(it.get("faim", 0)))
	soif = minf(100.0, soif + float(it.get("soif", 0)))
	sante = minf(100.0, sante + float(it.get("soin", 0)))
	if it.has("chaud"):
		chaleur = minf(100.0, chaleur + float(it["chaud"]))
	if it.get("guerit", false) and malade > 0.0:
		malade = 0.0
		return "Tu te sens mieux."
	var r := randf()
	if r < float(it.get("malade", 0.0)):
		malade = maxf(malade, 12.0 * 60.0)
		return "Ça ne passe pas… Tu es malade."
	return ""


func to_data() -> Dictionary:
	return {"minutes": minutes, "weather": weather, "slot": _weather_slot, "seed": seed_value,
		"soif": soif, "faim": faim, "fatigue": fatigue, "chaleur": chaleur, "sante": sante,
		"mouille": mouille, "malade": malade, "porte": porte, "sac": sac, "torche": torche,
		"distance": distance_m, "fouilles": fouilles}


func from_data(d: Dictionary) -> void:
	minutes = float(d.get("minutes", START_HOUR * 60.0))
	weather = String(d.get("weather", "beau"))
	_weather_slot = int(d.get("slot", -1))
	seed_value = int(d.get("seed", 0))
	soif = float(d.get("soif", 100))
	faim = float(d.get("faim", 100))
	fatigue = float(d.get("fatigue", 100))
	chaleur = float(d.get("chaleur", 100))
	sante = float(d.get("sante", 100))
	mouille = float(d.get("mouille", 0))
	malade = float(d.get("malade", 0))
	porte = String(d.get("porte", ""))
	sac = bool(d.get("sac", false))
	torche = float(d.get("torche", 0))
	distance_m = float(d.get("distance", 0))
	fouilles = int(d.get("fouilles", 0))
