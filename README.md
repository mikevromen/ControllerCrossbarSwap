# Controller Crossbar Swap

> **AI disclaimer:** this addon is developed with the help of AI coding tools. All code is reviewed and tested in the game by a human, but use it at your own risk.

**Swap your controller crossbar with a tap.** For the controller UI of **World of Warcraft Forever**.

With Blizzard's controller UI you only get your LT, RT and LT+RT bars while you **hold** the triggers. Controller Crossbar Swap lets you **tap** a trigger to switch to another bar, and it stays there. You can also have the selected bar rotate into the main position. Everything else looks and works like Blizzard's own crossbar.

> **Status:** version 1.0, the first release, for World of Warcraft Forever. Works with Xbox controllers and on the Steam Deck; PlayStation button layouts are planned.

## Features

- **Tap to swap bars:** tap RT to switch to the next bar (default → RT → LT+RT → LT), or tap LT to go the other way. The bar stays selected until you tap again, so you can use its abilities without holding a trigger.
- **Hold still works:** hold LT, RT or LT+RT to use that bar for as long as you hold it, just like the default UI.
- **Rotate into the main position (optional):** the selected bar moves to the top-centre position and the other bars rotate around it, with a smooth animation.
- **Combat bar (optional):** switch to your fighting bar automatically when combat starts, and back to your default bar (loot, interact ...) when it ends.
- **Never lose your default bar:** an icon marks your default bar, and it can switch back automatically when a fight ends.
- **Bar icons:** give each bar its own icon (star, numbers, raid markers ...), so you can tell them apart at a glance.
- **Looks like the default crossbar:** the same layout, buttons and art as Blizzard's crossbar, in the same place on your screen. You can make the bars you're not using smaller.
- **Uses your existing bars:** it shows the abilities you placed with Blizzard's own controller bar editor, so there's nothing to set up again.
- **LB / RB targeting bars:** holding LB, RB or both still brings up Blizzard's friendly, hostile and shortcuts bars (party and raid targeting, raid markers, bags, chat ...), on whichever bar you have selected.
- **All three bar pages:** LB+RB + D-pad left/right switches pages like the default UI, and your bars follow.
- **Works in combat:** swapping, rotating and resizing all work mid-fight.

## Options

Open the options with **`/ccs options`**, or from the game menu: **Options → AddOns → Controller Crossbar Swap → Open options window**. With a controller, press **Y** on that page.

In the options window, use the D-pad to move, A to change a setting and B to close. The mouse works too.

| Option | What it does | Default |
|---|---|---|
| Bar when combat starts | Switch to the LT, RT or LT+RT bar (or the bar you last used in a fight) as soon as combat starts, so your fighting spells are on the main buttons | Off |
| ↳ Ignore default bar for last bar (experimental) | With "last bar", switching back to your default bar during a fight doesn't count. Still being tested | Off |
| Revert to default bar after combat | When a fight ends, switch back to your default bar | Off |
| Rotate bars into the main position | Tapping LT/RT moves the selected bar into the top-centre position, and the other bars rotate around it | Off |
| ↳ Animate bar rotation | Bars glide to their new position instead of jumping | On |
| Show bar icons | Shows an icon above your bars, so you can always find them | On |
| ↳ Default bar icon | Icon for the default bar: none, gold star, numbers 1–3, raid markers, crossed swords, sword, checkmark or gold crest | Gold star |
| ↳ LT / RT / LT+RT bar icon | The same choice for each of the other bars | None |
| Size of inactive bars | Make the bars you're not using smaller: Normal, Small or Smaller | Normal |
| LB / RB targeting bars | While you hold LB, RB or both, show Blizzard's friendly, hostile or shortcuts bar in the main position, like the default UI. Off keeps your own bar | On |

The options window can't be opened during combat, and it closes by itself if combat starts.

## Installation

1. Download the addon from GitHub (**Code → Download ZIP**) and unzip it.
2. Copy the `ControllerCrossbarSwap` folder from inside the zip into your game's AddOns folder, for example:
   `World of Warcraft\_classic_beta_\Interface\AddOns\ControllerCrossbarSwap`
3. Start the game and enable **Controller Crossbar Swap** in the AddOns list on the character select screen.
4. In game, turn on the controller UI: **Options → Gamepad → enable the gamepad interface**.

## Controls

| Input | Action |
|---|---|
| Tap RT / tap LT | Swap to the next / previous bar. It stays selected |
| D-pad and A/B/X/Y | Use the selected bar. On the default bar, A/B/X/Y keep Blizzard's Interact, Inspect, Back and Jump |
| Hold LT, RT or LT+RT + a button | Use that bar for as long as you hold the trigger |
| Hold LB, RB or LB+RB + a button | Blizzard's friendly targeting, hostile targeting or shortcuts bar, as in the default UI |
| Hold LB+RB + D-pad left / right | Switch bar page (1–3). Our bars follow when you release LB+RB; pages 2 and 3 show a "Page" label |

To place abilities on the bars, use Blizzard's own controller bar editor as usual.

## Good to know

- **Blizzard's own crossbar is hidden** while the addon is active.
- **LT and RT act as Shift and Ctrl** while the addon is active, which is how holding a trigger selects a bar. This is undone when you switch back to keyboard and mouse.
- **LB / RB bars show in Blizzard's crossbar position.** If you moved or rescaled our bars away from it, they appear there and not on top of your bars.
- **The LT/RT labels under the bars are hidden** while "Rotate bars" is on, because the bars no longer stay in their fixed spots.

## Not supported yet

- Stance, shapeshift, possess and vehicle bars.
- PlayStation button layouts (symbols and button art).

## Feedback

Found a bug or have an idea? Open an issue on [GitHub](https://github.com/mikevromen/WoWFControllerExtended/issues).
