extends Node

# Добавляем параметр "req" (требуемый уровень прогресса) для каждого предмета
var shop_items = [
	# Доступно с самого начала
	{"id": "armor", "name": "Броня (50 AP)", "price": 650, "type": "armor", "req": 0},
	{"id": "medkit", "name": "Аптечка (50 HP)", "price": 200, "type": "consumable", "req": 0},
	{"id": "ammo_rifle", "name": "Патроны: Автомат (30)", "price": 80, "type": "ammo", "weapon": "rifle", "amount": 30, "req": 0},
	
	# Открывается после склада (миссия 1)
	{"id": "shotgun", "name": "Дробовик", "price": 1200, "type": "weapon", "req": 1},
	{"id": "ammo_shotgun", "name": "Патроны: Дробовик (8)", "price": 60, "type": "ammo", "weapon": "shotgun", "amount": 8, "req": 1},
	
	# Открывается после пригорода (миссия 2)
	{"id": "rifle", "name": "Автомат", "price": 2700, "type": "weapon", "req": 2},
	
	# Открывается после завода (миссия 3)
	{"id": "sniper", "name": "Снайперка", "price": 4750, "type": "weapon", "req": 3},
	{"id": "ammo_sniper", "name": "Патроны: Снайперка (10)", "price": 150, "type": "ammo", "weapon": "sniper", "amount": 10, "req": 3},
	
	# Crysis Оружие (открывается после Завода)
	{"id": "minigun", "name": "Миниган", "price": 5000, "type": "weapon", "req": 3},
	{"id": "rocket", "name": "Ракетница", "price": 4000, "type": "weapon", "req": 3},
	{"id": "flamer", "name": "Огнемет", "price": 3500, "type": "weapon", "req": 3}
]

func buy_item(item_id: String) -> bool:
	for item in shop_items:
		if item["id"] == item_id:
			if item["type"] == "weapon" and GameManager.owned_weapons.has(item["id"]):
				return false
				
			if GameManager.spend_money(item["price"]):
				if item["type"] == "weapon":
					GameManager.owned_weapons.append(item["id"])
				elif item["type"] == "ammo":
					GameManager.extra_ammo[item["weapon"]] += item["amount"]
				return true
	return false
