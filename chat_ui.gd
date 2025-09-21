extends Control

@onready var messages_container = $ScrollContainer/MessagesContainer
@onready var scroll_container = $ScrollContainer

# Sinyaller
signal choice_selected(dialog_id: int, choice_index: int, choice_text: String)

# Sistem değişkenleri
@export var dialog_file_path: String = "res://dialoglar/dialog.json"
var messages: Array = []
var current_index: int = 0
var waiting_for_choice: bool = false
var current_choices: Array = []
var current_choice_buttons: Array = []
var player_choices: Dictionary = {}
var current_dialog_id: int = 0

func _ready():
	# Container'ı yapılandır
	messages_container.clip_contents = true
	
	# Seçim geçmişini yükle
	load_choices_from_file()
	
	# Mesajları yükle
	messages = load_messages_from_file(dialog_file_path)
	if messages.is_empty():
		printerr("Mesajlar yüklenemedi!")
		return
	
	# İlk mesajı göster
	show_next_message()

func load_messages_from_file(file_path: String) -> Array:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("Dosya açılamadı: ", file_path)
		return []
	
	var json = JSON.new()
	var content = file.get_as_text()
	file.close()
	
	if json.parse(content) != OK:
		printerr("JSON Parse Error: ", json.get_error_message())
		return []
	
	var data = json.data
	if not data is Array:
		printerr("JSON root must be an array")
		return []
	
	return data

func _input(event):
	if waiting_for_choice:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_next_message()

func show_next_message():
	if current_index >= messages.size():
		print("Diyalog sonu")
		return
	
	# Eski mesajları temizle
	if messages_container.get_child_count() >= 10:
		remove_old_messages()
	
	var msg_data = messages[current_index]
	
	# Seçenekli mesaj mı?
	if msg_data.has("choices") and msg_data.choices.size() > 0:
		show_choice_message(msg_data)
	else:
		show_regular_message(msg_data)
	
	current_index += 1
	scroll_to_bottom()

func show_regular_message(msg_data: Dictionary):
	var message_bubble = create_message_bubble(msg_data.text, msg_data.who)
	messages_container.add_child(message_bubble)
	
	# Animasyon
	animate_message_in(message_bubble, msg_data.who)
	add_spacer()

func show_choice_message(msg_data: Dictionary):
	# Önce mesajı göster
	show_regular_message(msg_data)
	
	# Sonra seçenekleri
	current_dialog_id += 1
	waiting_for_choice = true
	current_choices = msg_data.choices
	
	# Kısa gecikme sonrası seçenekleri göster
	await get_tree().create_timer(0.3).timeout
	create_choice_buttons()

func create_choice_buttons():
	clear_current_buttons()
	
	# Seçenek container'ı
	var choice_container = VBoxContainer.new()
	choice_container.name = "ChoiceContainer"
	choice_container.position = Vector2(50, messages_container.size.y + 20)
	choice_container.add_theme_constant_override("separation", 10)
	
	# Seçenekleri oluştur
	for i in range(current_choices.size()):
		var choice = current_choices[i]
		var choice_text = choice.text if choice is Dictionary else str(choice)
		
		var button = create_choice_button(i, choice_text)
		choice_container.add_child(button)
		current_choice_buttons.append(button)
	
	add_child(choice_container)

func create_choice_button(index: int, text: String) -> Button:
	var button = Button.new()
	button.text = str(index + 1) + ". " + text
	button.custom_minimum_size = Vector2(400, 50)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Stil
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.8, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.3, 0.4, 0.9, 1.0)
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Bağlantı
	button.pressed.connect(_on_choice_selected.bind(index, text))
	
	# Hover animasyonu
	button.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	)
	button.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
	)
	
	return button

func _on_choice_selected(choice_index: int, choice_text: String):
	print("Seçim yapıldı: ", choice_index, " - ", choice_text)
	
	# Seçimi kaydet
	save_player_choice(current_dialog_id, choice_index, choice_text)
	
	# Seçenek butonlarını kaldır
	clear_current_buttons()
	
	# Kullanıcının seçimini mesaj olarak göster
	var user_message = {"text": choice_text, "who": "right"}
	show_regular_message(user_message)
	
	# Sinyal gönder
	choice_selected.emit(current_dialog_id, choice_index, choice_text)
	
	# Seçime göre dallanma
	handle_branching(choice_index)
	
	# Devam et
	waiting_for_choice = false
	await get_tree().create_timer(0.5).timeout
	show_next_message()

func handle_branching(choice_index: int):
	if choice_index < current_choices.size():
		var choice = current_choices[choice_index]
		if choice is Dictionary and choice.has("next_index"):
			var next_idx = choice.next_index
			if next_idx >= 0 and next_idx < messages.size():
				current_index = next_idx
				print("Dallanma: ", next_idx, " indexine atlıyor")

func clear_current_buttons():
	for child in get_children():
		if child.name == "ChoiceContainer":
			child.queue_free()
			break
	current_choice_buttons.clear()

func create_message_bubble(text: String, who: String) -> Control:
	# Bubble boyutunu metne göre ayarla
	var char_count = text.length()
	var bubble_width = 200
	if char_count > 50:
		bubble_width = 300
	if char_count > 100:
		bubble_width = 400
	
	# Ana container
	var container = Control.new()
	container.custom_minimum_size = Vector2(0, 60)
	
	# Panel (bubble)
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(bubble_width, 40)
	
	# Stil
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	
	if who == "left":
		style.bg_color = Color(0.9, 0.9, 1.0)
		style.corner_radius_bottom_left = 4
		panel.position.x = 20
	elif who == "right":  # right
		style.bg_color = Color(1.0, 0.9, 0.9)
		style.corner_radius_bottom_right = 6
		panel.position.x = 100
	
	panel.add_theme_stylebox_override("panel", style)
	
	# Metin
	var label = RichTextLabel.new()
	label.text = text
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(bubble_width - 50, 30)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(label)
	panel.add_child(margin)
	
	container.add_child(panel)
	return container

func animate_message_in(message: Control, who: String):
	# Başlangıç pozisyonu
	var start_offset = 100 if who == "left" else -100
	message.position.x += start_offset
	message.modulate.a = 0.0
	
	# Animasyon
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(message, "position:x", message.position.x - start_offset, 0.4)
	tween.tween_property(message, "modulate:a", 1.0, 0.3)

func add_spacer():
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	messages_container.add_child(spacer)

func remove_old_messages():
	var children_to_remove = []
	for child in messages_container.get_children():
		children_to_remove.append(child)
		if children_to_remove.size() >= 5:  # İlk 5 mesajı kaldır
			break
	
	for child in children_to_remove:
		messages_container.remove_child(child)
		child.queue_free()

func scroll_to_bottom():
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

# Seçim kaydetme/yükleme
func save_player_choice(dialog_id: int, choice_index: int, choice_text: String):
	player_choices[dialog_id] = {
		"index": choice_index,
		"text": choice_text,
		"timestamp": Time.get_unix_time_from_system()
	}
	save_choices_to_file()

func save_choices_to_file():
	var file = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(player_choices, "\t"))
		file.close()

func load_choices_from_file():
	var file = FileAccess.open("res://dialoglar.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			player_choices = json.data if json.data is Dictionary else {}
		file.close()
	else:
		player_choices = {}

func get_player_choice(dialog_id: int):
	return player_choices.get(dialog_id, null)

func clear_all_choices():
	player_choices.clear()
	save_choices_to_file()

# Utility fonksiyonlar
func add_message(who: String, text: String):
	messages.append({"who": who, "text": text})

func add_choice_message(who: String, text: String, choices: Array):
	messages.append({"who": who, "text": text, "choices": choices})

func get_choice_summary():
	print("=== OYUNCU SEÇİMLERİ ===")
	for dialog_id in player_choices:
		var choice = player_choices[dialog_id]
		print("Dialog ", dialog_id, ": ", choice.text)
	print("Toplam: ", player_choices.size(), " seçim")
