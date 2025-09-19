# ChoiceManager.gd - Singleton olarak ekleyin
extends Node

# Seçimleri saklamak için
var choices_made = {}
# Karakter durumları
var character_states = {}
# Karakter ilişkileri
var character_relationships = {}
# Karma sistemi (-100 ile +100)
var karma_score = 0
# Su kirliliği seviyesi (0-100, Elhami'nin etkisi)
var water_contamination = 30
# Elhami'nin güç seviyesi
var elhami_power = 50
# Kasaba kaos seviyesi
var town_chaos = 20

func _ready():
	initialize_characters()

func initialize_characters():
	character_states = {
		"cemal": {
			"mental_state": "dizzy", # baş dönmesi
			"job_status": "working",
			"trust_level": 60,
			"investigation_level": 0, # 0-100, ne kadar araştırdığı
			"alcohol_resistance": 40,
			"alive": true
		},
		"ali": {
			"mental_state": "hallucinating", # halüsinasyon
			"school_performance": 30,
			"trust_level": 80,
			"alcohol_resistance": 10, # çocuk, daha az dirençli
			"misdiagnosed": false,
			"alive": true
		},
		"selma": { # Ali'nin annesi
			"mental_state": "worried",
			"trust_level": 50,
			"parenting_approach": "protective",
			"alcohol_resistance": 30,
			"alive": true
		},
		"baran": {
			"mental_state": "suspicious", # şüpheli
			"music_influence": 50, # müziğinin kasabaya etkisi
			"anger_level": 40,
			"trust_level": 45,
			"alcohol_resistance": 60,
			"alive": true
		},
		"mert": {
			"mental_state": "guilty", # suçlu
			"corruption_level": 70,
			"elhami_cooperation": 60,
			"trust_level": 20,
			"employee_imprisoned": true,
			"alive": true
		},
		"selin": {
			"mental_state": "concerned", # endişeli
			"teaching_effectiveness": 70,
			"student_control": 50,
			"trust_level": 75,
			"alcohol_resistance": 35,
			"alive": true
		},
		"elhami": {
			"mental_state": "fanatical", # fanatik
			"cult_influence": 50,
			"water_poisoning_active": true,
			"discovered": false,
			"alive": true
		}
	}
	
	# Karakter bağlantıları (kimler kimi etkiliyor)
	character_relationships = {
		"cemal": ["baran", "mert"], # Su işçisi olarak Mert'le bağlantılı, Baran onu gözlemliyor
		"ali": ["selma", "selin"], # Anne ve öğretmeni
		"selma": ["ali", "selin"], # Çocuk ve öğretmen
		"baran": ["cemal", "selin"], # Cemal'i gözlemliyor, Selin'le genç bağlantısı
		"mert": ["cemal", "elhami"], # Su sisteminden sorumlu, Elhami'nin ortağı
		"selin": ["ali", "baran"], # Öğrenci ve genç müzisyen
		"elhami": ["mert", "cemal", "ali"] # Herkesi dolaylı etkiliyor
	}

# Her karakter tek seferlik geldiği için visited tracking
var characters_visited = {}
var session_order = [] # Karakterlerin gelme sırası

# Seçim yapma - tek seferlik görüşmeler için
func make_choice(character_name: String, dialogue_id: String, choice_key: String, choice_text: String):
	# Karakteri ziyaret edildi olarak işaretle
	characters_visited[character_name] = true
	session_order.append(character_name)
	
	choices_made[dialogue_id] = {
		"character": character_name,
		"choice": choice_key,
		"text": choice_text,
		"session_number": len(session_order),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Anında etkileri uygula
	process_choice_effects(character_name, dialogue_id, choice_key)
	apply_immediate_consequences(character_name, choice_key)
	update_water_contamination()
	update_elhami_influence()
	
	print("Seçim: ", character_name, " (", dialogue_id, ") -> ", choice_key)
	print("Su kirliliği: ", water_contamination, "% | Elhami gücü: ", elhami_power, "%")

# Seçim etkilerini işle - tek seferlik sistem
func process_choice_effects(character_name: String, dialogue_id: String, choice_key: String):
	var effects = get_choice_effects(character_name, choice_key)
	
	for effect in effects:
		match effect.type:
			"karma":
				karma_score += effect.value
				karma_score = clamp(karma_score, -100, 100)
			"character_state":
				if character_states.has(effect.character):
					character_states[effect.character][effect.attribute] = effect.value
			"water_contamination":
				water_contamination += effect.value
				water_contamination = clamp(water_contamination, 0, 100)
			"elhami_power":
				elhami_power += effect.value
				elhami_power = clamp(elhami_power, 0, 100)
			"town_chaos":
				town_chaos += effect.value
				town_chaos = clamp(town_chaos, 0, 100)
			"death":
				if character_states.has(effect.character):
					character_states[effect.character]["alive"] = false

# Anında sonuçları uygula (tek seferlik görüşmeler için)
func apply_immediate_consequences(character_name: String, choice_key: String):
	match character_name:
		"cemal":
			if choice_key == "investigate_further":
				# Cemal araştırmaya başlar - gelecek karakterleri etkiler
				character_states.cemal.investigation_level = 70
				# Baran gelirse Cemal'in keşiflerini duymuş olacak
				character_states.baran.trust_level += 10
			elif choice_key == "ignore_problem":
				# Su problemi büyür, sonraki karakterler daha fazla etkilenir
				water_contamination += 10
				character_states.ali.alcohol_resistance -= 5
		
		"ali":
			if choice_key == "misdiagnose":
				# Yanlış teşhis etkisi - öğretmen Selin bundan haberdar olacak
				character_states.selin.trust_level -= 20
				character_states.ali.school_performance -= 30
			elif choice_key == "investigate_symptoms":
				# Su problemi keşfi - sonraki karakterler için ipucu
				character_states.cemal.investigation_level += 20
				character_states.baran.mental_state = "alert"
		
		"baran":
			if choice_key == "trigger_violence":
				# Baran Cemal'e saldırabilir
				if character_states.cemal.investigation_level < 40:
					character_states.cemal.alive = false
					town_chaos += 30
				else:
					# Cemal güçlüyse kendini korur
					character_states.baran.mental_state = "defeated"
			elif choice_key == "support_investigation":
				# Müzisyen kasabayı uyarır
				character_states.selin.mental_state = "prepared"
				elhami_power -= 15
		
		"mert":
			if choice_key == "cooperate_with_elhami":
				# Elhami ile tam işbirliği
				water_contamination += 25
				elhami_power += 20
				# Çalışanı öldürür
				town_chaos += 20
			elif choice_key == "free_employee":
				# Çalışanı serbest bırakır ama Elhami intikam alır
				elhami_power -= 10
				# Ama çalışan sonradan öldürülür
				town_chaos += 15
		
		"selin":
			if choice_key == "direct_intervention":
				# Öğrencileri korur
				character_states.ali.mental_state = "recovering"
				character_states.ali.school_performance += 40
			elif choice_key == "cooperate_with_others":
				# Diğer karakterlerle işbirliği
				var cooperation_success = calculate_cooperation_success()
				if cooperation_success > 50:
					elhami_power -= 25
					water_contamination -= 15

# Seçim etkilerini tanımla - tek seferlik görüşmeler
func get_choice_effects(character_name: String, choice_key: String) -> Array:
	var effects = []
	
	match character_name:
		"cemal": # İlk karakter genelde - su problemini keşfeder
			match choice_key:
				"report_authorities":
					effects.append({"type": "karma", "value": 15})
					effects.append({"type": "character_state", "character": "cemal", "attribute": "job_status", "value": "unemployed"})
					effects.append({"type": "elhami_power", "value": 5}) # Elhami dikkat çeker ama güçlenir
				"ignore_problem":
					effects.append({"type": "karma", "value": -20})
					effects.append({"type": "water_contamination", "value": 15})
					effects.append({"type": "elhami_power", "value": 20})
				"investigate_further":
					effects.append({"type": "karma", "value": 25})
					effects.append({"type": "elhami_power", "value": -10})
		
		"ali": # Çocuk hasta - teşhis kritik
			match choice_key:
				"suppress_symptoms":
					effects.append({"type": "karma", "value": -15})
					effects.append({"type": "elhami_power", "value": 15})
				"investigate_symptoms":
					effects.append({"type": "karma", "value": 20})
					effects.append({"type": "water_contamination", "value": -5})
				"dismiss_as_imagination":
					effects.append({"type": "karma", "value": -10})
					effects.append({"type": "elhami_power", "value": 10})
				"misdiagnose":
					effects.append({"type": "karma", "value": -30})
					effects.append({"type": "elhami_power", "value": 25}) # En kötü seçim
		
		"baran": # Müzisyen - kasabayı etkileyebilir
			match choice_key:
				"calm_down":
					effects.append({"type": "karma", "value": -5})
					effects.append({"type": "elhami_power", "value": 10})
				"support_investigation":
					effects.append({"type": "karma", "value": 20})
					effects.append({"type": "elhami_power", "value": -15})
				"redirect_anger":
					effects.append({"type": "karma", "value": 0})
					effects.append({"type": "town_chaos", "value": 10})
				"trigger_violence": # Karanlık seçenek
					effects.append({"type": "karma", "value": -40})
					effects.append({"type": "town_chaos", "value": 30})
		
		"mert": # İşadamı - en kritik karakter
			match choice_key:
				"free_employee":
					effects.append({"type": "karma", "value": 30})
					effects.append({"type": "elhami_power", "value": -20})
					effects.append({"type": "town_chaos", "value": 15}) # Ama sonuçlar var
				"ignore_situation":
					effects.append({"type": "karma", "value": -20})
					effects.append({"type": "elhami_power", "value": 20})
				"cooperate_with_elhami": # En karanlık
					effects.append({"type": "karma", "value": -50})
					effects.append({"type": "elhami_power", "value": 30})
					effects.append({"type": "water_contamination", "value": 25})
				"secret_resistance":
					effects.append({"type": "karma", "value": 25})
					# Başarı şansı önceki seçimlere bağlı
		
		"selin": # Öğretmen - son umut
			match choice_key:
				"direct_intervention":
					effects.append({"type": "karma", "value": 15})
				"observe_wait":
					effects.append({"type": "karma", "value": -10})
					effects.append({"type": "elhami_power", "value": 15})
				"cooperate_with_others":
					effects.append({"type": "karma", "value": 25})
					# Başarı önceki seçimlere bağlı
				"report_authorities":
					effects.append({"type": "town_chaos", "value": 20})
	
	return effects

# İşbirliği başarısını hesapla
func calculate_cooperation_success() -> int:
	var success = 50 # Base
	
	# Önceki karakterlerin durumuna göre
	if character_states.cemal.investigation_level > 50:
		success += 20
	if character_states.baran.mental_state == "alert":
		success += 15
	if character_states.ali.mental_state != "worse_hallucinations":
		success += 10
	if character_states.mert.elhami_cooperation < 50:
		success += 25
	
	# Su kirliliği çok yüksekse zorlaşır
	if water_contamination > 70:
		success -= 30
	
	return success

# Karakter gelme sırasını kontrol et
func get_next_character() -> String:
	var available_characters = ["cemal", "ali", "baran", "mert", "selin"]
	
	for character in available_characters:
		if not characters_visited.has(character):
			return character
	
	return "" # Tüm karakterler geldi

# Tek seferlik görüşme için karakter durumu al
func get_character_current_state(character_name: String) -> Dictionary:
	var state = character_states[character_name].duplicate()
	
	# Önceki seçimlerin etkilerini ekle
	match character_name:
		"ali":
			# Cemal su problemini araştırdıysa Ali daha az etkilenir
			if characters_visited.has("cemal") and character_states.cemal.investigation_level > 50:
				state.mental_state = "slightly_better"
		"baran":
			# Cemal'in durumu Baran'ı etkiler
			if characters_visited.has("cemal"):
				if character_states.cemal.investigation_level > 50:
					state.mental_state = "hopeful"
				elif not character_states.cemal.alive:
					state.mental_state = "grieving"
		"selin":
			# Ali'nin teşhisi Selin'i etkiler
			if characters_visited.has("ali") and character_states.ali.misdiagnosed:
				state.mental_state = "confused"
			# Baran'ın müziği de etkiler
			if characters_visited.has("baran") and character_states.baran.music_influence > 60:
				state.mental_state = "inspired"
	
	return state

# Game Jam için hızlı test
func debug_simulate_playthrough():
	print("=== SİMÜLASYON BAŞLANGICI ===")
	make_choice("cemal", "water_problem", "investigate_further", "Araştır")
	make_choice("ali", "hallucinations", "investigate_symptoms", "Araştır")
	make_choice("baran", "suspicious", "support_investigation", "Destekle")
	make_choice("mert", "corruption", "free_employee", "Serbest bırak")
	make_choice("selin", "students", "cooperate_with_others", "İşbirliği")
	
	print("Final sonuç: ", get_story_outcome())
	debug_print_state()

# Su kirliliği güncellemesi
func update_water_contamination():
	# Elhami'nin su zehirleme faaliyeti
	if character_states.elhami.water_poisoning_active:
		water_contamination += 2
	
	# Cemal araştırırsa kirlilik azalabilir
	if character_states.cemal.investigation_level > 50:
		water_contamination -= 1
	
	water_contamination = clamp(water_contamination, 0, 100)

# Elhami'nin etkisini güncelle
func update_elhami_influence():
	# Su kirliliği arttıkça Elhami güçlenir
	if water_contamination > 70:
		elhami_power += 3
	elif water_contamination > 50:
		elhami_power += 1
	
	# Direnen karakterler varsa güç azalır
	var resistance = 0
	if character_states.cemal.investigation_level > 50: resistance += 10
	if character_states.baran.mental_state == "alert": resistance += 5
	if character_states.mert.mental_state == "plotting": resistance += 15
	
	elhami_power -= resistance / 10
	elhami_power = clamp(elhami_power, 0, 100)

# Domino etkilerini hesapla
func apply_domino_effects():
	# Ali'nin durumu Selin'i etkiler
	if character_states.ali.mental_state == "worse_hallucinations":
		character_states.selin.mental_state = "desperate"
	
	# Cemal'in araştırması Baran'ı etkiler
	if character_states.cemal.investigation_level > 70:
		character_states.baran.mental_state = "supportive"
	
	# Mert'in kararları herkesi etkiler
	if character_states.mert.elhami_cooperation > 80:
		water_contamination += 5
		for char in ["cemal", "ali", "baran", "selin"]:
			if character_states[char].has("alcohol_resistance"):
				character_states[char]["alcohol_resistance"] -= 5

# Hikaye dallanması
func get_story_outcome() -> String:
	var dead_count = 0
	for char in character_states:
		if not character_states[char].alive:
			dead_count += 1
	
	# Ölü sayısı ve karma'ya göre son
	if dead_count >= 3 or karma_score < -50:
		return "dark_ending" # Kasaba Elhami'nin kontrolünde
	elif elhami_power < 30 and karma_score > 30:
		return "good_ending" # Elhami durduruldu
	elif water_contamination < 20:
		return "neutral_ending" # Su temizlendi ama hasarlar var
	else:
		return "chaos_ending" # Kasaba kaosta

# Kayıt/yükleme işlemleri
func save_game():
	var save_data = {
		"choices": choices_made,
		"characters": character_states,
		"karma": karma_score,
		"water_contamination": water_contamination,
		"elhami_power": elhami_power,
		"town_chaos": town_chaos
	}
	
	var file = FileAccess.open("user://elhami_save.dat", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_game():
	if FileAccess.file_exists("user://elhami_save.dat"):
		var file = FileAccess.open("user://elhami_save.dat", FileAccess.READ)
		if file:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			file.close()
			
			if parse_result == OK:
				var data = json.data
				choices_made = data.get("choices", {})
				character_states = data.get("characters", {})
				karma_score = data.get("karma", 0)
				water_contamination = data.get("water_contamination", 30)
				elhami_power = data.get("elhami_power", 50)
				town_chaos = data.get("town_chaos", 20)

# Debug fonksiyonu
func debug_print_state():
	print("=== ELHAMI HİKAYESİ DURUM ===")
	print("Karma: ", karma_score)
	print("Su Kirliliği: ", water_contamination, "%")
	print("Elhami Gücü: ", elhami_power, "%")
	print("Kasaba Kaosu: ", town_chaos, "%")
	print("Yaşayan karakterler:")
	for char in character_states:
		if character_states[char].alive:
			print("- ", char, ": ", character_states[char].mental_state)
	print("==============================")
