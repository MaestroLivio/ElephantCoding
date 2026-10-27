class_name CodingSimulator
extends RefCounted

## Deterministic, headless simulation core.
## The 3D renderer only projects this state: it never decides success.

const DIRS = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const DIR_NAMES = ["N", "E", "S", "W"]
const MAX_BUDGET = 30000
const MAX_LOOP = 2000
const MAX_DEPTH = 24
const MAX_TICKS = 5000

var mission: Dictionary = {}
const ParserClass = preload("res://scripts/core/dsl_parser.gd")
var parser = ParserClass.new()

var pos = Vector2i.ZERO
var heading = 1
var vars: Dictionary = {}
var sensor_values: Dictionary = {}
var entities: Array = []
var obstacles: Dictionary = {}
var collected: Array = []
var activated: Array = []
var photos: Array = []
var trace: Array = []
var visited: Array = []
var events: Array = []
var inventory: Dictionary = {}
var ticks = 0
var steps = 0
var error_message = ""
var parse_error: Dictionary = {}
var success = false
var checks: Dictionary = {}
var failed_check = ""
var failure_reason = ""

var _budget = MAX_BUDGET
var _depth = 0
var _procs: Dictionary = {}
var _funcs: Dictionary = {}
var _timers: Array = []
var _timer_counts: Dictionary = {}


func setup(p_mission: Dictionary) -> void:
	mission = p_mission
	pos = Vector2i(int(mission.get("spawn", {}).get("cell", [0, 0])[0]), int(mission.get("spawn", {}).get("cell", [0, 0])[1]))
	heading = DIR_NAMES.find(mission.get("spawn", {}).get("heading", "E"))
	if heading < 0:
		heading = 1
	vars = mission.get("initial_vars", {}).duplicate(true)
	sensor_values = mission.get("sensors", {}).duplicate(true)
	for k in sensor_values:
		vars[k] = sensor_values[k]
	entities = mission.get("entities", []).duplicate(true)
	obstacles.clear()
	for c in mission.get("obstacles", []):
		obstacles[Vector2i(int(c[0]), int(c[1]))] = true
	collected = []
	activated = []
	photos = []
	trace = [[pos.x, pos.y]]
	visited = [pos]
	events = []
	inventory = {}
	ticks = 0
	steps = 0
	error_message = ""
	parse_error = {}
	success = false
	checks = {}
	failed_check = ""
	failure_reason = ""
	_budget = MAX_BUDGET
	_depth = 0
	_eval_failed = false
	_procs = {}
	_funcs = {}
	_timers = mission.get("timers", []).duplicate(true)
	_timer_counts = {}
	_emit({"kind": "start", "pos": [pos.x, pos.y], "heading": heading})


func run(source: String) -> Dictionary:
	if mission.is_empty():
		return {"ok": false, "success": false, "error": "Nessuna missione caricata."}
	_eval_failed = false
	var parsed: Dictionary = parser.parse(source)
	if not parsed.ok:
		parse_error = parsed.error
		error_message = "Riga %d, colonna %d: %s" % [parsed.error.get("line", 0), parsed.error.get("column", 0), parsed.error.get("message", "Errore di sintassi.")]
		failure_reason = error_message
		_emit({"kind": "error", "message": error_message})
		return _result(false)
	for d in parsed.definitions:
		if d.kind == "procedura":
			_procs[d.name] = d
		else:
			_funcs[d.name] = d
	var flow: Dictionary = _exec_block(parsed.program, {}, 0)
	if flow.get("error", false):
		return _result(false)
	if error_message != "":
		return _result(false)
	_evaluate_goal()
	return _result(success)


func _result(ok: bool) -> Dictionary:
	return {
		"ok": ok,
		"success": success,
		"error": error_message,
		"parse_error": parse_error,
		"failure_reason": failure_reason,
		"checks": checks,
		"failed_check": failed_check,
		"events": events,
		"state": snapshot(),
		"steps": steps,
		"ticks": ticks,
	}


func snapshot() -> Dictionary:
	return {
		"pos": [pos.x, pos.y],
		"heading": heading,
		"heading_name": DIR_NAMES[heading],
		"vars": vars.duplicate(true),
		"collected": collected.duplicate(),
		"activated": activated.duplicate(),
		"photos": photos.duplicate(),
		"inventory": inventory.duplicate(true),
		"trace": trace.duplicate(),
		"visited": visited.duplicate(),
		"ticks": ticks,
		"steps": steps,
	}


func _emit(ev: Dictionary) -> void:
	ev["pos"] = [pos.x, pos.y]
	ev["heading"] = heading
	ev["tick"] = ticks
	events.append(ev)


func _fail(message: String) -> void:
	error_message = message
	failure_reason = message
	_emit({"kind": "error", "message": message})


# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------
func _exec_block(block: Array, scope: Dictionary, depth: int) -> Dictionary:
	if depth > MAX_DEPTH:
		_fail("Troppi annidamenti: semplifica il programma.")
		return {"error": true}
	for stmt in block:
		var flow: Dictionary = _exec(stmt, scope, depth)
		if flow.get("error", false) or flow.get("returned", false):
			return flow
		if error_message != "":
			return {"error": true}
	return {}


func _exec(stmt: Dictionary, scope: Dictionary, depth: int) -> Dictionary:
	_budget -= 1
	steps += 1
	if _budget <= 0:
		_fail("Il programma è troppo lungo o c'è un ciclo che non termina. Controlla il limite delle ripetizioni.")
		return {"error": true}
	var rep = int(stmt.get("repeat", 1))
	for _r in range(max(1, rep)):
		if error_message != "":
			return {"error": true}
		var res: Dictionary = _exec_once(stmt, scope, depth)
		if res.get("error", false) or res.get("returned", false):
			return res
	return {}


func _exec_once(stmt: Dictionary, scope: Dictionary, depth: int) -> Dictionary:
	match stmt.type:
		"forward":
			var n = 1
			if stmt.steps != null:
				n = int(_eval(stmt.steps, scope, depth))
			if not _move_forward(n):
				return {"error": true}
		"turn":
			heading = (heading + int(stmt.dir) + 4) % 4
			_emit({"kind": "turn", "dir": stmt.dir, "heading": heading})
		"go_to":
			var target = _resolve_point(stmt.args, scope, depth)
			if target == null:
				return {"error": true}
			if not _go_to(target):
				return {"error": true}
		"move_axis":
			var amount = int(_eval(stmt.value, scope, depth))
			if not _move_axis(stmt.axis, amount):
				return {"error": true}
		"trace":
			var target2 = _resolve_point(stmt.args, scope, depth)
			if target2 == null:
				return {"error": true}
			if not _go_to(target2):
				return {"error": true}
			_emit({"kind": "trace", "cell": [target2.x, target2.y]})
		"action":
			return _do_action(stmt.action, stmt.target, scope, depth)
		"amount_action":
			return _do_amount_action(stmt.action, stmt.amount, scope, depth)
		"assign":
			var value = _eval(stmt.value, scope, depth)
			if _eval_failed:
				return {"error": true}
			vars[stmt.name] = value
			if scope.has(stmt.name):
				scope[stmt.name] = value
			_emit({"kind": "variable_change", "name": stmt.name, "value": value})
		"if":
			var cond = _truthy(_eval(stmt.cond, scope, depth))
			if _eval_failed:
				return {"error": true}
			if cond:
				return _exec_block(stmt.then, scope, depth + 1)
			elif not stmt.else.is_empty():
				return _exec_block(stmt.else, scope, depth + 1)
		"repeat":
			var count = int(_eval(stmt.count, scope, depth))
			if _eval_failed:
				return {"error": true}
			if count < 0:
				_fail("Le ripetizioni non possono essere negative.")
				return {"error": true}
			if count > MAX_LOOP:
				_fail("RIPETI supera il limite di %d ripetizioni." % MAX_LOOP)
				return {"error": true}
			for i in range(count):
				var r: Dictionary = _exec_block(stmt.body, scope, depth + 1)
				if r.get("error", false) or r.get("returned", false):
					return r
				if i > MAX_LOOP:
					break
		"while":
			var iterations = 0
			while _truthy(_eval(stmt.cond, scope, depth)):
				if _eval_failed:
					return {"error": true}
				iterations += 1
				if iterations > MAX_LOOP:
					_fail("Il ciclo FINCHÉ non termina: dopo %d giri la condizione è ancora vera." % MAX_LOOP)
					return {"error": true}
				var wr: Dictionary = _exec_block(stmt.body, scope, depth + 1)
				if wr.get("error", false) or wr.get("returned", false):
					return wr
		"for_range":
			var a = int(_eval(stmt.start, scope, depth))
			var b = int(_eval(stmt.stop, scope, depth))
			if _eval_failed:
				return {"error": true}
			var step = 1 if b >= a else -1
			var i2 = a
			var guard = 0
			while (step > 0 and i2 <= b) or (step < 0 and i2 >= b):
				scope[stmt.var] = i2
				var fr: Dictionary = _exec_block(stmt.body, scope, depth + 1)
				if fr.get("error", false) or fr.get("returned", false):
					return fr
				i2 += step
				guard += 1
				if guard > MAX_LOOP:
					_fail("Il ciclo PER è troppo lungo.")
					return {"error": true}
		"for_each":
			var it = _eval(stmt.iterable, scope, depth)
			if _eval_failed:
				return {"error": true}
			if not (it is Array) and not (it is PackedStringArray):
				_fail("PER OGNI richiede una lista, ma hai dato: %s." % _describe(it))
				return {"error": true}
			var guard2 = 0
			for item in it:
				scope[stmt.var] = item
				var er: Dictionary = _exec_block(stmt.body, scope, depth + 1)
				if er.get("error", false) or er.get("returned", false):
					return er
				guard2 += 1
				if guard2 > MAX_LOOP:
					_fail("La lista è troppo lunga per questo esercizio.")
					return {"error": true}
		"call":
			return _call_procedure(stmt.name, stmt.args, scope, depth)
		"return":
			var rv = null
			if stmt.value != null:
				rv = _eval(stmt.value, scope, depth)
				if _eval_failed:
					return {"error": true}
			return {"returned": true, "value": rv}
		_:
			_fail("Comando non supportato: %s." % str(stmt.get("type", "?")))
			return {"error": true}
	return {}


func _call_procedure(name: String, arg_nodes: Array, scope: Dictionary, depth: int) -> Dictionary:
	if not _procs.has(name):
		# Statement call to a builtin or a user function: evaluate it for its side effect.
		var call_node := {"type": "call_expr", "name": name, "args": arg_nodes, "token": {}}
		_call_function(call_node, scope, depth)
		if _eval_failed:
			return {"error": true}
		return {}
	var proc: Dictionary = _procs[name]
	var args: Array = []
	for a in arg_nodes:
		args.append(_eval(a, scope, depth))
		if _eval_failed:
			return {"error": true}
	if args.size() != proc.params.size():
		_fail("La procedura «%s» vuole %d valori, ne hai passati %d." % [name, proc.params.size(), args.size()])
		return {"error": true}
	var local = scope.duplicate()
	for i in range(proc.params.size()):
		local[proc.params[i]] = args[i]
	return _exec_block(proc.body, local, depth + 1)


# ---------------------------------------------------------------------------
# Movement and actions
# ---------------------------------------------------------------------------
func _in_bounds(cell: Vector2i) -> bool:
	var g: Dictionary = mission.get("grid", {})
	return cell.x >= int(g.get("min_x", 0)) and cell.x <= int(g.get("max_x", 9)) \
		and cell.y >= int(g.get("min_y", 0)) and cell.y <= int(g.get("max_y", 7))


func _move_forward(n: int) -> bool:
	if n < 0:
		_fail("AVANTI richiede un numero di passi non negativo. Hai scritto %d." % n)
		return false
	for _i in range(n):
		var nxt = pos + DIRS[heading]
		if not _in_bounds(nxt):
			_fail("Nilo uscirebbe dal campo: la casella %s è fuori dalla mappa. Fermati prima del bordo." % _cell_text(nxt))
			return false
		if obstacles.has(nxt):
			_fail("Nilo ha incontrato un ostacolo in %s. Fermati prima della collisione." % _cell_text(nxt))
			return false
		pos = nxt
		_after_move()
	return true


func _move_axis(axis: String, amount: int) -> bool:
	var d = Vector2i(1, 0) if axis == "x" else Vector2i(0, 1)
	var step = 1 if amount >= 0 else -1
	for _i in range(abs(amount)):
		var nxt = pos + d * step
		if not _in_bounds(nxt):
			_fail("Lo spostamento esce dal rettangolo del campo in %s." % _cell_text(nxt))
			return false
		if obstacles.has(nxt):
			_fail("C'è un ostacolo in %s: scegli un percorso con waypoint." % _cell_text(nxt))
			return false
		pos = nxt
		_after_move()
	return true


func _go_to(target: Vector2i) -> bool:
	if not _in_bounds(target):
		_fail("La destinazione %s è fuori dal campo." % _cell_text(target))
		return false
	if obstacles.has(target):
		_fail("La destinazione %s è occupata da un ostacolo." % _cell_text(target))
		return false
	# Orthogonal path: X first, then Y (documented behaviour).
	while pos.x != target.x:
		var step_x = 1 if target.x > pos.x else -1
		var nxt = Vector2i(pos.x + step_x, pos.y)
		if not _in_bounds(nxt) or obstacles.has(nxt):
			_fail("Percorso bloccato in %s: aggiungi un waypoint." % _cell_text(nxt))
			return false
		pos = nxt
		_after_move()
	while pos.y != target.y:
		var step_y = 1 if target.y > pos.y else -1
		var nxt2 = Vector2i(pos.x, pos.y + step_y)
		if not _in_bounds(nxt2) or obstacles.has(nxt2):
			_fail("Percorso bloccato in %s: aggiungi un waypoint." % _cell_text(nxt2))
			return false
		pos = nxt2
		_after_move()
	return true


func _after_move() -> void:
	visited.append(pos)
	trace.append([pos.x, pos.y])
	_emit({"kind": "step", "cell": [pos.x, pos.y]})


func _resolve_point(args: Dictionary, scope: Dictionary, depth: int):
	if args.kind == "pair":
		var xa = _eval(args.a, scope, depth)
		var ya = _eval(args.b, scope, depth)
		if _eval_failed:
			return null
		return Vector2i(int(xa), int(ya))
	var v = _eval(args.a, scope, depth)
	if _eval_failed:
		return null
	if v is Vector2i:
		return v
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	if v is Dictionary and v.has("x") and v.has("y"):
		return Vector2i(int(v.x), int(v.y))
	_fail("Atteso un punto (x,y), trovato: %s." % _describe(v))
	return null


func _do_action(action: String, target, scope: Dictionary, depth: int) -> Dictionary:
	var cell = pos
	if target != null:
		var t = _resolve_point(target, scope, depth)
		if _eval_failed:
			return {"error": true}
		if t != null:
			cell = t
	match action:
		"RACCOGLI", "PRENDI":
			var e = _entity_at(cell, ["collect"])
			if e.is_empty():
				_emit({"kind": "no_effect", "action": action, "cell": [cell.x, cell.y], "message": "Qui non c'è nulla da raccogliere."})
				return {}
			_collect(e)
		"TOCCA", "ATTIVA", "APRI", "ACCENDI", "SUONA":
			var e2 = _entity_at(cell, ["activate", "target"])
			if e2.is_empty():
				_emit({"kind": "no_effect", "action": action, "cell": [cell.x, cell.y], "message": "Qui non c'è un meccanismo da attivare."})
				return {}
			_activate(e2, action)
		"FOTO", "SCANSIONA":
			var e3 = _entity_at(cell, ["photo"])
			if e3.is_empty():
				_emit({"kind": "no_effect", "action": action, "cell": [cell.x, cell.y], "message": "Qui non c'è un reperto da fotografare."})
				return {}
			if not photos.has(e3.id):
				photos.append(e3.id)
				_emit({"kind": action.to_lower(), "entity": e3.id, "label": e3.label, "cell": [cell.x, cell.y]})
			else:
				_emit({"kind": "no_effect", "action": action, "message": "Questo reperto è già stato registrato."})
		"DEPOSITA":
			if inventory.is_empty():
				_fail("DEPOSITA richiede un oggetto raccolto prima. Non hai nulla nello zaino.")
				return {"error": true}
			var e4 = _entity_at(cell, ["target", "activate"])
			if e4.is_empty():
				_emit({"kind": "no_effect", "action": action, "cell": [cell.x, cell.y], "message": "Qui non c'è un deposito."})
				return {}
			inventory.clear()
			_activate(e4, action)
		"LASCIA":
			var e5 = _entity_at(cell, ["target", "activate"])
			if not e5.is_empty():
				_activate(e5, action)
			else:
				_emit({"kind": "lascia", "cell": [cell.x, cell.y]})
		"SALUTA", "PAUSA":
			_emit({"kind": action.to_lower(), "cell": [cell.x, cell.y]})
		"ATTRAVERSA":
			_emit({"kind": "attraversa", "cell": [cell.x, cell.y]})
		"RICARICA":
			vars["batteria"] = 100
			vars["ricarica"] = true
			_emit({"kind": "ricarica", "value": 100})
		"SEGNALA":
			_emit({"kind": "segnala", "cell": [cell.x, cell.y]})
		"CHIUDI":
			return _close_trace()
		_:
			_emit({"kind": "no_effect", "action": action})
	return {}


func _do_amount_action(action: String, amount_node, scope: Dictionary, depth: int) -> Dictionary:
	var amount = 1
	if amount_node != null:
		amount = int(_eval(amount_node, scope, depth))
		if _eval_failed:
			return {"error": true}
	match action:
		"VERSA":
			if amount < 0:
				_fail("VERSA richiede una quantità non negativa.")
				return {"error": true}
			vars["acqua"] = int(vars.get("acqua", 0)) + amount
			_emit({"kind": "versa", "amount": amount, "value": vars["acqua"]})
		"ASPETTA":
			if amount < 0:
				_fail("ASPETTA richiede un numero di tick non negativo.")
				return {"error": true}
			for _t in range(amount):
				ticks += 1
				_apply_timers()
				if ticks > MAX_TICKS:
					_fail("Troppi tick: il programma aspetta troppo a lungo.")
					return {"error": true}
			_emit({"kind": "aspetta", "amount": amount, "tick": ticks})
		"SU":
			_emit({"kind": "su", "amount": amount})
		_:
			_emit({"kind": action.to_lower(), "amount": amount})
	return {}


func _close_trace() -> Dictionary:
	if trace.size() < 3:
		_fail("Non c'è abbastanza traccia da chiudere: disegna almeno tre punti.")
		return {"error": true}
	var first = Vector2i(int(trace[0][0]), int(trace[0][1]))
	if first != pos:
		if not _go_to(first):
			return {"error": true}
	_emit({"kind": "chiudi", "cell": [pos.x, pos.y]})
	return {}


func _collect(e: Dictionary) -> void:
	if collected.has(e.id):
		_emit({"kind": "no_effect", "action": "RACCOGLI", "message": "Oggetto già raccolto."})
		return
	collected.append(e.id)
	inventory[e.id] = e.get("label", "Oggetto")
	_emit({"kind": "raccogli", "entity": e.id, "label": e.get("label", "Oggetto"), "cell": [pos.x, pos.y]})


func _activate(e: Dictionary, action: String) -> void:
	if activated.has(e.id):
		_emit({"kind": "no_effect", "action": action, "message": "Meccanismo già attivato."})
		return
	activated.append(e.id)
	_emit({"kind": action.to_lower(), "entity": e.id, "label": e.get("label", "Meccanismo"), "cell": [pos.x, pos.y]})


func _entity_at(cell: Vector2i, kinds: Array) -> Dictionary:
	for e in entities:
		var ec = e.get("cell", [0, 0])
		if int(ec[0]) == cell.x and int(ec[1]) == cell.y and kinds.has(e.get("kind", "")):
			return e
	return {}


func _apply_timers() -> void:
	for t in _timers:
		var every = int(t.get("every", 1))
		if every <= 0:
			every = 1
		if ticks % every == 0:
			var name: String = t.get("var", "")
			if name == "":
				continue
			if t.get("mode", "toggle") == "toggle":
				vars[name] = not bool(vars.get(name, false))
			else:
				vars[name] = int(vars.get(name, 0)) + int(t.get("amount", 1))


# ---------------------------------------------------------------------------
# Expressions
# ---------------------------------------------------------------------------
var _eval_failed = false


func _eval(node, scope: Dictionary, depth: int):
	if node == null:
		return null
	if _eval_failed:
		return null
	match node.type:
		"literal":
			return node.value
		"variable":
			var n: String = node.name
			if scope.has(n):
				return scope[n]
			if vars.has(n):
				return vars[n]
			_eval_failed = true
			_fail("La variabile «%s» non esiste ancora. Assegna un valore con IMPOSTA." % n)
			return null
		"list":
			var arr: Array = []
			for it in node.items:
				arr.append(_eval(it, scope, depth))
				if _eval_failed:
					return null
			return arr
		"unary":
			var v = _eval(node.value, scope, depth)
			if _eval_failed:
				return null
			if node.op == "-":
				return -_num(v)
			if node.op == "not":
				return not _truthy(v)
			return v
		"binary":
			return _binary(node, scope, depth)
		"index":
			var target = _eval(node.target, scope, depth)
			var idx = _eval(node.index, scope, depth)
			if _eval_failed:
				return null
			if target is Array or target is String:
				var i = int(idx)
				if i < 0:
					i += target.size()
				if i < 0 or i >= target.size():
					_eval_failed = true
					_fail("Indice %s fuori intervallo: la lista ha %d elementi." % [str(idx), target.size()])
					return null
				return target[i]
			if target is Dictionary:
				return target.get(str(idx), null)
			_eval_failed = true
			_fail("Non posso usare le parentesi quadre su %s." % _describe(target))
			return null
		"property":
			var target2 = _eval(node.target, scope, depth)
			if _eval_failed:
				return null
			if target2 is Dictionary:
				return target2.get(node.name, null)
			if target2 is Array and target2.size() >= 2:
				if node.name == "x":
					return target2[0]
				if node.name == "y":
					return target2[1]
			_eval_failed = true
			_fail("La proprietà «%s» non esiste su %s." % [node.name, _describe(target2)])
			return null
		"call_expr":
			return _call_function(node, scope, depth)
		_:
			_eval_failed = true
			_fail("Espressione non supportata: %s." % str(node.get("type", "?")))
			return null


func _binary(node: Dictionary, scope: Dictionary, depth: int):
	var a = _eval(node.left, scope, depth)
	if _eval_failed:
		return null
	var op: String = node.op
	if op == "and":
		if not _truthy(a):
			return false
		return _truthy(_eval(node.right, scope, depth))
	if op == "or":
		if _truthy(a):
			return true
		return _truthy(_eval(node.right, scope, depth))
	var b = _eval(node.right, scope, depth)
	if _eval_failed:
		return null
	match op:
		"+":
			return a + b
		"-":
			return _num(a) - _num(b)
		"*":
			return _num(a) * _num(b)
		"/":
			var d = _num(b)
			if abs(d) < 0.0000001:
				_eval_failed = true
				_fail("Divisione per zero: controlla il denominatore.")
				return null
			return float(_num(a)) / float(d)
		"%":
			var d2 = int(b)
			if d2 == 0:
				_eval_failed = true
				_fail("Modulo per zero: controlla il divisore.")
				return null
			return int(a) % d2
		"==":
			return _values_equal(a, b)
		"!=":
			return not _values_equal(a, b)
		"<":
			return _num(a) < _num(b)
		"<=":
			return _num(a) <= _num(b)
		">":
			return _num(a) > _num(b)
		">=":
			return _num(a) >= _num(b)
	_eval_failed = true
	_fail("Operatore sconosciuto: %s." % op)
	return null


func _call_function(node: Dictionary, scope: Dictionary, depth: int):
	var name: String = node.name
	var args: Array = []
	for a in node.args:
		args.append(_eval(a, scope, depth))
		if _eval_failed:
			return null
	if _funcs.has(name):
		var fn: Dictionary = _funcs[name]
		if args.size() != fn.params.size():
			_eval_failed = true
			_fail("La funzione «%s» vuole %d valori, ne hai passati %d." % [name, fn.params.size(), args.size()])
			return null
		var local = scope.duplicate()
		for i in range(fn.params.size()):
			local[fn.params[i]] = args[i]
		var flow: Dictionary = _exec_block(fn.body, local, depth + 1)
		if flow.get("error", false):
			_eval_failed = true
			return null
		return flow.get("value", null)
	match name:
		"lunghezza":
			if args.size() != 1:
				return _builtin_error("LUNGHEZZA vuole un solo valore.")
			if not (args[0] is Array or args[0] is String):
				return _builtin_error("LUNGHEZZA funziona su liste e testi.")
			return args[0].size()
		"ass", "abs":
			if args.size() != 1:
				return _builtin_error("ASS vuole un solo numero.")
			return abs(_num(args[0]))
		"min":
			if args.is_empty():
				return _builtin_error("MIN vuole almeno un numero.")
			var m = _num(args[0])
			for v in args:
				m = min(m, _num(v))
			return m
		"max":
			if args.is_empty():
				return _builtin_error("MAX vuole almeno un numero.")
			var m2 = _num(args[0])
			for v2 in args:
				m2 = max(m2, _num(v2))
			return m2
		"aggiungi":
			if args.size() != 2 or not (args[0] is Array):
				return _builtin_error("AGGIUNGI(lista, valore) vuole una lista e un valore.")
			args[0].append(args[1])
			return args[0]
		"estrai":
			if args.size() != 1 or not (args[0] is Array):
				return _builtin_error("ESTRAI(lista) vuole una lista.")
			if args[0].is_empty():
				return _builtin_error("ESTRAI non può svuotare una lista già vuota.")
			return args[0].pop_front()
		"contiene":
			if args.size() != 2:
				return _builtin_error("CONTIENE(lista, valore) vuole due valori.")
			if args[0] is Array:
				return args[0].has(args[1])
			if args[0] is String:
				return args[0].contains(str(args[1]))
			return false
		"vuota":
			if args.size() != 1:
				return _builtin_error("VUOTA(lista) vuole un valore.")
			if args[0] is Array or args[0] is String:
				return args[0].is_empty()
			return false
		"arrotonda":
			if args.size() != 1:
				return _builtin_error("ARROTONDA vuole un numero.")
			return round(_num(args[0]))
		"scambia":
			if args.size() != 3 or not (args[0] is Array):
				return _builtin_error("SCAMBIA(lista, i, j) vuole una lista e due indici.")
			var arr2: Array = args[0]
			var i1 = int(args[1])
			var j1 = int(args[2])
			if i1 < 0 or j1 < 0 or i1 >= arr2.size() or j1 >= arr2.size():
				return _builtin_error("SCAMBIA: indice fuori intervallo.")
			var tmp = arr2[i1]
			arr2[i1] = arr2[j1]
			arr2[j1] = tmp
			return arr2
	_eval_failed = true
	_fail("Funzione sconosciuta: «%s»." % name)
	return null


func _builtin_error(message: String):
	_eval_failed = true
	_fail(message)
	return null


func _num(v) -> float:
	if v is bool:
		return 1.0 if v else 0.0
	if v is int or v is float:
		return float(v)
	_fail("Atteso un numero, trovato: %s." % _describe(v))
	return 0.0


func _truthy(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v != ""
	if v is Array:
		return not v.is_empty()
	return true


func _describe(v) -> String:
	if v == null:
		return "NULLO"
	if v is bool:
		return "VERO" if v else "FALSO"
	if v is float:
		return str(v)
	if v is Array:
		return "lista"
	if v is Dictionary:
		return "dizionario"
	return "«%s»" % str(v)


func _cell_text(c: Vector2i) -> String:
	return "(%d,%d)" % [c.x, c.y]


# ---------------------------------------------------------------------------
# Goal evaluation
# ---------------------------------------------------------------------------
func _evaluate_goal() -> void:
	var goal: Dictionary = mission.get("goal", {})
	checks.clear()
	failed_check = ""
	success = true
	if goal.has("reach"):
		var r = Vector2i(int(goal.reach[0]), int(goal.reach[1]))
		var ok = pos == r
		checks["reach"] = ok
		if not ok:
			success = false
			failed_check = "reach"
			if failure_reason == "":
				failure_reason = "Nilo è in %s, ma la meta è %s." % [_cell_text(pos), _cell_text(r)]
	if goal.has("collect_all"):
		var missing: Array = []
		for id in goal.collect_all:
			if not collected.has(id):
				missing.append(_entity_label(id))
		checks["collect_all"] = missing.is_empty()
		if not missing.is_empty():
			success = false
			if failed_check == "":
				failed_check = "collect_all"
				failure_reason = "Mancano ancora: %s." % ", ".join(missing)
	if goal.has("activate_all"):
		var missing2: Array = []
		for id in goal.activate_all:
			if not activated.has(id):
				missing2.append(_entity_label(id))
		checks["activate_all"] = missing2.is_empty()
		if not missing2.is_empty():
			success = false
			if failed_check == "":
				failed_check = "activate_all"
				failure_reason = "Meccanismi non attivati: %s." % ", ".join(missing2)
	if goal.has("photo_all"):
		var missing3: Array = []
		for id in goal.photo_all:
			if not photos.has(id):
				missing3.append(_entity_label(id))
		checks["photo_all"] = missing3.is_empty()
		if not missing3.is_empty():
			success = false
			if failed_check == "":
				failed_check = "photo_all"
				failure_reason = "Reperti non registrati: %s." % ", ".join(missing3)
	if goal.has("visit_order"):
		var order_ok = _order_present(goal.visit_order)
		checks["visit_order"] = order_ok
		if not order_ok:
			success = false
			if failed_check == "":
				failed_check = "visit_order"
				failure_reason = "Le tappe non sono state visitate nell'ordine richiesto."
	if goal.get("trace_closed", false):
		var closed = trace.size() >= 3 and int(trace[0][0]) == pos.x and int(trace[0][1]) == pos.y
		checks["trace_closed"] = closed
		if not closed:
			success = false
			if failed_check == "":
				failed_check = "trace_closed"
				failure_reason = "La traccia non è chiusa: torna al primo punto del disegno."
	if goal.has("vars"):
		for k in goal.vars:
			var ok2 = _values_equal(vars.get(k), goal.vars[k])
			checks["var_" + k] = ok2
			if not ok2:
				success = false
				if failed_check == "":
					failed_check = "var_" + k
					failure_reason = "La variabile «%s» vale %s, ma dovrebbe valere %s." % [k, _describe(vars.get(k)), _describe(goal.vars[k])]
	if goal.has("min_vars"):
		for k2 in goal.min_vars:
			var ok3 = _num(vars.get(k2)) >= _num(goal.min_vars[k2])
			checks["min_" + k2] = ok3
			if not ok3:
				success = false
				if failed_check == "":
					failed_check = "min_" + k2
					failure_reason = "La variabile «%s» deve essere almeno %s." % [k2, str(goal.min_vars[k2])]
	if goal.has("event_counts"):
		for kind in goal.event_counts:
			var got = 0
			for ev in events:
				if ev.get("kind", "") == kind:
					got += 1
			var ok4 = got >= int(goal.event_counts[kind])
			checks["event_" + kind] = ok4
			if not ok4:
				success = false
				if failed_check == "":
					failed_check = "event_" + kind
					failure_reason = "L'evento «%s» è avvenuto %d volte, ne servono %d." % [kind, got, int(goal.event_counts[kind])]
	if not success and failure_reason == "":
		failure_reason = "Il programma è valido, ma l'obiettivo non è ancora soddisfatto."


func _order_present(required: Array) -> bool:
	var idx = 0
	for p in visited:
		if idx >= required.size():
			break
		if int(p.x) == int(required[idx][0]) and int(p.y) == int(required[idx][1]):
			idx += 1
	return idx >= required.size()


func _entity_label(id: String) -> String:
	for e in entities:
		if e.get("id", "") == id:
			return e.get("label", id)
	return id


func _values_equal(a, b) -> bool:
	if a is int or a is float:
		if b is int or b is float:
			return abs(float(a) - float(b)) < 0.001
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _values_equal(a[i], b[i]):
				return false
		return true
	if a is bool or b is bool:
		return _truthy(a) == _truthy(b)
	return a == b
