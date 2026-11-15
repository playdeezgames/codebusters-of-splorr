#+build !js
package codebusters

import "core:testing"

@(private = "file")
fresh :: proc(code: [SLOTS]u8) -> Game {
	g: Game
	new_game(&g, 12345)
	g.code = code
	return g
}

// Rolls, then overwrites the open slots with chosen faces (the dice are random; the rules are not).
@(private = "file")
place :: proc(g: ^Game, faces: [SLOTS]u8) {
	roll(g)
	for i in 0 ..< SLOTS {
		if !g.locked[i] {g.faces[i] = faces[i]}
	}
}

@(test)
pegs_count_blacks_and_whites :: proc(t: ^testing.T) {
	code := [SLOTS]u8{1, 2, 3, 4, 5}
	none: [SLOTS]bool
	b, w := score_guess(code, {1, 2, 3, 4, 5}, none)
	testing.expect_value(t, b, 5)
	testing.expect_value(t, w, 0)
	b, w = score_guess(code, {5, 4, 3, 2, 1}, none)
	testing.expect_value(t, b, 1)
	testing.expect_value(t, w, 4)
	b, w = score_guess(code, {6, 6, 6, 6, 6}, none)
	testing.expect_value(t, b, 0)
	testing.expect_value(t, w, 0)
}

@(test)
repeated_faces_are_not_counted_twice :: proc(t: ^testing.T) {
	none: [SLOTS]bool
	b, w := score_guess({1, 1, 2, 3, 4}, {2, 2, 2, 1, 6}, none)
	testing.expect_value(t, b, 1) // the 2 in slot 3
	testing.expect_value(t, w, 1) // one 1 is in the code but misplaced; the extra 2s are not
}

@(test)
locked_slots_take_no_part_in_pegs :: proc(t: ^testing.T) {
	locked := [SLOTS]bool{true, false, false, false, false}
	b, w := score_guess({1, 2, 3, 4, 5}, {1, 1, 6, 6, 6}, locked)
	testing.expect_value(t, b, 0)
	testing.expect_value(t, w, 0) // slot 1's 1 is spoken for by the lock
}

@(test)
new_game_starts_turn_one_with_a_code :: proc(t: ^testing.T) {
	g: Game
	new_game(&g, 7)
	testing.expect_value(t, g.phase, Phase.Start_Turn)
	testing.expect_value(t, g.turn, 1)
	for f in g.code {
		testing.expect(t, f >= 1 && f <= FACES)
	}
}

@(test)
same_seed_same_game :: proc(t: ^testing.T) {
	a, b: Game
	new_game(&a, 99)
	new_game(&b, 99)
	testing.expect_value(t, a.code, b.code)
	roll(&a)
	roll(&b)
	testing.expect_value(t, a.faces, b.faces)
}

@(test)
rolls_fill_open_slots_with_dice :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	for _ in 0 ..< 200 {
		g.phase = .Start_Turn
		roll(&g)
		for f in g.faces {
			testing.expect(t, f >= 1 && f <= FACES)
		}
	}
}

@(test)
a_black_peg_locks_and_scores :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	place(&g, {1, 6, 6, 6, 2})
	check(&g)
	testing.expect_value(t, g.phase, Phase.Scored)
	testing.expect(t, g.locked[0])
	testing.expect_value(t, free_dice(&g), 4)
	testing.expect_value(t, g.turn_points, POINTS_PER_BLACK)
	testing.expect_value(t, g.last.blacks, 1)
	testing.expect_value(t, g.last.whites, 1)
	testing.expect_value(t, g.log_count, 1)
	testing.expect_value(t, g.faces[1], 0) // the free dice are back in hand
}

@(test)
rolling_the_rest_keeps_locks :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	place(&g, {1, 2, 6, 6, 6})
	check(&g)
	roll(&g)
	testing.expect_value(t, g.phase, Phase.Arranging)
	testing.expect_value(t, g.faces[0], 1)
	testing.expect_value(t, g.faces[1], 2)
}

@(test)
no_new_black_busts_the_turn :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	place(&g, {1, 2, 6, 6, 6})
	check(&g)
	testing.expect_value(t, g.turn_points, 200)
	place(&g, {0, 0, 4, 5, 6}) // whites only
	check(&g)
	testing.expect_value(t, g.phase, Phase.Busted)
	testing.expect_value(t, g.turn_points, 0)
	testing.expect_value(t, g.last_points, 200)
	testing.expect_value(t, g.busts, 1)
	next_turn(&g)
	testing.expect_value(t, g.turn, 2)
	testing.expect_value(t, g.score, 0)
	testing.expect_value(t, free_dice(&g), SLOTS) // locks clear
	testing.expect_value(t, g.code, [SLOTS]u8{1, 2, 3, 4, 5}) // the code stays
	testing.expect_value(t, g.log_count, 2) // and so do the guesses
}

@(test)
banking_adds_the_turn_and_clears_locks :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	place(&g, {1, 2, 3, 6, 6})
	check(&g)
	bank(&g)
	testing.expect_value(t, g.score, 300)
	testing.expect_value(t, g.turn, 2)
	testing.expect_value(t, g.phase, Phase.Start_Turn)
	testing.expect_value(t, free_dice(&g), SLOTS)
}

@(test)
busting_the_code_pays_a_bonus_and_frees_all_dice :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	place(&g, {1, 2, 3, 6, 6})
	check(&g)
	place(&g, {0, 0, 0, 4, 5})
	check(&g)
	testing.expect(t, g.last_cracked)
	testing.expect_value(t, g.codes_busted, 1)
	testing.expect_value(t, g.turn_points, 500 + CRACK_BONUS)
	testing.expect_value(t, free_dice(&g), SLOTS)
	testing.expect_value(t, g.log_count, 0) // a new code, nothing known about it
	testing.expect_value(t, g.phase, Phase.Scored) // keep going or bank
}

@(test)
swaps_only_open_slots :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	place(&g, {1, 6, 6, 6, 6})
	check(&g)
	place(&g, {0, 3, 4, 5, 6})
	select_slot(&g, 0) // locked: ignored
	testing.expect_value(t, g.selected, -1)
	select_slot(&g, 1)
	select_slot(&g, 4)
	testing.expect_value(t, g.faces, [SLOTS]u8{1, 6, 4, 5, 3})
	testing.expect_value(t, g.selected, -1)
	select_slot(&g, 2)
	select_slot(&g, 2) // let go
	testing.expect_value(t, g.selected, -1)
}

@(test)
game_ends_after_the_last_turn :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	for _ in 1 ..< TURNS {
		place(&g, {6, 6, 6, 6, 6})
		check(&g)
		next_turn(&g)
	}
	testing.expect_value(t, g.turn, TURNS)
	place(&g, {1, 6, 6, 6, 6})
	check(&g)
	bank(&g)
	testing.expect_value(t, g.phase, Phase.Over)
	testing.expect_value(t, g.score, 100)
	roll(&g)
	testing.expect_value(t, g.phase, Phase.Over)
}

@(test)
actions_out_of_phase_do_nothing :: proc(t: ^testing.T) {
	g := fresh({1, 2, 3, 4, 5})
	check(&g)
	bank(&g)
	next_turn(&g)
	testing.expect_value(t, g.phase, Phase.Start_Turn)
	testing.expect_value(t, g.log_count, 0)
}
