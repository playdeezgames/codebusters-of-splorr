package codebusters

import "core:fmt"
import "core:strings"

// The screens as a view model: `make_view` lists what the page shows and `click` runs what a
// button does. Testable natively; web.odin only hands the view to the page.
// All wording here is a first draft for the user to approve.

Screen :: enum u8 {
	Title,
	How_To_Play,
	Play,
}

// The page's element kinds; web/index.html has a table in the same order.
Elem_Kind :: enum u8 {
	Title,
	Text,
	Stat,
	Button,
	Slot_Empty, // an open slot with no die in it
	Slot_Free, // a die you can move
	Slot_Selected, // the die picked for a swap
	Slot_Locked, // a black peg, locked for the rest of the turn
	Log_Head,
	Log, // one guess at the current code
}

Action :: enum u8 {
	None,
	Start,
	How_To_Play,
	Back,
	Roll,
	Check,
	Bank,
	Next_Turn,
	Play_Again,
	Slot_1,
	Slot_2,
	Slot_3,
	Slot_4,
	Slot_5,
}

Elem :: struct {
	kind:   Elem_Kind,
	action: Action,
	text:   string,
}

MAX_ELEMS :: 24 + MAX_LOG

View :: struct {
	elems: [MAX_ELEMS]Elem,
	count: int,
}

App :: struct {
	game:   Game,
	screen: Screen,
	seed:   u64,
}

app_init :: proc(a: ^App, seed: u64) {
	a^ = {}
	a.seed = seed
	new_game(&a.game, seed)
}

@(private = "file")
add :: proc(v: ^View, kind: Elem_Kind, text: string, action := Action.None) {
	if v.count < MAX_ELEMS {
		v.elems[v.count] = Elem{kind, action, text}
		v.count += 1
	}
}

TITLE :: "Codebusters of SPLORR!!"

HOW_TO_PLAY := [?]string {
	"A code of five dice faces is hiding. Ye have ten turns to score as much as ye can off it.",
	"Roll yer dice into the open slots, then click two dice to swap them until the row looks right. Check it.",
	"● means a right face in the right slot. That die locks in and scores 100. ○ means a right face in the wrong slot. It scores nothing, but now ye know.",
	"After a check that locks something, bank the turn's points or roll the dice still free. A check with no new ● busts the turn: every point from it is gone.",
	"Lock all five and ye bust the code: 500 more, a new code, and all five dice are yers again. Keep pushing or bank.",
	"Locks clear at the end of every turn. The code does not, and neither do yer guesses at it.",
}

// "● ● ○" for the pegs, "nothing" for none.
pegs_text :: proc(blacks, whites: int) -> string {
	if blacks + whites == 0 {return "nothing"}
	sb := strings.builder_make(context.temp_allocator)
	for i in 0 ..< blacks + whites {
		if i > 0 {strings.write_byte(&sb, ' ')}
		strings.write_string(&sb, i < blacks ? "●" : "○")
	}
	return strings.to_string(sb)
}

// "[1] 6 6 2 4  ●  ○": locked going in are bracketed.
guess_text :: proc(guess: Guess) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for i in 0 ..< SLOTS {
		if i > 0 {strings.write_byte(&sb, ' ')}
		if guess.locked[i] {
			fmt.sbprintf(&sb, "[%d]", guess.faces[i])
		} else {
			fmt.sbprintf(&sb, "%d", guess.faces[i])
		}
	}
	strings.write_string(&sb, "   ")
	strings.write_string(&sb, pegs_text(int(guess.blacks), int(guess.whites)))
	return strings.to_string(sb)
}

@(private = "file")
dice_word :: proc(n: int) -> string {
	return n == 1 ? "die" : "dice"
}

phase_text :: proc(g: ^Game) -> string {
	switch g.phase {
	case .Start_Turn:
		if g.log_count == 0 {
			return "A new code is hiding. Roll yer five dice."
		}
		return "The code is still hiding. Roll yer five dice."
	case .Arranging:
		return "Click two dice to swap them. Check when the row looks right."
	case .Scored:
		pegs := pegs_text(int(g.last.blacks), int(g.last.whites))
		if g.last_cracked {
			return fmt.tprintf(
				"%s. CODE BUSTED! +%d. A new code is hiding, and all five dice are yers again.",
				pegs,
				g.last_points,
			)
		}
		n := free_dice(g)
		return fmt.tprintf(
			"%s. %d locked in, +%d. Bank %d, or roll the %d %s still free.",
			pegs,
			int(g.last.blacks),
			g.last_points,
			g.turn_points,
			n,
			dice_word(n),
		)
	case .Busted:
		pegs := pegs_text(int(g.last.blacks), int(g.last.whites))
		if g.last_points > 0 {
			return fmt.tprintf("%s. No new ●. BUSTED. Ye lose the %d ye had this turn.", pegs, g.last_points)
		}
		return fmt.tprintf("%s. No new ●. BUSTED.", pegs)
	case .Over:
		return fmt.tprintf(
			"That was the last turn. Final score: %d. Codes busted: %d. Turns busted: %d.",
			g.score,
			g.codes_busted,
			g.busts,
		)
	}
	return ""
}

make_view :: proc(a: ^App) -> View {
	v: View
	add(&v, .Title, TITLE)
	switch a.screen {
	case .Title:
		add(&v, .Text, "Farkle, played against a hidden Mastermind code. Push yer luck, mind yer pegs.")
		add(&v, .Button, "Play", .Start)
		add(&v, .Button, "How to Play", .How_To_Play)
	case .How_To_Play:
		for line in HOW_TO_PLAY {
			add(&v, .Text, line)
		}
		add(&v, .Button, "Back", .Back)
	case .Play:
		play_view(&v, &a.game)
	}
	return v
}

@(private = "file")
play_view :: proc(v: ^View, g: ^Game) {
	if g.phase == .Over {
		add(v, .Stat, fmt.tprintf("Score %d", g.score))
	} else {
		add(v, .Stat, fmt.tprintf("Turn %d of %d · Score %d · This turn %d", g.turn, TURNS, g.score, g.turn_points))
	}
	for i in 0 ..< SLOTS {
		if g.phase == .Over {break}
		action := Action(int(Action.Slot_1) + i)
		switch {
		case g.locked[i]:
			add(v, .Slot_Locked, fmt.tprintf("%d", g.code[i]), action)
		case g.faces[i] == 0:
			add(v, .Slot_Empty, "·", action)
		case g.selected == i:
			add(v, .Slot_Selected, fmt.tprintf("%d", g.faces[i]), action)
		case:
			add(v, .Slot_Free, fmt.tprintf("%d", g.faces[i]), action)
		}
	}
	add(v, .Text, phase_text(g))
	switch g.phase {
	case .Start_Turn:
		add(v, .Button, "Roll", .Roll)
	case .Arranging:
		add(v, .Button, "Check", .Check)
	case .Scored:
		add(v, .Button, fmt.tprintf("Bank %d", g.turn_points), .Bank)
		n := free_dice(g)
		add(v, .Button, fmt.tprintf("Roll %d %s", n, dice_word(n)), .Roll)
	case .Busted:
		add(v, .Button, g.turn >= TURNS ? "See the score" : "Next turn", .Next_Turn)
	case .Over:
		add(v, .Button, "Play again", .Play_Again)
		add(v, .Button, "How to Play", .How_To_Play)
	}
	if g.log_count > 0 && g.phase != .Over {
		add(v, .Log_Head, "Guesses at this code ([n] was already locked):")
		for k in 0 ..< g.log_count {
			add(v, .Log, guess_text(g.log[k]))
		}
	}
}

click :: proc(a: ^App, action: Action) {
	g := &a.game
	#partial switch action {
	case .Start:
		a.screen = .Play
	case .How_To_Play:
		a.screen = .How_To_Play
	case .Back:
		a.screen = g.phase == .Over || (g.turn == 1 && g.phase == .Start_Turn && g.log_count == 0) ? .Title : .Play
	case .Roll:
		roll(g)
	case .Check:
		check(g)
	case .Bank:
		bank(g)
	case .Next_Turn:
		next_turn(g)
	case .Play_Again:
		a.seed = rand_u64(g)
		new_game(g, a.seed)
		a.screen = .Play
	case .Slot_1 ..= .Slot_5:
		select_slot(g, int(action) - int(Action.Slot_1))
	}
}
