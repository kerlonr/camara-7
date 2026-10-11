extends Node
## Compila todos os scripts do projeto (com autoloads ativos) e sai.
##   godot --headless --path . res://tests/check_scripts.tscn

func _ready() -> void:
	var n := 0
	for dir in ["res://autoload", "res://scripts", "res://tests"]:
		n += _scan(dir)
	print("scripts verificados: ", n)
	get_tree().quit()


func _scan(path: String) -> int:
	var n := 0
	var d := DirAccess.open(path)
	if d == null:
		return 0
	for f in d.get_files():
		if f.ends_with(".gd"):
			var s = load(path + "/" + f)
			if s == null or not s.can_instantiate():
				printerr("FALHOU: ", path + "/" + f)
			n += 1
	for sub in d.get_directories():
		n += _scan(path + "/" + sub)
	return n
