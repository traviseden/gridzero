# How GridZero plays

The [gameplay controller](site/src/game/machine.ts) owns the screen, the active session, the digit in flight, and the open dialog. Both touch and keyboard input use its transitions. The [Sudoku rules](site/src/game/game.ts) operate on the same saved board in either mode; the [browser adapter](site/src/game/app.ts) handles storage, history, focus, animation, and sound.

### Starting or resuming

![Setup goes to preparation on Play. Only successful preparation installs a board; cancel or failure returns to setup.](docs/diagrams/screen.svg)

`/` opens setup without replacing the previous game. Play chooses from the collection or starts the generator worker. Only the current request can install a puzzle and remember the setup choices. `/play/` and browser history can return to the saved board; without a valid save the player returns to setup.

### Playing a puzzle

![Challenge can end in strike-out or completion. A struck-out player can retry or continue in Classic. Classic completes on a full valid board.](docs/diagrams/session.svg)

Challenge rejects wrong guesses, counts strikes, and locks edits at the limit. Retry starts the same puzzle over; Continue in Classic keeps entries, history, and strikes. Classic accepts hypotheses without correctness feedback until the player chooses Check Board. Both modes support notes, erase, undo, and redo; undo never refunds strikes. A completed board remains available to admire. Restart resets the current mode’s board; New game returns to setup.

The controller derives these session states from the saved game. Restore can therefore resume *any* of them, including a locked board.

### Placing a digit

![A committed guess travels. Accepted guesses settle on arrival; rejected guesses recoil before returning to idle.](docs/diagrams/entry.svg)

A filled cell focuses its digit; an empty cell selects an entry target. A valid input commits **before** the 350 ms flight. No second input is accepted until the flight (and, for a rejection, the 450 ms recoil) settles. Challenge cues fire once at arrival; Reduce Motion and notes settle immediately. Notes, Classic, and history changes never play correctness sounds. Rotation or navigation settles the existing move rather than applying it again.

### Opening a dialog

![Setup can open Settings or Mode Info. The board can open a menu or an outcome notice. Dismissal returns control to the underlying screen.](docs/diagrams/overlay.svg)

An overlay pauses the clock and blocks board input. Settings is shared by setup and play. Notices handle check results, restart confirmation, completion, and strike-out. Closing a dialog returns control to the underlying screen; leaving for setup keeps the saved game.

### Updating the diagrams

The editable [diagram sources](docs/diagrams/) use Mermaid state syntax supported by [Pele](https://pele.run). After changing a transition, update the matching `.mmd` and regenerate the checked-in SVGs:

```sh
npm --prefix site run diagrams
```

Pele runs only for documentation. It is not shipped with the game.
