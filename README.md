# CPlanets

`CPlanets` is a territory game where a player tries to conquer the playing space by outmaneuvering all opponents. Opponents can be any mix of robotic or human players. Play is **policy-based** on a server-driven real-time tick: you update allocations and fleet orders whenever you want, the server advances the galaxy on a configurable cadence, and you read a digest of events between looks. The idea for this game is loosely inspired by the 1990's Macintosh game Spaceward HO! by Delta Tao Software. 

The playing field is an array of "planets", called a "galaxy", where the planets have different attributes that are based upon their livability and available resources. A player expends resources on planets to increase livability while resources are used up. The player wins by exploring them and using their available resources wisely. 

A player has attributes such as wealth, power, experience, and technology level. Players compete based upon these attributes and the attributes change as a result of game play. Detection range and the chance to identify an attacker scale with capability (technology / attributes); exploration reveals rocks inside current range without extending it. Some planets are efficient in increasing some player attributes and inefficient at others. A planet's value and desirability is based on its efficiency. As a player gains in wealth and technology, range and options grow. (Whether livability / power / experience drive ticks beyond display is still open in the rules.)

A player uses a fleet of ships to explore and conquer the galaxy. Named classes (scout through colony) are default designs; a player can set their own mix of speed, range, weapons, shields, and size, pay a **development** cost (mostly wealth) once, then **produce** hulls (mostly resources) until they are reclaimed at a shipyard (setup percent of production resources). Ships already built keep their stats. Any fleet can be recalled before it arrives. 

Players can form **player–player** trade agreements and broadcast messages and send messages directly to other players. Freighters cycle full both ways (plus escorts); war fleets stay until moved. Attacking a partner ends trade and can confiscate inbound ships; identify chance for origin and/or actor scales with attributes. Unowned rocks fall without a fight; parked ships and defenses still fight. Taking a planet requires a surviving colony before it produces; mixed fleets matter in combat. Roles (neutral, conqueror, pirate, trader, hermit) retune how wealth becomes worlds, resources, and technology. A closed game (v1 default) ends when one player has eliminated all others. An ongoing map that continues without any one player is a future model; new players get a sandbox until they make contact. Magnitudes live in a scenario setup file that an admin edits and that locks once play starts. Working rules are in [doc/RULES.md](doc/RULES.md). That file is the spec if it disagrees with this overview. 

## User interface

The planet grid is a computer generated graphic with "hot spots" for planets. A player has the ability to detect planets according to their technology level, and at first, there are planets that are out of detection range. A player sends ships to a planet by clicking on it. While ships are in transit, a dotted line connects the planet that they were sent from and the progress of the ship. When the ship arrives, the line disappears and is replaced by a different graphic. The status of a planet is given by its color. Green means that it is settled and does not have any problems, red means that it has been taken by another player. Colors between that give the current status of the planet between those extremes. Players can pan and zoom the playing field and to see areas more clearly of get an overview of the field. To do things like change a planet's budget, the player clicks on it and selects menu options. Settings are in general controlled with sliders.

## Multi-player

The game is a multi-player game that can also be played stand-alone; stand-alone and online share the same server clock. A **server** executable owns the universe and calls `tick` on a configurable real-time period; **human** and **AI** clients talk to it over TCP with a REST-shaped protocol (no HTTP server in v1; compressed binary on a local network). Clients update policy anytime and read the published digest — they never tick. A formal REST façade may come later. Players can join the game before play begins; AFK keeps the last policy, with timeout shrink in real time and/or tick period until they return. 

## Building and Installation

This directory contains the shared machine in `src/lib/` (scenario,
seeded RNG, start galaxy, empire pools, pure tick core, take/colony
combat stub, trade agreements / cycle, pirate midpoint ambush /
identify), stub executables (`cplanets-server`, `cplanets`,
`cplanets-ai`, `cplanets-tick`), the closed default setup text in
`scenarios/`, tests in `tests/`, and SDK discovery helpers in
`scripts/`.

With a current Cwhip SDK installed, run `scripts/setup [--clean] [debug|release|profile]`
from the checkout, then `build` in the project shell. Use `rebuild` for a
clean-first build, or `clean` to remove generated outputs; exit the shell before
running setup again.

```sh
./scripts/setup [--clean] [debug|release|profile]
build
../bin/cplanets-tick
```

- [Game rules and machine](doc/RULES.md)
- [Implementation plan](doc/PLAN.md)
- [Building](doc/BUILDING.md)
- [Syntax](doc/SYNTAX.md)
- [Project shell](doc/PROJECT-SHELL.md)
- [Changelog](doc/CHANGELOG.md)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
