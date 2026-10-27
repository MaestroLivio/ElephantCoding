class_name DSLParser
extends RefCounted

## Parser for the educational Italian DSL used by ElephantCoding.
## It produces a typed AST. eval/exec and arbitrary code are never used.

const KEYWORDS = {
	"AVANTI": true, "DESTRA": true, "SINISTRA": true, "GIRA": true,
	"TOCCA": true, "RACCOGLI": true, "PRENDI": true, "ATTIVA": true,
	"APRI": true, "ACCENDI": true, "FOTO": true, "SCANSIONA": true,
	"SALUTA": true, "SUONA": true, "PAUSA": true, "VERSA": true,
	"ASPETTA": true, "SU": true, "ATTRAVERSA": true, "RICARICA": true,
	"SEGNALA": true, "DEPOSITA": true, "LASCIA": true, "TRACCIA": true,
	"CHIUDI": true, "VAI": true, "MUOVI": true, "X": true, "Y": true,
	"RIPETI": true, "VOLTE": true, "SE": true, "ALLORA": true,
	"ALTRIMENTI": true, "FINCHÉ": true, "FINCHE": true, "IMPOSTA": true,
	"PER": true, "OGNI": true, "IN": true, "DA": true, "A": true,
	"PROCEDURA": true, "FUNZIONE": true, "RITORNA": true, "E": true,
	"O": true, "NON": true, "VERO": true, "FALSO": true, "NULLO": true,
	"LUNGHEZZA": true, "ASS": true, "ABS": true, "MIN": true, "MAX": true,
	"AGGIUNGI": true, "ESTRAI": true, "CONTIENE": true, "VUOTA": true,
	"ARROTONDA": true, "SCAMBIA": true,
}

const ACTIONS = {
	"TOCCA": true, "RACCOGLI": true, "PRENDI": true, "ATTIVA": true,
	"APRI": true, "ACCENDI": true, "FOTO": true, "SCANSIONA": true,
	"SALUTA": true, "SUONA": true, "PAUSA": true, "ATTRAVERSA": true,
	"RICARICA": true, "SEGNALA": true, "DEPOSITA": true, "LASCIA": true,
	"CHIUDI": true,
}

var _tokens: Array = []
var _i = 0
var _source = ""
var _definitions: Array = []


func parse(source: String) -> Dictionary:
	_source = source
	_definitions = []
	_parse_error = {}
	var lex = _tokenize(source)
	if not lex.ok:
		return lex
	_tokens = lex.tokens
	_i = 0
	var body: Array = []
	while not _at_end():
		_skip_separators()
		if _at_end():
			break
		var stmt = _statement()
		if stmt == null:
			return _error_result()
		if stmt is Dictionary and stmt.get("_definition", false):
			continue
		body.append(stmt)
	return {
		"ok": true,
		"program": body,
		"definitions": _definitions,
		"error": {},
		"tokens": _tokens.size(),
	}


# ---------------------------------------------------------------------------
# Lexer
# ---------------------------------------------------------------------------
func _tokenize(src: String) -> Dictionary:
	var tokens: Array = []
	var i = 0
	var line = 1
	var col = 1
	var n = src.length()
	while i < n:
		var c = src[i]
		if c == "\n":
			tokens.append({"type": "newline", "value": "\n", "line": line, "col": col})
			i += 1
			line += 1
			col = 1
			continue
		if c == "\r" or c == " " or c == "\t":
			i += 1
			col += 1
			continue
		if c == "#" or (c == "/" and i + 1 < n and src[i + 1] == "/"):
			while i < n and src[i] != "\n":
				i += 1
			continue
		if c.is_valid_int() or (c == "." and i + 1 < n and src[i + 1].is_valid_int()):
			var start_col = col
			var text = ""
			var seen_dot = false
			while i < n:
				var d = src[i]
				if d.is_valid_int():
					text += d
					i += 1
					col += 1
				elif d == "." and not seen_dot:
					seen_dot = true
					text += d
					i += 1
					col += 1
				else:
					break
			tokens.append({"type": "number", "value": float(text) if seen_dot else int(text), "line": line, "col": start_col})
			continue
		if c == '"' or c == "'":
			var quote = c
			var start_col = col
			i += 1
			col += 1
			var out = ""
			var closed = false
			while i < n:
				var d = src[i]
				if d == "\\" and i + 1 < n:
					out += src[i + 1]
					i += 2
					col += 2
					continue
				if d == quote:
					i += 1
					col += 1
					closed = true
					break
				if d == "\n":
					return {"ok": false, "error": {"message": "Stringa non chiusa.", "line": line, "column": col}}
				out += d
				i += 1
				col += 1
			if not closed:
				return {"ok": false, "error": {"message": "Stringa non chiusa.", "line": line, "column": start_col}}
			tokens.append({"type": "string", "value": out, "line": line, "col": start_col})
			continue
		if _is_ident_start(c):
			var start_col = col
			var word = ""
			while i < n and _is_ident_part(src[i]):
				word += src[i]
				i += 1
				col += 1
			var upper = word.to_upper()
			if upper == "FINCHÈ":
				upper = "FINCHÉ"
			tokens.append({"type": "ident", "value": word, "upper": upper, "line": line, "col": start_col})
			continue
		# operators
		var two = src.substr(i, 2)
		if two in ["<=", ">=", "==", "!="]:
			tokens.append({"type": "symbol", "value": two, "line": line, "col": col})
			i += 2
			col += 2
			continue
		if c in ["(", ")", "{", "}", "[", "]", ",", ";", "=", "<", ">", "+", "-", "*", "/", "%", ".", "!"]:
			tokens.append({"type": "symbol", "value": c, "line": line, "col": col})
			i += 1
			col += 1
			continue
		return {"ok": false, "error": {"message": "Carattere non riconosciuto: «%s»." % c, "line": line, "column": col}}
	tokens.append({"type": "eof", "value": "", "line": line, "col": col})
	return {"ok": true, "tokens": tokens}


func _is_ident_start(c: String) -> bool:
	return c == "_" or (c.to_upper() != c.to_lower() and c.length() == 1) or c == "à" or c == "è" or c == "é" or c == "ì" or c == "ò" or c == "ù"


func _is_ident_part(c: String) -> bool:
	return _is_ident_start(c) or c.is_valid_int()


# ---------------------------------------------------------------------------
# Parser helpers
# ---------------------------------------------------------------------------
func _at_end() -> bool:
	return _peek().type == "eof"


func _peek(offset = 0) -> Dictionary:
	var idx = _i + offset
	if idx >= _tokens.size():
		return _tokens[_tokens.size() - 1]
	return _tokens[idx]


func _advance() -> Dictionary:
	var t = _tokens[_i]
	if _i < _tokens.size() - 1:
		_i += 1
	return t


func _check(value: String) -> bool:
	var t = _peek()
	if t.type == "symbol" and t.value == value:
		return true
	if t.type == "ident" and t.upper == value:
		return true
	return false


func _match(value: String) -> bool:
	if _check(value):
		_advance()
		return true
	return false


func _expect(value: String, message = "") -> bool:
	if _match(value):
		return true
	_set_error(message if message != "" else "Atteso «%s»." % value, _peek())
	return false


func _skip_separators() -> void:
	while _peek().type == "newline" or (_peek().type == "symbol" and _peek().value == ";"):
		_advance()


func _error_result() -> Dictionary:
	return {"ok": false, "program": [], "definitions": [], "error": _parse_error}


var _parse_error: Dictionary = {}


func _set_error(message: String, token: Dictionary) -> void:
	_parse_error = {"message": message, "line": token.get("line", 0), "column": token.get("col", 0)}


func _block() -> Array:
	if not _expect("{", "Apri una graffa «{» per iniziare il blocco."):
		return []
	var out: Array = []
	while not _at_end():
		_skip_separators()
		if _match("}"):
			return out
		if _at_end():
			break
		var stmt = _statement()
		if stmt == null:
			return []
		if stmt is Dictionary and stmt.get("_definition", false):
			continue
		out.append(stmt)
	_set_error("Blocco non chiuso: manca la graffa «}».", _peek())
	return []


func _statement():
	_skip_separators()
	if _at_end() or _check("}"):
		return null
	var t = _peek()
	if t.type != "ident":
		_set_error("Atteso un comando, trovato «%s»." % str(t.value), t)
		return null
	var kw: String = t.upper
	# definitions
	if kw == "PROCEDURA" or kw == "FUNZIONE":
		return _definition(kw)
	# assignment with IMPOSTA
	if kw == "IMPOSTA":
		return _assignment(true)
	# plain assignment: name = expr
	if _peek(1).type == "symbol" and _peek(1).value == "=":
		return _assignment(false)
	# control flow
	if _peek(1).type == "symbol" and _peek(1).value == "(" and not (kw in ["SE", "RIPETI", "PER", "VAI", "MUOVI", "TRACCIA", "GIRA", "AVANTI", "VERSA", "ASPETTA", "SU"]):
		_advance()
		var call_args = _arguments()
		if call_args == null:
			return null
		return _repeatable({"type": "call", "name": t.value.to_lower(), "args": call_args, "token": t})
	if kw == "SE":
		return _if_statement()
	if kw == "RIPETI":
		return _repeat_statement()
	if kw == "FINCHÉ" or kw == "FINCHE":
		return _while_statement()
	if kw == "PER":
		return _for_statement()
	if kw == "RITORNA":
		_advance()
		var expr = _expression()
		if expr == null:
			return null
		return {"type": "return", "value": expr, "token": t}
	if kw == "VAI":
		return _go_statement()
	if kw == "MUOVI":
		return _move_statement()
	if kw == "TRACCIA":
		_advance()
		var args = _pair_or_expr()
		if args == null:
			return null
		return _repeatable({"type": "trace", "args": args, "token": t})
	if kw == "GIRA":
		_advance()
		if _match("DESTRA"):
			return _repeatable({"type": "turn", "dir": 1, "token": t})
		if _match("SINISTRA"):
			return _repeatable({"type": "turn", "dir": -1, "token": t})
		_set_error("Dopo GIRA scrivi DESTRA oppure SINISTRA.", _peek())
		return null
	if kw == "DESTRA":
		_advance()
		return _repeatable({"type": "turn", "dir": 1, "token": t})
	if kw == "SINISTRA":
		_advance()
		return _repeatable({"type": "turn", "dir": -1, "token": t})
	if kw == "AVANTI":
		_advance()
		var steps = null
		if not _at_statement_end() and not _is_repeat_suffix():
			steps = _expression()
			if steps == null:
				return null
		return _repeatable({"type": "forward", "steps": steps, "token": t})
	if kw == "VERSA" or kw == "ASPETTA" or kw == "SU":
		_advance()
		var amount = null
		if not _at_statement_end() and not _is_repeat_suffix():
			amount = _expression()
			if amount == null:
				return null
		return _repeatable({"type": "amount_action", "action": kw, "amount": amount, "token": t})
	if ACTIONS.has(kw):
		_advance()
		var target = null
		if _check("("):
			target = _pair_or_expr()
			if target == null:
				return null
		return _repeatable({"type": "action", "action": kw, "target": target, "token": t})
	if _peek(1).type == "symbol" and _peek(1).value == "(":
		# procedure call
		_advance()
		var args = _arguments()
		if args == null:
			return null
		return _repeatable({"type": "call", "name": t.value.to_lower(), "args": args, "token": t})
	_set_error("Comando non riconosciuto: «%s»." % t.value, t)
	return null


func _repeatable(node: Dictionary) -> Dictionary:
	# suffix x2 / x3 (also X2)
	if _is_repeat_suffix():
		var tok = _advance()
		var count = int(str(tok.value).substr(1))
		node["repeat"] = count
	return node


func _is_repeat_suffix() -> bool:
	var t = _peek()
	if t.type != "ident":
		return false
	var s: String = str(t.value).to_lower()
	if not s.begins_with("x"):
		return false
	return s.substr(1).is_valid_int()


func _at_statement_end() -> bool:
	var t = _peek()
	return t.type == "newline" or t.type == "eof" or (t.type == "symbol" and t.value in [";", "}"])


func _definition(kw: String):
	var tok = _advance()
	if _peek().type != "ident":
		_set_error("Manca il nome della %s." % ("procedura" if kw == "PROCEDURA" else "funzione"), _peek())
		return null
	var name: String = _peek().value.to_lower()
	_advance()
	var params: Array = []
	if _match("("):
		if not _match(")"):
			while true:
				if _peek().type != "ident":
					_set_error("Atteso un nome di parametro.", _peek())
					return null
				params.append(_peek().value.to_lower())
				_advance()
				if _match(")"):
					break
				if not _expect(","):
					return null
	var body = _block()
	if body.is_empty() and not _parse_error.is_empty():
		return null
	_definitions.append({"kind": kw.to_lower(), "name": name, "params": params, "body": body, "token": tok})
	return {"_definition": true}


func _assignment(imposta: bool):
	if imposta:
		_advance()
	var tok = _peek()
	if _peek().type != "ident":
		_set_error("Atteso il nome di una variabile.", _peek())
		return null
	var name: String = _peek().value.to_lower()
	_advance()
	if not _expect("=", "Dopo il nome della variabile scrivi «=»."):
		return null
	var expr = _expression()
	if expr == null:
		return null
	return {"type": "assign", "name": name, "value": expr, "imposta": imposta, "token": tok}


func _if_statement():
	var tok = _advance()
	var cond = _expression()
	if cond == null:
		return null
	if not _expect("ALLORA", "Dopo la condizione scrivi ALLORA."):
		return null
	var then_block = _branch_body()
	if then_block == null:
		return null
	var else_block: Array = []
	if _match("ALTRIMENTI"):
		var eb = _branch_body()
		if eb == null:
			return null
		else_block = eb
	return {"type": "if", "cond": cond, "then": then_block, "else": else_block, "token": tok}


func _branch_body():
	if _match("{"):
		_i -= 1
		return _block()
	# allow newline + brace
	if _peek().type == "newline":
		var save = _i
		_skip_separators()
		if _check("{"):
			return _block()
		_i = save
	# single statement on the same line
	var st = _statement()
	if st == null:
		return null
	return [st]


func _repeat_statement():
	var tok = _advance()
	var count = null
	if _check("X") or _is_repeat_suffix():
		var count_tok = _advance()
		var raw = str(count_tok.value).to_lower()
		if raw.begins_with("x") and raw.substr(1).is_valid_int():
			count = {"type": "literal", "value": int(raw.substr(1))}
		elif _peek().type == "number":
			count = {"type": "literal", "value": int(_peek().value)}
			_advance()
		else:
			_set_error("Dopo x scrivi quante volte ripetere (x2, x3...).", _peek())
			return null
	else:
		count = _expression()
		if count == null:
			return null
		_match("VOLTE")
	if not _check("{"):
		_set_error("RIPETI richiede un blocco tra graffe: RIPETI x3 { ... }.", _peek())
		return null
	var body = _block()
	if body.is_empty() and not _parse_error.is_empty():
		return null
	return {"type": "repeat", "count": count, "body": body, "token": tok}


func _while_statement():
	var tok = _advance()
	var cond = _expression()
	if cond == null:
		return null
	if not _check("{"):
		_set_error("FINCHÉ richiede un blocco tra graffe: FINCHÉ condizione { ... }.", _peek())
		return null
	var body = _block()
	if body.is_empty() and not _parse_error.is_empty():
		return null
	return {"type": "while", "cond": cond, "body": body, "token": tok}


func _for_statement():
	var tok = _advance()
	if _match("OGNI"):
		if _peek().type != "ident":
			_set_error("Atteso il nome della variabile dopo PER OGNI.", _peek())
			return null
		var var_name: String = _peek().value.to_lower()
		_advance()
		if not _expect("IN", "Dopo la variabile scrivi IN e la lista."):
			return null
		var iterable = _expression()
		if iterable == null:
			return null
		if not _check("{"):
			_set_error("PER OGNI richiede un blocco tra graffe.", _peek())
			return null
		var body = _block()
		if body.is_empty() and not _parse_error.is_empty():
			return null
		return {"type": "for_each", "var": var_name, "iterable": iterable, "body": body, "token": tok}
	if _peek().type != "ident":
		_set_error("Dopo PER scrivi una variabile (oppure OGNI).", _peek())
		return null
	var name: String = _peek().value.to_lower()
	_advance()
	if not _expect("DA", "Dopo la variabile scrivi DA."):
		return null
	var start = _expression()
	if start == null:
		return null
	if not _expect("A", "Dopo il valore iniziale scrivi A."):
		return null
	var stop = _expression()
	if stop == null:
		return null
	if not _check("{"):
		_set_error("PER richiede un blocco tra graffe.", _peek())
		return null
	var body2 = _block()
	if body2.is_empty() and not _parse_error.is_empty():
		return null
	return {"type": "for_range", "var": name, "start": start, "stop": stop, "body": body2, "token": tok}


func _go_statement():
	var tok = _advance()
	if not _expect("A", "Il comando è VAI A (x,y)."):
		return null
	var args = _pair_or_expr()
	if args == null:
		return null
	return _repeatable({"type": "go_to", "args": args, "token": tok})


func _move_statement():
	var tok = _advance()
	if _match("X"):
		var e = _expression()
		if e == null:
			return null
		return _repeatable({"type": "move_axis", "axis": "x", "value": e, "token": tok})
	if _match("Y"):
		var e2 = _expression()
		if e2 == null:
			return null
		return _repeatable({"type": "move_axis", "axis": "y", "value": e2, "token": tok})
	_set_error("Dopo MUOVI scrivi X oppure Y.", _peek())
	return null


func _pair_or_expr():
	# ( expr , expr ) or a single expression (e.g. a point in a list)
	if _match("("):
		var a = _expression()
		if a == null:
			return null
		if _match(","):
			var b = _expression()
			if b == null:
				return null
			if not _expect(")"):
				return null
			return {"kind": "pair", "a": a, "b": b}
		if not _expect(")"):
			return null
		return {"kind": "single", "a": a}
	var e = _expression()
	if e == null:
		return null
	return {"kind": "single", "a": e}


# ---------------------------------------------------------------------------
# Expressions
# ---------------------------------------------------------------------------
func _expression():
	return _or_expr()


func _or_expr():
	var left = _and_expr()
	if left == null:
		return null
	while _check("O"):
		var tok = _advance()
		var right = _and_expr()
		if right == null:
			return null
		left = {"type": "binary", "op": "or", "left": left, "right": right, "token": tok}
	return left


func _and_expr():
	var left = _comparison()
	if left == null:
		return null
	while _check("E"):
		var tok = _advance()
		var right = _comparison()
		if right == null:
			return null
		left = {"type": "binary", "op": "and", "left": left, "right": right, "token": tok}
	return left


func _comparison():
	var left = _additive()
	if left == null:
		return null
	while _peek().type == "symbol" and _peek().value in ["==", "!=", "<", "<=", ">", ">="]:
		var tok = _advance()
		var right = _additive()
		if right == null:
			return null
		left = {"type": "binary", "op": tok.value, "left": left, "right": right, "token": tok}
	return left


func _additive():
	var left = _multiplicative()
	if left == null:
		return null
	while _peek().type == "symbol" and _peek().value in ["+", "-"]:
		var tok = _advance()
		var right = _multiplicative()
		if right == null:
			return null
		left = {"type": "binary", "op": tok.value, "left": left, "right": right, "token": tok}
	return left


func _multiplicative():
	var left = _unary()
	if left == null:
		return null
	while _peek().type == "symbol" and _peek().value in ["*", "/", "%"]:
		var tok = _advance()
		var right = _unary()
		if right == null:
			return null
		left = {"type": "binary", "op": tok.value, "left": left, "right": right, "token": tok}
	return left


func _unary():
	if _match("-"):
		var e = _unary()
		if e == null:
			return null
		return {"type": "unary", "op": "-", "value": e}
	if _match("+"):
		return _unary()
	if _match("NON") or _match("!"):
		var e2 = _unary()
		if e2 == null:
			return null
		return {"type": "unary", "op": "not", "value": e2}
	return _postfix()


func _postfix():
	var node = _primary()
	if node == null:
		return null
	while true:
		if _match("["):
			var idx = _expression()
			if idx == null:
				return null
			if not _expect("]"):
				return null
			node = {"type": "index", "target": node, "index": idx}
			continue
		if _match("."):
			if _peek().type != "ident":
				_set_error("Dopo il punto scrivi x oppure y.", _peek())
				return null
			var prop: String = _peek().value.to_lower()
			_advance()
			node = {"type": "property", "target": node, "name": prop}
			continue
		break
	return node


func _primary():
	var t = _peek()
	if t.type == "number":
		_advance()
		return {"type": "literal", "value": t.value}
	if t.type == "string":
		_advance()
		return {"type": "literal", "value": t.value}
	if t.type == "ident":
		var up: String = t.upper
		if up == "VERO":
			_advance()
			return {"type": "literal", "value": true}
		if up == "FALSO":
			_advance()
			return {"type": "literal", "value": false}
		if up == "NULLO":
			_advance()
			return {"type": "literal", "value": null}
		if _peek(1).type == "symbol" and _peek(1).value == "(":
			_advance()
			var args = _arguments()
			if args == null:
				return null
			return {"type": "call_expr", "name": t.value.to_lower(), "args": args, "token": t}
		_advance()
		return {"type": "variable", "name": t.value.to_lower(), "token": t}
	if _match("("):
		var e = _expression()
		if e == null:
			return null
		if not _expect(")"):
			return null
		return e
	if _match("["):
		var items: Array = []
		if _match("]"):
			return {"type": "list", "items": items}
		while true:
			var e2 = _expression()
			if e2 == null:
				return null
			items.append(e2)
			if _match("]"):
				break
			if not _expect(",", "Separa gli elementi della lista con una virgola."):
				return null
		return {"type": "list", "items": items}
	_set_error("Attesa un'espressione, trovato «%s»." % str(t.value), t)
	return null


func _arguments() -> Array:
	var args: Array = []
	if not _expect("("):
		return []
	if _match(")"):
		return args
	while true:
		var e = _expression()
		if e == null:
			return []
		args.append(e)
		if _match(")"):
			break
		if not _expect(","):
			return []
	return args
