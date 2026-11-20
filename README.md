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

## Foundations

PROMPT_GLAZE is the whole game. It will grow and get complicated. Each foundational game
we build elsewhere stays small and can be taught as a tutorial in its own engine demo
suite, and each one is also part of this whole: a skill, a level or a scene the heroes go
through.

| Foundational game | Where | Teaches | In PROMPT_GLAZE |
|---|---|---|---|
| Amazing Couple (`Play.Amazing_Couple`, formerly Heroes / Companions) | `LIB_GAMES/Vibecode3D_Games/Vibecode3D_Play_Amazing_Couple.livecodescript`: Vibecode3D, and the xt3d games bench | Third-person companions: mocap stick figures, a follower using path finding, TAB to swap, a 1-bit generated maze | The heroes, their walk and follow, the maze |

Next: give the skills something to do (GLAZE barters, charms and influences; PROMPT
forces through), then bring in the other foundational games (Antack, Thrmnlra, Canyon,
Hunter, GAD and more).

## Layout

- PROMPT_GLAZE's own code (the parts that join the foundations together) goes here as it
  is written. The foundational games stay in LIB_GAMES.
- Shared code stays in the libraries. This project only uses it:
  `../LIB_BIT` (Bit.Maze), `../LIB_MAP` (paths, edges) and `../LIB_MOCAP/library`
  (clips). Scripts find these with FindFile, which looks in the folders above the stack
  and then in `//wsl$/Ubuntu/home/igame3d/projects/`.

## History

Started on the LIB_GAMES `prompt-glaze` branch and moved here on 2026-11-12. That same day the
demo went back to LIB_GAMES as Amazing Couple; this repo keeps the early history.

Git: main holds what has been reviewed; each new episode gets its own branch and is
merged after review.

## Licence

MIT (see `LICENSE`), Copyright (c) 2026 xAction.
