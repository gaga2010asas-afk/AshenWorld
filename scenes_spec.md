# VIBE SHOOTER — SCENES AND SCRIPTS SPECIFICATION (v1)

## 0. FILE ORGANIZATION
res://
├── project.godot
├── materials/{metal,rust,concrete,accent}.tres
├── data/
│   ├── weapons/{pistol,rifle,shotgun,sniper,grenade}.tres
│   ├── shop/{weapon_rifle,weapon_shotgun,weapon_sniper,kevlar,kevlar_helmet,ammo_rifle,ammo_shotgun,ammo_sniper,grenade,medkit}.tres
│   └── waves/{easy_1,easy_2,normal_1,normal_2,hard_1,hard_2,hard_3,boss_mech,boss_drone,boss_chief}.tres
├── scenes/
│   ├── MainMenu.tscn / Lobby.tscn / Hub.tscn
│   ├── levels/{Level_Sklad,Level_Prigorod,Level_Zavod,Level_Lair}.tscn
│   ├── actors/{Player,Ragdoll}.tscn
│   ├── enemies/{Enemy_Rifle,Enemy_Shotgun,Enemy_Sniper}.tscn
│   ├── bosses/{Boss_Mech,Boss_Drone,Boss_Chief}.tscn
│   ├── pickups/{Pickup_Money,Pickup_Ammo,Pickup_Weapon,Pickup_Health}.tscn
│   ├── weapons/Grenade.tscn
│   └── ui/{HUD,PauseMenu,Shop,Dialogue}.tscn
└── scripts/
    ├── autoload/{GameManager,NetworkManager,WeaponDB,EconomyDB}.gd
    ├── actors/{Player,CameraController,WeaponHolder,Health,Armor,PlayerInput}.gd
    ├── enemies/{EnemyBase,EnemyStateMachine}.gd
    ├── states/{IdleState,PatrolState,ChaseState,AttackState,DeadState}.gd
    ├── bosses/{BossMech,BossDrone,BossChief}.gd
    ├── level/{LevelBuilder,LevelController,WaveManager}.gd
    ├── resources/{WeaponData,ShopItem,WaveResource}.gd
    ├── ui/{HUD,Crosshair,PauseMenu,Shop,ShopCard,Dialogue,MainMenu,Lobby}.gd
    ├── pickups/{MoneyPickup,AmmoPickup,WeaponPickup,HealthPickup}.gd
    ├── weapons/{Grenade,Ragdoll}.gd
    └── hub/{Hub,Chief,ShopTrigger}.gd

## 1. AUTOLOADS (project.godot -> [autoload])
GameManager  = "*res://scripts/autoload/GameManager.gd"
NetworkManager = "*res://scripts/autoload/NetworkManager.gd"
WeaponDB     = "*res://scripts/autoload/WeaponDB.gd"
EconomyDB    = "*res://scripts/autoload/EconomyDB.gd"

Responsibilities:
- GameManager: current_mission_id, difficulty, player_money:Dictionary(peer_id->int), owned_weapons:Dictionary(peer_id->Array[StringName]), start_mission(id), return_to_hub(), add_money(peer_id, amount), spend(peer_id, amount)->bool. Signals: money_changed, objective_changed, dialogue_requested.
- NetworkManager: host(port:int=7777), join(ip, port:int=7777), disconnect(). Signals: peer_joined, peer_left, connection_failed.
- WeaponDB: get_weapon(id:StringName)->WeaponData, list_ids()->Array[StringName].
- EconomyDB: shop_items()->Array[ShopItem], buy(peer_id, item_id)->bool, kill_reward(weapon_id)->int, wave_bonus(difficulty:int)->int.

## 2. MATERIALS (res://materials/)
metal.tres    — StandardMaterial3D albedo Color(0.42,0.42,0.42,1), roughness 0.85, metallic 0.2
rust.tres     — albedo Color(0.545,0.271,0.075,1), roughness 1.0, metallic 0.0
concrete.tres — albedo Color(0.243,0.184,0.110,1), roughness 1.0, metallic 0.0
accent.tres   — albedo Color(1.0,0.42,0.208,1), emission_enabled=true, emission=Color(1,0.42,0.208,1), emission_energy=1.5

## 3. RESOURCES (data/)

WeaponData (Resource, scripts/resources/WeaponData.gd):
  @export id:StringName; display_name:String
  @export damage:float; pellets:int=1
  @export fire_rate_rpm:int; mag_size:int; reserve_max:int
  @export reload_time:float; spread_deg:float
  @export armor_pen:float; price:int; kill_reward:int
  @export view_model_scene:PackedScene; world_model_scene:PackedScene

ShopItem (Resource):
  @export id:StringName; category:StringName; display_name:String; price:int
  @export payload:Dictionary

WaveResource (Resource):
  @export difficulty:int  # 0=easy,1=normal,2=hard
  @export wave_index:int
  @export entries:Array[Dictionary]  # [{type:StringName, count:int}]
  @export is_boss_wave:bool=false; boss_type:StringName
  @export time_bonus_seconds:float=90.0

Weapon .tres values (from combat math):
- pistol:  damage 26, pellets 1,  rpm 400, mag 12, reserve 999, reload 1.4, spread 1.2, pen 0.50, price 0,    kill 300
- rifle:   damage 33, pellets 1,  rpm 600, mag 30, reserve 90,  reload 2.4, spread 1.8, pen 0.775,price 2700, kill 300
- shotgun: damage 8,  pellets 12, rpm 80,  mag 8,  reserve 24,  reload 3.0, spread 6.0, pen 0.60, price 1200, kill 900
- sniper:  damage 115,pellets 1,  rpm 40,  mag 5,  reserve 20,  reload 3.8, spread 0.2, pen 1.00, price 4750, kill 100
- grenade: damage 80, radius 3m,     price 300, kill 300

Shop .tres (10 items per economy spec): rifle $2700, shotgun $1200, sniper $4750, kevlar $650, kevlar_helmet $1000, ammo_rifle $80/30, ammo_shotgun $60/8, ammo_sniper $150/10, grenade $300, medkit $200.

Waves: easy_1(5,{rifle:5}), easy_2(5,{rifle:3,shotgun:2}), normal_1(8,{rifle:5,shotgun:2,sniper:1}), normal_2(8,{rifle:4,shotgun:3,sniper:1}), hard_1(12,{rifle:7,shotgun:3,sniper:2}), hard_2(12,{rifle:8,shotgun:3,sniper:1}), hard_3(12,{rifle:6,shotgun:4,sniper:2}), boss_mech/drone/chief(is_boss_wave=true, replaces 4 bots).

## 4. SCENES — NODE TREES

### scenes/MainMenu.tscn
MainMenu (Control) [scripts/ui/MainMenu.gd]
├── Background (TextureRect, full rect, dark gradient)
├── CenterVBox (VBoxContainer, anchors center)
│   ├── Title (Label "VIBE SHOOTER")
│   ├── BtnHost (Button "Создать игру (LAN)")
│   ├── BtnJoin (Button "Подключиться")
│   ├── BtnSettings (Button "Настройки")
│   └── BtnQuit (Button "Выход")
└── VersionLabel (Label, bottom-right)
Wiring: BtnHost -> NetworkManager.host(7777); change_scene("res://scenes/Lobby.tscn"). BtnJoin -> change_scene Lobby (client mode). BtnQuit -> get_tree().quit().

### scenes/Lobby.tscn
Lobby (Control) [scripts/ui/Lobby.gd]
├── PlayerListVBox (VBoxContainer, top-left) — dynamic PlayerRow
├── JoinBox (HBoxContainer, top-right, visible only if client)
│   ├── IPInput (LineEdit placeholder "192.168.x.x")
│   └── BtnConnect (Button)
├── SettingsBox (HBoxContainer, bottom-center)
│   ├── DifficultyLabel (Label)
│   └── DifficultyOption (OptionButton: Лёгкая/Средняя/Сложная)
├── BtnStart (Button, visible only if host)
└── BtnLeave (Button)
Wiring: BtnStart -> GameManager.difficulty = opt.selected; change_scene("res://scenes/Hub.tscn"); server rpc to all peers -> change_scene same path.

### scenes/Hub.tscn
Hub (Node3D) [scripts/hub/Hub.gd]
├── Environment (WorldEnvironment: fog_enabled, ambient dark)
├── SunLight (DirectionalLight3D, warm)
├── Floor (StaticBody3D: MeshInstance3D BoxMesh 30x0.3x30 concrete, CollisionShape3D)
├── Walls (StaticBody3D: several BoxMesh colliders, rust/concrete)
├── Chief (CharacterBody3D) [scripts/hub/Chief.gd]
│   ├── BodyMesh (MeshInstance3D CapsuleMesh 0.5x2.0, metal + accent gold BoxMesh)
│   ├── HeadMesh (MeshInstance3D SphereMesh 0.25 metal)
│   ├── DialogueArea (Area3D SphereShape3D 2.5)
│   └── NameLabel (Label3D "MAIN CHIEF")
├── ShopCounter (StaticBody3D + MeshInstance3D concrete)
├── ShopTrigger (Area3D SphereShape3D 2.0) [scripts/hub/ShopTrigger.gd]
├── MissionDoors (Node3D)
│   ├── Door_Sklad (Area3D, meta mission_id="sklad")
│   ├── Door_Prigorod (Area3D, meta mission_id="prigorod")
│   ├── Door_Zavod (Area3D, meta mission_id="zavod")
│   └── Door_Lair (Area3D, meta mission_id="lair")
└── PlayerSpawn (Marker3D)
Wiring: DialogueArea body_entered(player) -> GameManager.dialogue_requested.emit(briefing_lines, "Chief"). Door body_entered -> GameManager.start_mission(meta). ShopTrigger body_entered -> change_scene Shop overlay (CanvasLayer or process_mode ALWAYS).

### scenes/levels/Level_Sklad.tscn (structure shared by all 4 levels)
Level_Sklad (Node3D) [scripts/level/LevelController.gd]
├── Environment (WorldEnvironment, fog density 0.02)
├── SunLight (DirectionalLight3D, warm)
├── NavRegion (NavigationRegion3D, NavigationMesh res)
├── LevelGeometry (Node3D) — populated by LevelBuilder.build(self, spec) in _ready
├── SpawnMarkers (Node3D)
│   ├── Spawn_1..Spawn_8 (Marker3D)
├── PlayerSpawns (Node3D)
│   ├── PlayerSpawn_1..PlayerSpawn_4 (Marker3D)
├── Triggers (Node3D)
│   ├── Trigger_Wave_1 (Area3D, meta wave_idx=0)
│   ├── Trigger_Wave_2 (Area3D, meta wave_idx=1)
│   └── Trigger_Boss (Area3D, meta wave_idx=boss) — only Level_Lair
├── WaveManager (Node) [scripts/level/WaveManager.gd]
└── ExitArea (Area3D) — body_entered -> GameManager.return_to_hub()
LevelController.gd exports: level_id:StringName, wave_sequence:Array[WaveResource], boss_resource:WaveResource(optional), level_spec:Dictionary.
Per-level: Sklad(easy_1,easy_2), Prigorod(normal_1,normal_2 + boss_mech), Zavod(normal_2,hard_1 + boss_drone, vertical platforms), Lair(hard_2,hard_3 + boss_chief).

### scenes/actors/Player.tscn
Player (CharacterBody3D) [scripts/actors/Player.gd]
├── CollisionShape3D (CapsuleShape3D r=0.4 h=1.8)
├── BodyMesh (MeshInstance3D CapsuleMesh, metal)  — hidden for local player
├── Head (Node3D, height 1.6)
│   ├── Camera3D [scripts/actors/CameraController.gd]
│   │   └── WeaponHolder (Node3D) [scripts/actors/WeaponHolder.gd]
│   └── HeadMesh (MeshInstance3D SphereMesh 0.25 metal)
├── Health (Node) [scripts/actors/Health.gd]   hp=100, no regen
├── Armor (Node)  [scripts/actors/Armor.gd]    armor=0, helmet=false
├── PlayerInput (Node) [scripts/actors/PlayerInput.gd]
├── NameLabel (Label3D)
└── MultiplayerSynchronizer — syncs position/rotation/current_weapon_id at 20Hz

### scenes/enemies/Enemy_Rifle.tscn
Enemy_Rifle (CharacterBody3D) [scripts/enemies/EnemyBase.gd]
├── CollisionShape3D (CapsuleShape3D r=0.4 h=1.6)
├── BodyMesh (MeshInstance3D CapsuleMesh metal)
├── HeadMesh (MeshInstance3D SphereMesh 0.2 metal)
├── ShoulderAccent (MeshInstance3D BoxMesh, red Color(0.75,0.22,0.16,1))
├── GunModel (Node3D)
│   ├── Receiver (MeshInstance3D BoxMesh)
│   └── Barrel (MeshInstance3D CylinderMesh)
├── Health (Node) [scripts/actors/Health.gd]
├── StateMachine (Node) [scripts/enemies/EnemyStateMachine.gd]
│   ├── IdleState (Node) [scripts/states/IdleState.gd]
│   ├── PatrolState (Node) [scripts/states/PatrolState.gd]
│   ├── ChaseState (Node) [scripts/states/ChaseState.gd]
│   ├── AttackState (Node) [scripts/states/AttackState.gd]
│   └── DeadState (Node) [scripts/states/DeadState.gd]
├── NavAgent (NavigationAgent3D)
├── VisionArea (Area3D SphereShape3D 20)
├── ShootTimer (Timer 1.5)
└── MultiplayerSynchronizer
Enemy_Shotgun: capsule 0.45x1.5, orange Color(0.9,0.49,0.13,1) accent, Cylinder+Box gun, shoot_timer 2.0, move_speed 4.5.
Enemy_Sniper:  capsule 0.35x1.7, purple Color(0.55,0.27,0.68,1), long Cylinder gun, stationary at spawn, shoot_timer 3.0, damage 115.

### scenes/bosses/Boss_Mech.tscn
Boss_Mech (CharacterBody3D) [scripts/bosses/BossMech.gd]
├── CollisionShape3D (BoxShape3D 2x1.5x2.5)
├── BodyMesh (BoxMesh, rust)
├── Arms (Node3D: ArmL, ArmR — BoxMesh each)
├── Wheels (Node3D: Wheel_1..4 — CylinderMesh)
├── EyeLamp (SphereMesh 0.15 accent emissive) — weak_point meta=true
├── Health (Node, hp=800)
├── NavAgent, AttackTimer
└── MultiplayerSynchronizer

### scenes/bosses/Boss_Drone.tscn
Boss_Drone (CharacterBody3D, hovering — gravity off)
├── CollisionShape3D (SphereShape3D 0.8)
├── BodyMesh (SphereMesh, metal)
├── Rotors (Node3D: 4x CylinderMesh) — weak points
├── GunBarrel (CylinderMesh)
├── EyeLamp (SphereMesh, red emissive)
├── Health (hp=500)
├── HoverBob (AnimationPlayer, loop)
├── BurstTimer (2.5s)
└── MultiplayerSynchronizer

### scenes/bosses/Boss_Chief.tscn
Boss_Chief (CharacterBody3D) [scripts/bosses/BossChief.gd]
├── CollisionShape3D (CapsuleShape3D 0.5x2.0)
├── BodyMesh (CapsuleMesh metal)
├── CloakMesh (BoxMesh 0.6x1.2x0.1, rust)
├── HeadMesh (SphereMesh metal)
├── Staff (CylinderMesh, accent gold)
├── Health (hp=1200)
├── StateMachine (EnemyBase FSM + GrenadeThrowState)
├── NavAgent, ShootTimer, GrenadeTimer
└── MultiplayerSynchronizer

### scenes/actors/Ragdoll.tscn
Ragdoll (RigidBody3D) [scripts/weapons/Ragdoll.gd]
├── CollisionShape3D (CapsuleShape3D, set on spawn)
├── BodyMesh (CapsuleMesh)
├── HeadMesh (SphereMesh)
└── CleanupTimer (Timer 10.0, autostart)
Ragdoll.gd: _ready -> apply_central_impulse(stored_impulse); angular_velocity = random_unit * 8.0. On timeout -> queue_free().

### scenes/pickups/Pickup_Money.tscn
Pickup_Money (Area3D) [scripts/pickups/MoneyPickup.gd]
├── CollisionShape3D (SphereShape3D 1.5)
├── Mesh (MeshInstance3D BoxMesh 0.3 accent emissive) — bobs+spins in _process
├── Label3D (Label3D "+$300")
└── LifetimeTimer (Timer 30.0)
Pickup_Ammo / Pickup_Weapon / Pickup_Health: same skeleton, different metadata keys ("ammo_id","weapon_id","heal_amount").

### scenes/weapons/Grenade.tscn
Grenade (RigidBody3D) [scripts/weapons/Grenade.gd]
├── CollisionShape3D (SphereShape3D 0.12)
├── Mesh (SphereMesh 0.12 metal)
├── Lever (CylinderMesh accent)
├── FuseTimer (3.0)
└── ExplosionArea (Area3D SphereShape3D 3.0)

### scenes/ui/HUD.tscn
HUD (CanvasLayer) [scripts/ui/HUD.gd]
├── Crosshair (Control, center) [scripts/ui/Crosshair.gd]
├── HealthArmor (HBoxContainer, bottom-left)
│   ├── HealthBar (TextureProgressBar fill)
│   └── ArmorBar (TextureProgressBar fill, blue tint)
├── Ammo (VBoxContainer, bottom-right)
│   ├── AmmoLabel (Label large font)
│   └── WeaponName (Label)
├── GrenadeIcon (TextureRect, bottom-center)
├── ObjectiveLabel (Label, top-center)
├── MoneyLabel (Label, top-right)
├── DamageFlash (ColorRect full-screen red alpha 0)
└── PauseMenuInstance (instance of PauseMenu.tscn, hidden)
HUD.gd API: bind_to_player(p), update_health(hp,max), update_armor(a,max), update_ammo(mag,res,name), update_money(v), flash_damage(), set_objective(t).

### scenes/ui/PauseMenu.tscn
PauseMenu (Control) [scripts/ui/PauseMenu.gd]  process_mode = ALWAYS
├── Dimmer (ColorRect black 0.6)
└── VBox (anchors center): BtnResume, BtnSettings, BtnLeaveToHub, BtnQuit
Behavior: get_tree().paused = true on open. Network RPCs continue (server-authoritative loop not paused; use process_mode ALWAYS on network nodes or scene-tree paused check bypass).

### scenes/ui/Shop.tscn
Shop (Control) [scripts/ui/Shop.gd]
├── PlayerMoneyLabel (Label, top-right)
├── Tabs (TabContainer below top)
│   ├── Weapons (GridContainer 3 cols)
│   ├── Armor (GridContainer)
│   └── Consumables (GridContainer)
└── BtnClose (Button, bottom)
ShopCard (PanelContainer: Button + NameLabel + PriceLabel) [scripts/ui/ShopCard.gd]
Shop.gd: populate from EconomyDB.shop_items(); disable if GameManager.owned_weapons[peer_id].has(id); buy -> EconomyDB.buy(peer_id, id) -> refresh.

### scenes/ui/Dialogue.tscn
Dialogue (Control) [scripts/ui/Dialogue.gd]
├── Portrait (TextureRect 128x128)
├── NameLabel (Label)
├── TextLabel (RichTextLabel, autoscroll)
├── BtnNext (Button)
└── BtnSkip (Button)
Dialogue.gd: show(lines:Array[String], speaker:String). Sets local PlayerInput.shooting_enabled=false while open (camera NOT blocked).

## 5. KEY SCRIPT INTERFACES

Health.gd:
  signal died(impulse_dir:Vector3)
  @export var max_hp:float = 100
  var hp:float
  func take_damage(amount:float, zone:StringName, armor_ref:Armor)->float
  func heal(amount:float)
  func is_dead()->bool
  Damage formula: final = base * zone_mult * (armor? armor_pen : 1.0); if armor>0: armor.armor -= final*0.5; final *= 0.5. zone_mult: head=4.0, torso=1.0, stomach=1.25, legs=0.75. Helmet disables head mult (zone becomes torso).

Armor.gd:
  @export var armor_max:float = 100
  var armor:float = 0.0
  var helmet:bool = false
  func absorb(damage:float)->float
  func has_helmet()->bool

WeaponHolder.gd:
  signal ammo_changed(mag:int, reserve:int, weapon_name:String)
  signal reload_started(duration:float)
  var current_weapon:WeaponData; var mag:int; var reserve:int
  func switch_to(weapon_id:StringName)
  func fire()->bool
  func reload()->void

Crosshair.gd:
  func set_spread(deg:float)
  func on_fire()

WaveManager.gd (server-only):
  @export var wave_resources:Array[WaveResource]
  signal wave_started(index:int)
  signal wave_cleared(index:int, time_taken:float)
  signal all_waves_cleared()
  func start_wave(index:int)
  func register_enemy(e:Node)
  func _on_enemy_died()

LevelController.gd:
  @export var level_id:StringName
  @export var wave_sequence:Array[WaveResource]
  @export var boss_resource:WaveResource
  @export var level_spec:Dictionary
  func _ready(): if multiplayer.is_server(): LevelBuilder.build(self, level_spec); NavRegion.bake_navigation_mesh()

LevelBuilder.gd (static):
  static func build(root:Node3D, spec:Dictionary)->void
  # spec = {rooms:[...], corridors:[...], doors:[...], lamps:[...], spawn_points:[...], triggers:[...]}
  # Creates StaticBody3D + MeshInstance3D (primitive) + CollisionShape3D for walls/floor.
  # Creates Marker3D for each spawn point (name Spawn_i).
  # Creates Area3D for each trigger (name Trigger_Wave_i).
  # Uses materials only — no inline Color literals in geometry.

EnemyBase.gd:
  @export var enemy_type:StringName
  @export var move_speed:float = 3.5
  @export var damage:float = 33
  @export var shoot_range:float = 18.0
  var target:Node3D
  func take_damage(amount:float, zone:StringName, armor:Armor)->float
  func die(impulse_dir:Vector3)->void
  # die(): rpc("_spawn_ragdoll", global_position, impulse_dir, enemy_type); queue_free()

Player.gd (network):
  movement local only -> MultiplayerSynchronizer at 20Hz
  shoot: rpc_id(1, "_server_fire", origin:Vector3, dir:Vector3, weapon_id:StringName)
  _server_fire validates, raycasts, calls target.Health.take_damage
  damage: server rpc_id(target_peer, "client_take_damage", amount:float, zone:StringName)

## 6. SIGNAL BUS (GameManager)
signal money_changed(peer_id:int, amount:int)
signal objective_changed(text:String)
signal dialogue_requested(lines:Array[String], speaker:String)

## 7. BUILD ORDER (implementing AI MUST follow)

STEP 1 — Foundation
  1.1 project.godot (config/features PackedStringArray("4.3","Forward Plus"), [autoload] 4 entries, input map: move_forward/back/left/right, jump, crouch, fire, aim, reload, grenade, weapon_1..4, pause, interact, scoreboard).
  1.2 4 materials .tres.
  1.3 4 autoload scripts — full public API, empty bodies where logic isn't wired yet.
  1.4 data/weapons/*.tres, data/shop/*.tres, data/waves/*.tres.

STEP 2 — Player single-player
  2.1 Player.tscn: CharacterBody3D + CapsuleMesh + Camera3D.
  2.2 Player.gd: move_and_slide WASD, crouch (Shift), jump (Space), gravity 20.
  2.3 CameraController.gd: mouse look, pitch clamp -89..89.
  2.4 Health.gd, Armor.gd.
  2.5 WeaponHolder.gd: 4 weapon slots, raycast fire, reload, switch.

STEP 3 — Combat single enemy
  3.1 Enemy_Rifle.tscn + EnemyBase.gd.
  3.2 EnemyStateMachine.gd + IdleState/PatrolState/ChaseState/AttackState/DeadState.
  3.3 NavigationAgent3D + VisionArea detection.
  3.4 Enemy shooting -> Player.Health.take_damage (server-direct in SP test).
  3.5 Player shooting -> Enemy.Health.take_damage.
  3.6 On death: Ragdoll.tscn with apply_central_impulse.

STEP 4 — HUD + Crosshair
  4.1 HUD.tscn + HUD.gd bound via signals.
  4.2 Crosshair.gd draws 4 lines + dot (draw_line with int coords, thickness Color(1,1,1,1)).
  4.3 DamageFlash Tween 0 -> 0.4 -> 0 over 0.15s.
  4.4 Ammo/HP/Armor bound to signals.

STEP 5 — Wave system
  5.1 WaveManager.gd.
  5.2 Level_Sklad.tscn + LevelBuilder.build() (corridor 40m + 8 spawn markers + 2 triggers).
  5.3 Test: enter trigger -> wave 1 spawns -> clear -> wave 2 -> exit -> return_to_hub.

STEP 6 — Menus + Networking
  6.1 MainMenu.tscn + MainMenu.gd.
  6.2 Lobby.tscn + Lobby.gd.
  6.3 NetworkManager host/join ENetMultiplayerPeer, port 7777, max_peers 8.
  6.4 Player MultiplayerSynchronizer (pos, rot, weapon_id).
  6.5 Server-authoritative shooting: rpc_id(1,"_server_fire").

STEP 7 — Hub + Shop + Dialogue
  7.1 Hub.tscn.
  7.2 Chief.gd + Dialogue.tscn + Dialogue.gd.
  7.3 Shop.tscn + Shop.gd + ShopCard.gd.
  7.4 EconomyDB.buy() -> server validation -> GameManager.add_money(-price).
  7.5 MissionDoors -> GameManager.start_mission(id).

STEP 8 — All levels + Bosses
  8.1 Level_Prigorod.tscn + Boss_Mech.tscn.
  8.2 Level_Zavod.tscn + Boss_Drone.tscn (vertical platforms, sniper).
  8.3 Level_Lair.tscn + Boss_Chief.tscn.
  8.4 Mission clear bonus $800 on ExitArea -> return_to_hub.

STEP 9 — Pickups + Economy drops
  9.1 Pickup_Money.tscn spawned on enemy death with amount = kill_reward + (headshot?100:0).
  9.2 Pickup_Ammo, Pickup_Weapon.
  9.3 Hidden money crate (1-2 per level).
  9.4 Area3D body_entered -> GameManager.add_money(peer_id, amount) (server-auth).

STEP 10 — Polish + LINT
  10.1 Fog, lighting per level.
  10.2 Camera shake on damage (Tween Camera3D.position offset).
  10.3 Procedural sounds via AudioStreamGenerator (no external assets).
  10.4 # LINT: gdscript on every .gd, fix warnings.
  10.5 Playtest Sklad: verify income $1500-2000 (never > $2500).

## 8. VERIFICATION CHECKLIST
[ ] All 24 .tscn exist
[ ] All 4 materials referenced; no inline hex strings in scripts (Color(r,g,b,a) or material.tres only)
[ ] project.godot [autoload] has exactly 4 entries
[ ] Input map has 12+ actions
[ ] Player.tscn: local player sees no body mesh (BodyMesh.hide for is_multiplayer_authority)
[ ] Enemy death spawns Ragdoll with impulse + angular_velocity
[ ] WaveManager runs only on server (multiplayer.is_server() guard)
[ ] HUD reads via signals, no per-frame polling of Player internals
[ ] Shop disables already-purchased weapons
[ ] First Sklad playthrough income: $1500-2000 (never > $2500)
[ ] No hardcoded IP anywhere (grep project for 192.168 / 127.0.0.1)
[ ] Max live enemies <= 80 (WaveManager counter)
[ ] No HP regen code path (grep for "hp +=" outside heal())
[ ] Dialogue blocks shooting, NOT camera (PlayerInput.shooting_enabled toggled)
[ ] 3 difficulty variants reflected in WaveResource
[ ] GameManager.player_money syncs to clients via rpc
