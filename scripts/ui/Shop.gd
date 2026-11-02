extends CanvasLayer

@onready var list = $Panel/VBox/ItemList
@onready var money_label = $Panel/VBox/MoneyLabel
@onready var close_btn = $Panel/VBox/CloseBtn

func _ready() -> void:
	GameManager.money_changed.connect(_update_money)
	_update_money(GameManager.money)
	_populate_list()
	close_btn.pressed.connect(_on_close_pressed)

func _update_money(amount: int) -> void:
	money_label.text = "Деньги: $" + str(amount)

func _populate_list() -> void:
	for item in EconomyDB.shop_items:
		var btn = Button.new()
		var is_locked = GameManager.progress < item["req"]
		
		if is_locked:
			btn.text = item["name"] + " [ЗАКРЫТО]"
			btn.disabled = true
		else:
			btn.text = item["name"] + " - $" + str(item["price"])
			if item["type"] == "weapon" and GameManager.owned_weapons.has(item["id"]):
				btn.text += " (Куплено)"
				btn.disabled = true
				
			btn.pressed.connect(func(): 
				if EconomyDB.buy_item(item["id"]):
					GameManager.save_game()
					btn.text += " (Куплено)"
					btn.disabled = true
			)
		list.add_child(btn)

func _on_close_pressed() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
