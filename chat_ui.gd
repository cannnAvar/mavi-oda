extends Control

@onready var messages_container = $ScrollContainer/MessagesContainer
@onready var scroll_container = $ScrollContainer

# Deneme mesajları
var messages = [
	{"who": "left", "text": "Selam, nasılsın?"},
	{"who": "right", "text": "İyiyim, sen nasılsın?"},
	{"who": "left", "text": "Bugün hava çok güzel!"},
	{"who": "right", "text": "Evet, yürüyüşe çıkabilirim."},
	{"who": "left", "text": "Bu uzun bir mesaj örneği. ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ ZENCİ"},
	{"who": "right", "text": "Haklısın, NİGGER NİGGER NİGGER"}
]

var current_index = 0

func _ready():
	# İlk mesajı göster
	show_next_message()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_next_message()

func show_next_message():
	if current_index >= messages.size():
		return
	
	# Her 3. mesajda eski mesajları animasyonla sil
	if messages_container.get_child_count() >= 5:
		animate_old_messages_out()
	
	var msg_data = messages[current_index]
	
	# Mesaj uzunluğuna göre maksimum genişlik hesapla
	var char_count = msg_data.text.length()
	var max_width = 0
	
	if char_count <= 20:
		max_width = 150
	elif char_count <= 50:
		max_width = 250
	elif char_count <= 100:
		max_width = 350
	else:
		max_width = 450
	
	# Ana container
	var message_container = Control.new()
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	message_container.custom_minimum_size = Vector2(0, 50)
	
	# Mesaj balonu - RichTextLabel 
	var panel = Panel.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Panel stili
	var style_box = StyleBoxFlat.new()
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	
	# RichTextLabel - Label yerine (autowrap düzgün çalışır)
	var rich_label = RichTextLabel.new()
	rich_label.text = msg_data.text
	rich_label.fit_content = true
	rich_label.scroll_active = false
	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_label.custom_minimum_size = Vector2(max_width - 24, 30)
	
	# Margin container
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.add_theme_constant_override("margin_right", 12)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	margin_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin_container.add_child(rich_label)
	
	panel.add_child(margin_container)
	
	# Pozisyonlama
	if msg_data.who == "left":
		# Sol mesaj
		style_box.bg_color = Color(0.9, 0.95, 1.0)
		style_box.corner_radius_bottom_left = 4
		
		# Paneli sola hizala
		panel.position = Vector2(20, 0)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
	else:
		# Sağ mesaj
		style_box.bg_color = Color(1.0, 0.9, 0.95)
		style_box.corner_radius_bottom_right = 4
		
		# Paneli sağa hizala - ekran genişliğine göre hesapla
		call_deferred("position_right_message", panel, max_width)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Style uygula
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Panel'i container'a ekle
	message_container.add_child(panel)
	
	# Container'ı messages_container'a ekle
	messages_container.add_child(message_container)
	
	# Animasyon için başlangıç pozisyonu ayarla
	var start_offset = 300 if msg_data.who == "left" else -300
	message_container.position.x = start_offset
	message_container.modulate.a = 0.0  # Şeffaf başla
	
	# Kayma animasyonu
	animate_message_in(message_container)
	
	# Mesajlar arası boşluk
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	messages_container.add_child(spacer)
	
	current_index += 1
	
	# Scroll aşağı
	call_deferred("scroll_to_bottom")

func animate_old_messages_out():
	# İlk 3 child'ı al (2 mesaj + 1 spacer)
	var children_to_remove = []
	for i in range(min(3, messages_container.get_child_count())):
		children_to_remove.append(messages_container.get_child(i))
	
	# Her child için aşağı kayma animasyonu
	for i in range(children_to_remove.size()):
		var child = children_to_remove[i]
		animate_message_out(child, i * 0.1)  # Staggered animasyon

func animate_message_out(node: Node, delay: float):
	# Gecikme ile başla
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Aşağı doğru kayma (kadrajdan çıkana kadar)
	var target_y = node.position.y + 200  # 200px aşağı
	var move_tween = tween.tween_property(node, "position:y", target_y, 0.5)
	move_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	# Fade out
	tween.tween_property(node, "modulate:a", 0.0, 0.4)
	
	# Hafif ölçek küçülme efekti
	var scale_tween = tween.tween_property(node, "scale", Vector2(0.8, 0.8), 0.5)
	scale_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	# Animasyon bitince sil
	await tween.finished
	if node and is_instance_valid(node):
		messages_container.remove_child(node)
		node.queue_free()

func animate_message_in(message_container: Control):
	# Tween oluştur
	var tween = create_tween()
	tween.set_parallel(true)  # Paralel animasyonlar için
	
	# Kayma animasyonu (x pozisyonu 0'a)
	tween.tween_property(message_container, "position:x", 0, 0.4)
	tween.tween_property(message_container, "position:x", 0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Fade in animasyonu
	tween.tween_property(message_container, "modulate:a", 1.0, 0.3)
	
	# Hafif bounce efekti
	tween.tween_property(message_container, "scale", Vector2(1.05, 1.05), 0.2).set_delay(0.2)
	tween.tween_property(message_container, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.35)

func position_right_message(panel: Panel, max_width: int):
	await get_tree().process_frame
	var container_width = messages_container.size.x
	if container_width > max_width:
		panel.position = Vector2(container_width - max_width - 20, 0)

func scroll_to_bottom():
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

# İsteğe bağlı: Tüm mesajları temizle
func clear_messages():
	for child in messages_container.get_children():
		child.queue_free()
	current_index = 0

# İsteğe bağlı: Yeni mesaj ekle
func add_message(who: String, text: String):
	messages.append({"who": who, "text": text})
	show_next_message()
