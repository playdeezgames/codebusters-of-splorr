#+build !js
package codebusters

import "core:testing"

@(private = "file")
count_kind :: proc(v: ^View, kind: Elem_Kind) -> int {
	n := 0
	for e in v.elems[:v.count] {
		if e.kind == kind {n += 1}
	}
	return n
}

@(private = "file")
has_button :: proc(v: ^View, action: Action) -> bool {
	for e in v.elems[:v.count] {
		if e.kind == .Button && e.action == action {return true}
	}
	return false
}

@(test)
title_then_play :: proc(t: ^testing.T) {
	a: App
	app_init(&a, 42)
	v := make_view(&a)
	testing.expect(t, has_button(&v, .Start))
	click(&a, .Start)
	v = make_view(&a)
	testing.expect_value(t, count_kind(&v, .Slot_Empty), SLOTS)
	testing.expect(t, has_button(&v, .Roll))
	free_all(context.temp_allocator)
}

@(test)
roll_select_check_through_the_view :: proc(t: ^testing.T) {
	a: App
	app_init(&a, 42)
	click(&a, .Start)
	click(&a, .Roll)
	v := make_view(&a)
	testing.expect_value(t, count_kind(&v, .Slot_Free), SLOTS)
	testing.expect(t, has_button(&v, .Check))
	click(&a, .Slot_2)
	v = make_view(&a)
	testing.expect_value(t, count_kind(&v, .Slot_Selected), 1)
	click(&a, .Check)
	v = make_view(&a)
	testing.expect_value(t, count_kind(&v, .Log), 1)
	testing.expect(t, a.game.phase == .Scored || a.game.phase == .Busted)
	free_all(context.temp_allocator)
}

@(test)
scored_offers_bank_and_roll :: proc(t: ^testing.T) {
	a: App
	app_init(&a, 1)
	a.screen = .Play
	a.game.code = {1, 2, 3, 4, 5}
	roll(&a.game)
	a.game.faces = {1, 2, 6, 6, 6}
	check(&a.game)
	v := make_view(&a)
	testing.expect_value(t, count_kind(&v, .Slot_Locked), 2)
	testing.expect(t, has_button(&v, .Bank))
	testing.expect(t, has_button(&v, .Roll))
	testing.expect_value(t, phase_text(&a.game), "● ●. 2 locked in, +200. Bank 200, or roll the 3 dice still free.")
	free_all(context.temp_allocator)
}

@(test)
guess_and_peg_wording :: proc(t: ^testing.T) {
	g := Guess{{1, 6, 6, 2, 4}, {true, false, false, false, false}, 1, 2}
	testing.expect_value(t, guess_text(g), "[1] 6 6 2 4   ● ○ ○")
	testing.expect_value(t, pegs_text(0, 0), "nothing")
	free_all(context.temp_allocator)
}

@(test)
view_never_overflows :: proc(t: ^testing.T) {
	a: App
	app_init(&a, 3)
	a.screen = .Play
	a.game.log_count = MAX_LOG
	v := make_view(&a)
	testing.expect(t, v.count <= MAX_ELEMS)
	testing.expect_value(t, count_kind(&v, .Log), MAX_LOG)
	free_all(context.temp_allocator)
}

@(test)
play_again_starts_fresh :: proc(t: ^testing.T) {
	a: App
	app_init(&a, 5)
	a.screen = .Play
	a.game.phase = .Over
	a.game.score = 900
	v := make_view(&a)
	testing.expect(t, has_button(&v, .Play_Again))
	click(&a, .Play_Again)
	testing.expect_value(t, a.game.score, 0)
	testing.expect_value(t, a.game.phase, Phase.Start_Turn)
	free_all(context.temp_allocator)
}

// web/index.html has a KIND table in the same order as Elem_Kind.
@(test)
element_kinds_match_the_page :: proc(t: ^testing.T) {
	testing.expect_value(t, len(Elem_Kind), 10)
	testing.expect_value(t, int(Elem_Kind.Log), 9)
}
