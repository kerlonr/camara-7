extends Node
## Barramento de sinais globais. Sistemas e cenas se comunicam por aqui
## sem se referenciarem diretamente.

# --- feedback / UI
signal toast(text: String, kind: String)          # kind: info | good | warn | danger | item
signal interact_prompt_changed(text: String)      # "" = esconder
signal camera_shake(strength: float, duration: float)
signal floating_text(text: String, world_pos: Vector2, color: Color)

# --- inventário / economia / progressão
signal inventory_changed
signal hotbar_selected(index: int)
signal item_collected(item_id: String, amount: int)
signal money_changed(value: int)
signal stats_changed
signal upgrade_purchased(track_id: String, level: int)

# --- jogador
signal vitals_changed
signal exposure_changed(exposure: float, rate: float)
signal player_passed_out(reason: String)

# --- mundo
signal time_changed(day: int, minute: int)
signal day_started(day: int)
signal location_changed(location_id: String, depth: int)
signal rock_broken(ore_id: String, world_pos: Vector2)
signal depth_reached(depth: int)
signal note_found(note_id: String)
signal machine_changed(machine_id: String)
signal weather_changed(state: String)
signal flag_changed(flag: String)
signal quest_changed(quest_id: String)

# --- narrativa / acessibilidade
signal hint_shown(text: String)
signal caption(text: String)                     # legenda de som
signal banner(title: String, subtitle: String)   # letreiro grande (troca de nível etc.)

# --- sistema
signal game_saved
signal game_loaded
signal new_game_started
