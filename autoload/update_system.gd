extends Node
## Atualização automática pelo GitHub Releases (data/config/update.json).
##
## Instalação = motor ("Camara 7.exe") + conteúdo ("Camara 7.pck", ao lado do exe).
## Ao abrir, o jogo consulta o último release; se houver versão nova com o mesmo motor, baixa o .pck
## para "<pck>.new", confere o SHA-256 e, ao fechar (ou em "Reiniciar e atualizar"), um ajudante em
## PowerShell espera o jogo sair, troca o arquivo e (opcionalmente) reabre o jogo.
## O save do jogador fica em %APPDATA% e não é tocado.
##
## Não faz nada no editor, em modo headless, com --no-update, no exe de testes (conteúdo embutido)
## ou se o jogador desligar em Opções. --update-url=<url> troca a origem (testes locais).

signal status_changed(state: String, text: String)

enum St { OFF, IDLE, CHECKING, UP_TO_DATE, DOWNLOADING, READY, NEEDS_INSTALLER, ERROR }

var state := St.OFF
var status_text := ""
var latest_version := ""
var release_notes := ""
var release_page := ""
var progress := 0.0

var _cfg: Dictionary = {}
var _http: HTTPRequest
var _step := ""
var _manifest: Dictionary = {}
var _pck_url := ""
var _api_override := ""
var _applied := false
var _autotest := false          # --update-autotest: escreve o resultado ao lado do exe e sai


func _ready() -> void:
	_cfg = DataManager.load_json("config/update.json")
	release_page = String(_cfg.get("releases_page", "")) % String(_cfg.get("repo", ""))
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--update-url="):
			_api_override = a.substr(13)
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--update-autotest"):
			_autotest = true
	_cleanup_leftovers()
	if not can_update():
		_set_state(St.OFF, "")
		return
	_set_state(St.IDLE, "")
	if bool(Settings.get_v("auto_update")):
		check.call_deferred()


## Caminho do .pck instalado ao lado do exe ("" se o conteúdo estiver embutido no exe).
func pck_path() -> String:
	var exe := OS.get_executable_path()
	var p := exe.get_base_dir().path_join(exe.get_file().get_basename() + ".pck")
	return p if FileAccess.file_exists(p) else ""


func can_update() -> bool:
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return false
	if "--no-update" in OS.get_cmdline_args() or "--no-update" in OS.get_cmdline_user_args():
		return false
	return pck_path() != "" and OS.get_name() == "Windows"


func current_version() -> String:
	return String(DataManager.game.get("version", "0.0.0"))


static func engine_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v.major, v.minor, v.patch]


## -1 se a < b, 0 se igual, 1 se a > b ("v0.6.2" e "0.6.10" funcionam).
static func compare(a: String, b: String) -> int:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


# ------------------------------------------------------------ verificar
func check() -> void:
	if state in [St.CHECKING, St.DOWNLOADING, St.READY]:
		return
	_set_state(St.CHECKING, "Procurando atualizações…")
	var url := _api_override if _api_override != "" else String(_cfg.get("api_latest", "")) % String(_cfg.get("repo", ""))
	_request(url, "latest")


func _request(url: String, step: String, file := "") -> void:
	if _http:
		_http.queue_free()
	_http = HTTPRequest.new()
	_http.timeout = float(_cfg.get("timeout_seconds", 20))
	_http.use_threads = true
	if file != "":
		_http.download_file = file
		_http.timeout = 0.0          # download grande: sem limite (o servidor decide)
	add_child(_http)
	_http.request_completed.connect(_on_done)
	_step = step
	var headers := ["User-Agent: Camara7/" + current_version(), "Accept: application/vnd.github+json"]
	var err := _http.request(url, headers)
	if err != OK:
		_fail("Sem conexão (%d)." % err)


func _process(_delta: float) -> void:
	if state == St.DOWNLOADING and _http:
		var total := _http.get_body_size()
		if total > 0:
			progress = clampf(float(_http.get_downloaded_bytes()) / float(total), 0.0, 1.0)
			status_text = "Baixando atualização %s… %d%%" % [latest_version, int(progress * 100.0)]


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		if _step == "latest" and code == 404:
			_set_state(St.UP_TO_DATE, "Nenhuma versão publicada ainda.")
			return
		_fail("Não foi possível verificar (%s)." % ("HTTP %d" % code if code > 0 else "sem internet"))
		return
	match _step:
		"latest":
			_on_latest(body)
		"manifest":
			_on_manifest(body)
		"pck":
			_on_pck()


func _on_latest(body: PackedByteArray) -> void:
	var rel = JSON.parse_string(body.get_string_from_utf8())
	if not rel is Dictionary:
		_fail("Resposta inválida do servidor.")
		return
	latest_version = String(rel.get("tag_name", "")).trim_prefix("v")
	release_notes = String(rel.get("body", ""))
	if rel.has("html_url"):
		release_page = String(rel.html_url)
	if latest_version == "" or compare(latest_version, current_version()) <= 0:
		_set_state(St.UP_TO_DATE, "Jogo atualizado (v%s)." % current_version())
		return
	var manifest_url := ""
	for a in rel.get("assets", []):
		if a.get("name", "") == _cfg.get("manifest_asset", "update.json"):
			manifest_url = String(a.browser_download_url)
		elif a.get("name", "") == _cfg.get("pck_asset", "Camara7.pck"):
			_pck_url = String(a.browser_download_url)
	if manifest_url == "" or _pck_url == "":
		_set_state(St.NEEDS_INSTALLER, "Versão %s disponível — baixe o instalador novo." % latest_version)
		return
	_request(manifest_url, "manifest")


func _on_manifest(body: PackedByteArray) -> void:
	var m = JSON.parse_string(body.get_string_from_utf8())
	if not m is Dictionary or not m.has("pck_sha256"):
		_fail("Manifesto de atualização inválido.")
		return
	_manifest = m
	if String(m.get("engine", "")) != engine_version():
		_set_state(St.NEEDS_INSTALLER, "Versão %s precisa do instalador novo (motor %s)." % [latest_version, m.get("engine", "?")])
		return
	if _ready_file_matches():
		_set_state(St.READY, "Atualização %s pronta. Reinicie para aplicar." % latest_version)
		return
	progress = 0.0
	_set_state(St.DOWNLOADING, "Baixando atualização %s…" % latest_version)
	_request(_pck_url, "pck", _download_path())


func _on_pck() -> void:
	var dl := _download_path()
	var sha := FileAccess.get_sha256(dl)
	if sha != String(_manifest.get("pck_sha256", "")).to_lower():
		DirAccess.remove_absolute(dl)
		_fail("Download corrompido — tento de novo na próxima vez.")
		return
	var ready := _ready_path()
	if FileAccess.file_exists(ready):
		DirAccess.remove_absolute(ready)
	if DirAccess.rename_absolute(dl, ready) != OK:
		_fail("Não consegui salvar a atualização.")
		return
	_set_state(St.READY, "Atualização %s pronta. Reinicie para aplicar." % latest_version)
	EventBus.toast.emit("Atualização %s baixada. Ela entra quando você fechar o jogo." % latest_version, "good")


func _ready_file_matches() -> bool:
	var ready := _ready_path()
	return FileAccess.file_exists(ready) and FileAccess.get_sha256(ready) == String(_manifest.get("pck_sha256", "")).to_lower()


func _download_path() -> String:
	return pck_path() + ".download"


func _ready_path() -> String:
	return pck_path() + ".new"


func _cleanup_leftovers() -> void:
	var p := pck_path()
	if p == "":
		return
	for suffix in [".download", ".old"]:
		if FileAccess.file_exists(p + suffix):
			DirAccess.remove_absolute(p + suffix)


func _fail(msg: String) -> void:
	_set_state(St.ERROR, msg)
	push_warning("[UpdateSystem] " + msg)


func _set_state(s: int, text: String) -> void:
	state = s
	status_text = text
	status_changed.emit(St.keys()[s], text)
	if _autotest and s in [St.READY, St.UP_TO_DATE, St.NEEDS_INSTALLER, St.ERROR]:
		var f := FileAccess.open(OS.get_executable_path().get_base_dir().path_join("update_autotest.txt"), FileAccess.READ_WRITE if FileAccess.file_exists(OS.get_executable_path().get_base_dir().path_join("update_autotest.txt")) else FileAccess.WRITE)
		if f:
			f.seek_end()
			f.store_line("%s v%s %s | %s" % [Time.get_datetime_string_from_system(), current_version(), St.keys()[s], text])
			f.close()
		if s == St.READY and "--update-autotest=close" in OS.get_cmdline_args() + OS.get_cmdline_user_args():
			get_tree().quit.call_deferred()      # simula o jogador fechando o jogo
		elif s == St.READY:
			apply_and_restart.call_deferred()
		else:
			get_tree().quit.call_deferred()


# ------------------------------------------------------------ aplicar
## Fecha o jogo, troca o .pck e reabre já atualizado.
func apply_and_restart() -> void:
	if state != St.READY:
		return
	_spawn_helper(true)
	get_tree().quit()


## Ao fechar o jogo com atualização baixada, aplica sem reabrir.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if state == St.READY and not _applied:
			_spawn_helper(false)


func _exit_tree() -> void:
	if state == St.READY and not _applied:
		_spawn_helper(false)


func _spawn_helper(relaunch: bool) -> void:
	_applied = true
	var pck := pck_path()
	var exe := OS.get_executable_path()
	var script := OS.get_user_data_dir().path_join("apply_update.ps1")
	var ps := """param([int]$GamePid, [string]$Pck, [string]$New, [string]$Exe, [int]$Relaunch, [string]$GameArgs = "")
try { Wait-Process -Id $GamePid -Timeout 60 -ErrorAction SilentlyContinue } catch {}
for ($i = 0; $i -lt 40; $i++) {
  try {
    if (Test-Path -LiteralPath ($Pck + '.old')) { Remove-Item -LiteralPath ($Pck + '.old') -Force }
    Move-Item -LiteralPath $Pck -Destination ($Pck + '.old') -Force -ErrorAction Stop
    Move-Item -LiteralPath $New -Destination $Pck -Force -ErrorAction Stop
    Remove-Item -LiteralPath ($Pck + '.old') -Force -ErrorAction SilentlyContinue
    break
  } catch {
    if ((-not (Test-Path -LiteralPath $Pck)) -and (Test-Path -LiteralPath ($Pck + '.old'))) { Move-Item -LiteralPath ($Pck + '.old') -Destination $Pck -Force }
    Start-Sleep -Milliseconds 250
  }
}
if ($Relaunch -eq 1) {
  if ($GameArgs -ne '') { Start-Process -FilePath $Exe -WorkingDirectory (Split-Path -Parent $Exe) -ArgumentList $GameArgs }
  else { Start-Process -FilePath $Exe -WorkingDirectory (Split-Path -Parent $Exe) }
}
"""
	var f := FileAccess.open(script, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(ps)
	f.close()
	var args := ["-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", script,
		"-GamePid", str(OS.get_process_id()), "-Pck", pck, "-New", _ready_path(), "-Exe", exe, "-Relaunch", "1" if relaunch else "0"]
	var fwd := []          # só os argumentos de teste são repassados ao jogo reaberto
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--update-url=") or a == "--update-autotest":
			fwd.append(a)
	if not fwd.is_empty():
		args += ["-GameArgs", " ".join(fwd)]
	OS.create_process("powershell.exe", args)


func open_release_page() -> void:
	if release_page != "":
		OS.shell_open(release_page)
