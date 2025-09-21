extends Control

@onready var messages_container = $ScrollContainer/MessagesContainer
@onready var scroll_container = $ScrollContainer

@export var next_scene := NodePath("res://levels/level2.tscn")


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

	# Mesajları yükle
	messages = get_messages(dialog_file_path)
	if messages.is_empty():
		printerr("Mesajlar yüklenemedi. Dosya: ", dialog_file_path)
	else:
		# İlk mesajı göster
		show_next_message()

func get_messages(file_path: String) -> Array:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("Dosya açılamadı: ", file_path, " Error: ", FileAccess.get_open_error())
		return []
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		printerr("JSON Parse Error: ", json.get_error_message())
		file.close()
		return []
	
	file.close()
	var data = json.data
	if typeof(data) != TYPE_ARRAY:
		printerr("JSON root must be an array")
		return []
	
	# Mesaj formatını doğrula
	for msg in data:
		if not msg is Dictionary or not "text" in msg or not "who" in msg:
			printerr("Invalid message format: ", msg)
			return []
		if "choices" in msg and not msg.choices is Array:
			printerr("Invalid choices format in message: ", msg)
			return []
	
	print("Loaded messages: ", data.size())
	return data

func _input(event):
	if waiting_for_choice:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_next_message()

func show_next_message():
	print("Showing message index: ", current_index)
	if current_index >= messages.size():
		print("Diyalog sonu")
		ChangeScene.change_scene(next_scene)
		return
	
	# Eski mesajları temizle
	if messages_container.get_child_count() >= 10:
		remove_old_messages()
	
	var msg_data = messages[current_index]
	
	
	if messages_container.get_child_count() >= 20:
		animate_old_messages_out()
	
	if "choices" in msg_data and msg_data.choices.size() > 0:
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
	show_regular_message({"text": msg_data.text, "who": msg_data.who})
	current_dialog_id += 1
	waiting_for_choice = true
	current_choices = msg_data.choices
	
	if current_choices.is_empty():
		printerr("No choices available for dialog ID: ", current_dialog_id)
		waiting_for_choice = false
		return
	
	messages_container.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	await get_tree().create_timer(0.2).timeout
	create_choice_buttons(msg_data.choices)

func create_choice_buttons(choices: Array):
	current_choice_buttons.clear()
	
	var button_container = VBoxContainer.new()
	button_container.name = "ChoiceButtons"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.custom_minimum_size = Vector2(0, choices.size() * 60 + 20)
	
	for i in range(choices.size()):
		var choice_text = choices[i] if typeof(choices[i]) == TYPE_STRING else choices[i].text
		var button = Button.new()
		button.text = str(i + 1) + ". " + choice_text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 50)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.modulate = Color.BLUE
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.3, 0.8, 1.0)
		button.add_theme_stylebox_override("normal", style)
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.3, 0.4, 0.9, 1.0)
		button.add_theme_stylebox_override("hover", hover_style)
		button.pressed.connect(func(): _on_choice_button_clicked(i, choice_text))
		button.mouse_entered.connect(func(): print("MOUSE GİRDİ: ", i))
		button.mouse_exited.connect(func(): print("MOUSE ÇIKTI: ", i))
		button_container.add_child(button)
		current_choice_buttons.append(button)
		print("Buton oluşturuldu: ", i, " text: ", choice_text)
	
	add_child(button_container)
	print("Buton container eklendi, toplam child: ", get_child_count())

func _on_choice_button_clicked(choice_index: int, choice_text: String):
	print("*** BUTON CALLBACK ÇALIŞTI: ", choice_index, " - ", choice_text, " ***")
	
	save_player_choice(current_dialog_id, choice_index, choice_text)
	
	for child in get_children():
		if child.name == "ChoiceButtons":
			child.queue_free()
			break
	
	current_choice_buttons.clear()
	waiting_for_choice = false
	messages_container.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var user_message = {"text": choice_text, "who": "right"}
	show_regular_message(user_message)
	
	choice_selected.emit(choice_index, choice_text)
	
	# Branching için next_index kontrolü
	if current_choices[choice_index] is Dictionary and "next_index" in current_choices[choice_index]:
		current_index = current_choices[choice_index].next_index
		print("Jumping to index: ", current_index)
	
	show_next_message()



func add_message_spacer():
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	messages_container.add_child(spacer)

func animate_old_messages_out():
	var children_to_remove = []
	for child in messages_container.get_children():
		if child is Panel:
			children_to_remove.append(child)
		if children_to_remove.size() >= 8:
			break
	
	for i in range(children_to_remove.size()):
		animate_message_out(children_to_remove[i], i * 0.05)

func animate_message_out(node: Node, delay: float):
	if delay > 0:
		await get_tree().create_timer(delay).timeout
		create_choice_buttons()


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
	var char_count = text.length()
	var max_width = 150 if char_count <= 20 else 250 if char_count <= 50 else 350 if char_count <= 100 else 450
	
	var message_container = Control.new()
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	message_container.custom_minimum_size = Vector2(0, 50)
	
	var panel = Panel.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var style_box = StyleBoxFlat.new()
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	
	var rich_label = RichTextLabel.new()
	rich_label.text = text
	rich_label.fit_content = true
	rich_label.scroll_active = false
	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_label.custom_minimum_size = Vector2(max_width - 24, 30)
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	margin_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin_container.add_child(rich_label)
	
	panel.add_child(margin_container)
	
	if who == "left":
		style_box.bg_color = Color(0.9, 0.95, 1.0)
		style_box.corner_radius_bottom_left = 4
		panel.position = Vector2(20, 0)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		style_box.bg_color = Color(1.0, 0.9, 0.95)
		style_box.corner_radius_bottom_right = 4
		call_deferred("position_right_message", panel, max_width)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	panel.add_theme_stylebox_override("panel", style_box)
	message_container.add_child(panel)
	
	return message_container


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
	
	var target_y = node.position.y + 200
	tween.tween_property(node, "position:y", target_y, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "modulate:a", 0.0, 0.4)
	tween.tween_property(node, "scale", Vector2(0.8, 0.8), 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	await tween.finished
	if node and is_instance_valid(node):
		messages_container.remove_child(node)
		node.queue_free()


func position_right_message(panel: Panel, max_width: int):
	await get_tree().process_frame
	var container_width = messages_container.size.x
	if container_width > max_width:
		panel.position = Vector2(container_width - max_width - 20, 0)


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
	var file = FileAccess.open("user://save_game.json", FileAccess.WRITE)
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
func clear_messages():
	for child in messages_container.get_children():
		child.queue_free()
	current_index = 0
	current_choice_buttons.clear()

#func add_message(who: String, text: String):
#	messages.append({"who": who, "text": text})
#	show_next_message()

#func add_choice_message(who: String, text: String, choices: Array):
#	messages.append({"who": who, "text": text, "choices": choices})
#	show_next_message()


func get_choice_summary():
	print("=== OYUNCU SEÇİMLERİ ===")
	for dialog_id in player_choices:
		var choice = player_choices[dialog_id]
		print("Dialog ", dialog_id, ": ", choice.text, " (index: ", choice.index, ")")
	print("Toplam seçim sayısı: ", player_choices.size())

func has_made_choice(dialog_id: int, choice_index: int) -> bool:
	var choice = get_player_choice(dialog_id)
	if choice != null:
		return choice.index == choice_index
	return false
