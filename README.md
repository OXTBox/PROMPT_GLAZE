# PROMPT & GLAZE

Two vector heroes who get dropped into every kind of game we build. The same pair
appears in each one: the maze, and whatever comes next from LIB_GAMES, LIB_GAD,
Antack, Thrmnlra or the iGame3D catalogue.

> "Train them for the games, let them hope for a while, and then blow them away."

## The heroes

| | PROMPT | GLAZE |
|---|---|---|
| Colour | cyan | magenta |
| Nature | gets the job done no matter what | barter, charm, influence |
| Walk / idle | Animazoo gangster walk / hands on hips | Animazoo walking waving / talking gesturing |
| Run | Animazoo Running - Jog (shared) | same |

Both are minimal stick figures (vertices and edges) driven by LIB_MOCAP clips. You play
one of them; the other follows along LIB_MAP paths; TAB switches between them.

Animazoo motion has no stated licence and is for local use only. Before anything ships,
replace these clips with CMU clips (from the LIB_MOCAP iGame3D/FreeBVH sets, which need
credit) or with our own captures.

## Episodes

| Episode | Engine | File | State |
|---|---|---|---|
| The Maze: a 1-bit generated vector maze where both heroes reach the gold beacon | Vibecode3D | `vibecode3d/Vibecode3D_Play_Heroes.livecodescript` | playable |

Planned: skills that do something (GLAZE barters, charms and influences; PROMPT forces
through), each episode carried over to xt3d, and the heroes visiting the other game
concepts.

## Layout

- `vibecode3d/`: card scripts for the Vibecode3D stack. Paste one into a card the way
  LIB_GAMES describes ("Putting a game into the stack").
- Shared code stays in the libraries. This project only uses it:
  `../LIB_BIT` (Bit.Maze), `../LIB_MAP` (paths, edges) and `../LIB_MOCAP/library`
  (clips). Scripts find these with FindFile, which looks in the folders above the stack
  and then in `//wsl$/Ubuntu/home/igame3d/projects/`.

## History

Started on the LIB_GAMES `prompt-glaze` branch and moved here on 2026-11-12, with its
commits.

Git: main holds what has been reviewed; each new episode gets its own branch and is
merged after review.
