extends CanvasLayer
class_name HUDController

const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const HUD_MARGIN_MIN := 24.0
const HEALTH_BAR_VIEWPORT_RATIO := 0.2
const AMMO_PANEL_VIEWPORT_RATIO := 0.1
const KILLS_PANEL_VIEWPORT_RATIO := 0.14
const GAME_OVER_VIEWPORT_RATIO := Vector2(0.6, 0.32)
const HEALTH_LABEL_MIN_SIZE := Vector2(96.0, 42.0)
const HEALTH_BAR_MIN_SIZE := Vector2(240.0, 34.0)
const HEALTH_PANEL_MIN_HEIGHT := 54.0
const AMMO_PANEL_MIN_SIZE := Vector2(140.0, 76.0)
const KILLS_PANEL_MIN_SIZE := Vector2(160.0, 64.0)
const GAME_OVER_MENU_MIN_SIZE := Vector2(768.0, 230.0)

@onready var health_panel: HBoxContainer = $Root/HealthPanel
@onready var health_bar: ProgressBar = $Root/HealthPanel/HealthBar
@onready var health_label: Label = $Root/HealthPanel/HealthLabel
@onready var kills_panel: VBoxContainer = $Root/KillsPanel
@onready var kills_title: Label = $Root/KillsPanel/KillsTitle
@onready var kills_label: Label = $Root/KillsPanel/KillsLabel
@onready var crosshair: Control = $Root/Center/Crosshair
@onready var ammo_panel: VBoxContainer = $Root/AmmoPanel
@onready var ammo_title: Label = $Root/AmmoPanel/AmmoTitle
@onready var ammo_label: Label = $Root/AmmoPanel/AmmoLabel
@onready var reload_label: Label = $Root/AmmoPanel/ReloadLabel
@onready var damage_overlay: ColorRect = $Root/DamageOverlay
@onready var game_over_overlay: Control = $Root/GameOverOverlay
@onready var game_over_menu: PanelContainer = $Root/GameOverOverlay/GameOverMenu
@onready var game_over_title: Label = $Root/GameOverOverlay/GameOverMenu/Margin/VBox/Title
@onready var restart_button: Button = $Root/GameOverOverlay/GameOverMenu/Margin/VBox/RestartButton

var enemies_killed: int = 0
var _tracked_enemy_ids: Dictionary = {}
var _last_player_health: float = 0.0
var _has_player_health_baseline: bool = false
var _uses_player_damaged_signal: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_overlay.visible = false
	damage_overlay.modulate.a = 0.0
	_update_kills_label()
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	restart_button.pressed.connect(_on_restart_button_pressed)
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player := players[0]
		_capture_player_health_baseline(player)
		if player.has_signal("damaged"):
			player.damaged.connect(_on_player_damaged)
			_uses_player_damaged_signal = true
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("died"):
			player.died.connect(_on_player_died)

		var weapon_system := player.get_node_or_null("WeaponSystem")
		if weapon_system and weapon_system.has_signal("ammo_changed"):
			weapon_system.ammo_changed.connect(set_ammo)
		if weapon_system and weapon_system.has_signal("reloading_changed"):
			weapon_system.reloading_changed.connect(set_reloading)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		_track_enemy(enemy)


func _track_enemy(enemy: Node) -> void:
	var enemy_id := enemy.get_instance_id()
	if _tracked_enemy_ids.has(enemy_id):
		return
	if not enemy.has_signal("died"):
		return
	_tracked_enemy_ids[enemy_id] = true
	enemy.died.connect(_on_enemy_died.bind(enemy_id), CONNECT_ONE_SHOT)


func _on_player_health_changed(new_health: float) -> void:
	health_bar.value = new_health
	health_label.text = "HP %d" % int(new_health)
	if new_health < health_bar.max_value * 0.3:
		health_bar.modulate = Color.RED
	else:
		health_bar.modulate = Color.WHITE
	if not _uses_player_damaged_signal and _has_player_health_baseline and new_health < _last_player_health:
		show_damage_flash()
	_last_player_health = new_health
	_has_player_health_baseline = true


func _on_player_damaged(_amount: float = 0.0) -> void:
	show_damage_flash()


func _process(delta: float) -> void:
	if damage_overlay.modulate.a > 0.0:
		damage_overlay.modulate.a = maxf(damage_overlay.modulate.a - delta * 2.0, 0.0)


func set_health(value: float, max_value: float = 100.0) -> void:
	health_bar.max_value = max_value
	health_bar.value = value
	health_label.text = "HP %d" % int(value)
	if value < max_value * 0.3:
		health_bar.modulate = Color.RED
	else:
		health_bar.modulate = Color.WHITE
	_last_player_health = value
	_has_player_health_baseline = true


func set_ammo(current: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [current, reserve]


func set_reloading(is_reloading: bool) -> void:
	reload_label.visible = is_reloading
	if is_reloading:
		reload_label.text = "Reloading..."


func _on_enemy_died(_enemy_id: int) -> void:
	enemies_killed += 1
	_update_kills_label()


func _update_kills_label() -> void:
	kills_label.text = "%d" % enemies_killed


func _capture_player_health_baseline(player: Node) -> void:
	var player_health: Variant = player.get("health")
	if player_health != null:
		_last_player_health = float(player_health)
	else:
		_last_player_health = health_bar.value
	_has_player_health_baseline = true

	var player_max_health: Variant = player.get("max_health")
	if player_max_health != null:
		health_bar.max_value = float(player_max_health)


func _update_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var ui_scale := maxf(1.0, minf(
		viewport_size.x / BASE_VIEWPORT_SIZE.x,
		viewport_size.y / BASE_VIEWPORT_SIZE.y
	))
	var margin := maxf(HUD_MARGIN_MIN, HUD_MARGIN_MIN * ui_scale)
	var top_margin := maxf(18.0, 18.0 * ui_scale)

	_update_responsive_fonts(ui_scale)
	_update_health_layout(viewport_size, margin, ui_scale)
	_update_ammo_layout(viewport_size, margin, ui_scale)
	_update_kills_layout(viewport_size, top_margin, ui_scale)
	_update_game_over_layout(viewport_size, margin, ui_scale)


func _update_responsive_fonts(ui_scale: float) -> void:
	health_label.add_theme_font_size_override("font_size", _scaled_int(26.0, ui_scale))
	kills_title.add_theme_font_size_override("font_size", _scaled_int(16.0, ui_scale))
	kills_label.add_theme_font_size_override("font_size", _scaled_int(32.0, ui_scale))
	ammo_title.add_theme_font_size_override("font_size", _scaled_int(16.0, ui_scale))
	ammo_label.add_theme_font_size_override("font_size", _scaled_int(28.0, ui_scale))
	reload_label.add_theme_font_size_override("font_size", _scaled_int(16.0, ui_scale))
	game_over_title.add_theme_font_size_override("font_size", _scaled_int(38.0, ui_scale))
	restart_button.add_theme_font_size_override("font_size", _scaled_int(24.0, ui_scale))
	crosshair.add_theme_font_size_override("font_size", _scaled_int(24.0, ui_scale))


func _update_health_layout(viewport_size: Vector2, margin: float, ui_scale: float) -> void:
	var separation := _scaled_int(12.0, ui_scale)
	var label_size := Vector2(
		maxf(HEALTH_LABEL_MIN_SIZE.x, HEALTH_LABEL_MIN_SIZE.x * ui_scale),
		maxf(HEALTH_LABEL_MIN_SIZE.y, HEALTH_LABEL_MIN_SIZE.y * ui_scale)
	)
	var bar_size := Vector2(
		maxf(HEALTH_BAR_MIN_SIZE.x, viewport_size.x * HEALTH_BAR_VIEWPORT_RATIO),
		maxf(HEALTH_BAR_MIN_SIZE.y, HEALTH_BAR_MIN_SIZE.y * ui_scale)
	)
	var panel_size := Vector2(
		label_size.x + bar_size.x + float(separation),
		maxf(HEALTH_PANEL_MIN_HEIGHT, maxf(label_size.y, bar_size.y))
	)

	health_panel.add_theme_constant_override("separation", separation)
	health_label.custom_minimum_size = label_size
	health_bar.custom_minimum_size = bar_size
	health_panel.custom_minimum_size = panel_size
	_set_control_rect(health_panel, 0.0, 1.0, 0.0, 1.0, margin, -margin - panel_size.y, margin + panel_size.x, -margin)


func _update_ammo_layout(viewport_size: Vector2, margin: float, ui_scale: float) -> void:
	var panel_size := Vector2(
		maxf(AMMO_PANEL_MIN_SIZE.x, viewport_size.x * AMMO_PANEL_VIEWPORT_RATIO),
		maxf(AMMO_PANEL_MIN_SIZE.y, AMMO_PANEL_MIN_SIZE.y * ui_scale)
	)

	ammo_panel.add_theme_constant_override("separation", _scaled_int(2.0, ui_scale))
	ammo_panel.custom_minimum_size = panel_size
	ammo_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reload_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_rect(ammo_panel, 1.0, 1.0, 1.0, 1.0, -margin - panel_size.x, -margin - panel_size.y, -margin, -margin)


func _update_kills_layout(viewport_size: Vector2, top_margin: float, ui_scale: float) -> void:
	var panel_size := Vector2(
		maxf(KILLS_PANEL_MIN_SIZE.x, viewport_size.x * KILLS_PANEL_VIEWPORT_RATIO),
		maxf(KILLS_PANEL_MIN_SIZE.y, KILLS_PANEL_MIN_SIZE.y * ui_scale)
	)

	kills_panel.custom_minimum_size = panel_size
	kills_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kills_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_control_rect(kills_panel, 0.5, 0.0, 0.5, 0.0, -panel_size.x * 0.5, top_margin, panel_size.x * 0.5, top_margin + panel_size.y)


func _update_game_over_layout(viewport_size: Vector2, margin: float, ui_scale: float) -> void:
	var menu_size := Vector2(
		maxf(GAME_OVER_MENU_MIN_SIZE.x, viewport_size.x * GAME_OVER_VIEWPORT_RATIO.x),
		maxf(GAME_OVER_MENU_MIN_SIZE.y, viewport_size.y * GAME_OVER_VIEWPORT_RATIO.y)
	)
	menu_size.x = minf(menu_size.x, viewport_size.x - margin * 2.0)
	menu_size.y = minf(menu_size.y, viewport_size.y - margin * 2.0)

	game_over_menu.custom_minimum_size = menu_size
	restart_button.custom_minimum_size = Vector2(
		maxf(220.0, 220.0 * ui_scale),
		maxf(54.0, 54.0 * ui_scale)
	)
	_set_control_rect(game_over_menu, 0.5, 0.5, 0.5, 0.5, -menu_size.x * 0.5, -menu_size.y * 0.5, menu_size.x * 0.5, menu_size.y * 0.5)


func _set_control_rect(control: Control, anchor_left: float, anchor_top: float, anchor_right: float, anchor_bottom: float, offset_left: float, offset_top: float, offset_right: float, offset_bottom: float) -> void:
	control.anchor_left = anchor_left
	control.anchor_top = anchor_top
	control.anchor_right = anchor_right
	control.anchor_bottom = anchor_bottom
	control.offset_left = offset_left
	control.offset_top = offset_top
	control.offset_right = offset_right
	control.offset_bottom = offset_bottom


func _scaled_int(value: float, ui_scale: float) -> int:
	return int(round(value * ui_scale))


func show_damage_flash() -> void:
	damage_overlay.modulate = Color(1.0, 0.0, 0.0, 0.3)


func _on_player_died() -> void:
	game_over_overlay.visible = true
	crosshair.visible = false
	reload_label.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	restart_button.grab_focus()


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_warning("Failed to restart current scene: %s" % error)
