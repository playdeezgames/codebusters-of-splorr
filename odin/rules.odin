package codebusters

// The pure game: Farkle played against a hidden Mastermind code. Nothing here touches the
// page; every random number comes from the game's own generator, seeded by the platform.
//
// A turn: roll the free dice, arrange them in the open slots, check. Each black peg (right
// face, right slot) locks that die and scores. No new black peg is a bust: the turn's points
// are lost. After a scoring check, bank the points or roll the dice still free. Locking all
// five slots busts the code: a bonus, a new code, and all five dice are free again.
// Locks clear at the end of every turn; the code (and what the guesses taught) stays until busted.

SLOTS :: 5
FACES :: 6
TURNS :: 10
POINTS_PER_BLACK :: 100
CRACK_BONUS :: 500
MAX_LOG :: 64

Phase :: enum u8 {
	Start_Turn, // waiting for the first roll of a turn
	Arranging, // dice rolled into the open slots; swap them, then check
	Scored, // the last check locked at least one die: bank or roll the rest
	Busted, // the last check found no new black peg; the turn's points are gone
	Over, // all turns played
}

// One check, as it was made: the row (locked faces and placed dice), which slots were already
// locked going in, and the pegs for the open slots.
Guess :: struct {
	faces:  [SLOTS]u8,
	locked: [SLOTS]bool,
	blacks: u8,
	whites: u8,
}

Game :: struct {
	rng:          u64,
	code:         [SLOTS]u8,
	locked:       [SLOTS]bool,
	faces:        [SLOTS]u8, // the row; 0 is an empty open slot
	selected:     int, // the open slot picked for a swap, or -1
	phase:        Phase,
	turn:         int, // 1 to TURNS
	score:        int,
	turn_points:  int,
	codes_busted: int,
	busts:        int,
	// Guesses at the current code, oldest first.
	log:          [MAX_LOG]Guess,
	log_count:    int,
	// The latest check, kept for the message after it (the log may have been cleared by a bust code).
	last:         Guess,
	last_cracked: bool,
	last_points:  int, // points the latest check added (or lost, for a bust)
}

// xorshift64*; u64 works on js_wasm32.
rand_u64 :: proc(g: ^Game) -> u64 {
	x := g.rng
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	g.rng = x
	return x * 0x2545F4914F6CDD1D
}

@(private = "file")
roll_die :: proc(g: ^Game) -> u8 {
	return u8(rand_u64(g) % FACES) + 1
}

new_game :: proc(g: ^Game, seed: u64) {
	g^ = {}
	g.rng = seed | 1
	g.selected = -1
	g.turn = 1
	new_code(g)
}

@(private = "file")
new_code :: proc(g: ^Game) {
	for i in 0 ..< SLOTS {
		g.code[i] = roll_die(g)
	}
	g.log_count = 0
}

free_dice :: proc(g: ^Game) -> int {
	n := 0
	for l in g.locked {
		if !l {n += 1}
	}
	return n
}

// Pegs for the open slots only: locked slots are known and take no part.
score_guess :: proc(code, faces: [SLOTS]u8, locked: [SLOTS]bool) -> (blacks, whites: int) {
	code_left, guess_left: [FACES + 1]int
	for i in 0 ..< SLOTS {
		if locked[i] {continue}
		if faces[i] == code[i] {
			blacks += 1
		} else {
			code_left[code[i]] += 1
			if faces[i] >= 1 && faces[i] <= FACES {
				guess_left[faces[i]] += 1
			}
		}
	}
	for f in 1 ..= FACES {
		whites += min(code_left[f], guess_left[f])
	}
	return
}

can_roll :: proc(g: ^Game) -> bool {
	return g.phase == .Start_Turn || g.phase == .Scored
}

// Rolls a die into every open slot.
roll :: proc(g: ^Game) {
	if !can_roll(g) {return}
	for i in 0 ..< SLOTS {
		if g.locked[i] {
			g.faces[i] = g.code[i]
		} else {
			g.faces[i] = roll_die(g)
		}
	}
	g.selected = -1
	g.phase = .Arranging
}

// Picks an open slot; picking a second one swaps the two dice, picking the same one again lets go.
select_slot :: proc(g: ^Game, i: int) {
	if g.phase != .Arranging || i < 0 || i >= SLOTS || g.locked[i] {return}
	switch {
	case g.selected < 0:
		g.selected = i
	case g.selected == i:
		g.selected = -1
	case:
		g.faces[g.selected], g.faces[i] = g.faces[i], g.faces[g.selected]
		g.selected = -1
	}
}

@(private = "file")
push_log :: proc(g: ^Game, guess: Guess) {
	if g.log_count == MAX_LOG {
		copy(g.log[:], g.log[1:])
		g.log_count -= 1
	}
	g.log[g.log_count] = guess
	g.log_count += 1
}

check :: proc(g: ^Game) {
	if g.phase != .Arranging {return}
	b, w := score_guess(g.code, g.faces, g.locked)
	guess := Guess{g.faces, g.locked, u8(b), u8(w)}
	push_log(g, guess)
	g.last = guess
	g.last_cracked = false
	g.selected = -1
	if b == 0 {
		g.last_points = g.turn_points
		g.turn_points = 0
		g.busts += 1
		g.phase = .Busted
		return
	}
	for i in 0 ..< SLOTS {
		if !g.locked[i] && g.faces[i] == g.code[i] {
			g.locked[i] = true
		}
	}
	g.last_points = b * POINTS_PER_BLACK
	if free_dice(g) == 0 {
		g.last_points += CRACK_BONUS
		g.last_cracked = true
		g.codes_busted += 1
		g.locked = {}
		new_code(g)
	}
	g.turn_points += g.last_points
	for i in 0 ..< SLOTS {
		if !g.locked[i] {g.faces[i] = 0}
	}
	g.phase = .Scored
}

bank :: proc(g: ^Game) {
	if g.phase != .Scored {return}
	g.score += g.turn_points
	end_turn(g)
}

// After a bust, move on.
next_turn :: proc(g: ^Game) {
	if g.phase != .Busted {return}
	end_turn(g)
}

@(private = "file")
end_turn :: proc(g: ^Game) {
	g.locked = {}
	g.faces = {}
	g.turn_points = 0
	g.selected = -1
	if g.turn >= TURNS {
		g.phase = .Over
		return
	}
	g.turn += 1
	g.phase = .Start_Turn
}
