# Codebusters of SPLORR!! design

A mashup of Farkle and Mastermind, started November 15, 2026. Taken from the Fifty Games idea list (Dice Games: Farkle; Board Games: Mastermind) because no dice game of the user's was on the web.

## Decided (the user, November 15, 2026)

- Mash up Farkle and Mastermind. Of three proposals the user picked "the dice make your guess": a hidden code of die faces; you roll dice and choose which slot each die goes in, and that arrangement is your guess; standard black and white pegs; a black-peg die locks and scores; reroll the free dice or bank; a check with no new black peg busts the turn's points; locking every slot busts the code for a bonus, a new code and all dice free again.
- Title: **Codebusters of SPLORR!!**

## Prototype defaults (picked by Claude, open for the user)

- 5 slots, faces 1 to 6, repeats allowed in the code.
- 10 turns, solo score chase.
- 100 per black peg; white pegs score nothing (information only). Busting the code: +500.
- Pegs count only the open slots; locked slots take no part.
- Locks clear at the end of every turn (bank or bust); the code and the guess log stay until the code is busted.
- Swapping: click a die, then another, to swap them. Locked dice cannot move.
- No save: a reload starts a new game.
- All on-screen wording (`odin/screens.odin`) is a first draft, not approved.

## Open

- Scoring curve (should pushing deeper pay more per peg?), number of turns, code length.
- Whether whites should score.
- LootLocker top scores, a save, keyboard controls, the metaphor (if any) and the page copy.
