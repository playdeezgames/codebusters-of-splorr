#+build js
package codebusters

import "base:runtime"

// The browser side: hands the view to web/index.html and takes clicks back.
// No save yet: a reload starts a new game (prototype).

foreign import host "env"

@(default_calling_convention = "contextless")
foreign host {
	// Milliseconds since the epoch (Date.now()); only seeds the dice.
	now_ms :: proc() -> f64 ---
	// The view: dom_clear, one dom_add per element, then dom_end.
	dom_clear :: proc() ---
	dom_add :: proc(kind: i32, action: i32, ptr: [^]u8, len: i32) ---
	dom_end :: proc() ---
}

@(private = "file")
app: App

main :: proc() {
	app_init(&app, u64(now_ms()) ~ 0x9E3779B97F4A7C15)
	redraw()
}

// Kept so odin.js does not call _end straight after main; the page has no frame loop.
@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	return true
}

@(export)
on_click :: proc "c" (action: i32) {
	context = runtime.default_context()
	if action > 0 && action < i32(len(Action)) {
		click(&app, Action(action))
	}
	redraw()
}

@(private = "file")
redraw :: proc() {
	v := make_view(&app)
	dom_clear()
	for e in v.elems[:v.count] {
		dom_add(i32(e.kind), i32(e.action), raw_data(e.text), i32(len(e.text)))
	}
	dom_end()
	free_all(context.temp_allocator)
}
