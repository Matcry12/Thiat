class_name F3Search
## Settings search. A name hit (every word is part of the setting name) ranks above a section hit
## (every word is a WHOLE word of the section name: "heal" does not pull `HealthBar`).
## sections: [{name, props: [{name, ...}]}]. Returns [{section: String, prop: Dictionary, name_hit: bool}], name hits first.

static func words(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for i in s.length():
		var c := s[i]
		var sep := c == " " or c == "_" or c == "." or c == "-"
		var camel := i > 0 and c != c.to_lower() and s[i - 1] == s[i - 1].to_lower() and s[i - 1] != " " and s[i - 1] != "_"
		if sep or camel:
			if cur != "":
				out.append(cur.to_lower())
			cur = "" if sep else c
		else:
			cur += c
	if cur != "":
		out.append(cur.to_lower())
	return out

static func run(sections: Array, query: String) -> Array:
	var tokens := query.strip_edges().to_lower().split(" ", false)
	if tokens.is_empty():
		return []
	var by_name: Array = []
	var by_section: Array = []
	for sec in sections:
		var sw := words(sec["name"])
		for p in sec["props"]:
			var pn: String = String(p["name"]).to_lower()
			var name_tokens := 0
			var ok := true
			for t in tokens:
				if pn.contains(t):
					name_tokens += 1
				elif not sw.has(t):
					ok = false
					break
			if not ok:
				continue
			var hit := {"section": sec["name"], "prop": p, "name_hit": name_tokens > 0}
			if name_tokens > 0:
				hit["rank"] = (0 if pn.begins_with(tokens[0]) else 1000000) + by_name.size()
				by_name.append(hit)
			else:
				by_section.append(hit)
	by_name.sort_custom(func(a, b): return a["rank"] < b["rank"])
	return by_name + by_section
