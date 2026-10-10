# Controller Crossbar Swap

> **AI disclaimer:** this addon is developed with the help of AI coding tools. All code is reviewed and tested in the game by a human, but use it at your own risk.

**Swap your controller crossbar with a tap.** For the controller UI of **World of Warcraft Forever**.

With Blizzard's controller UI you only get your LT, RT and LT+RT bars while you **hold** the triggers. Controller Crossbar Swap lets you **tap** a trigger to switch to another bar, and it stays there. You can also have the selected bar rotate into the main position. Everything else looks and works like Blizzard's own crossbar.

> **Status:** early version (0.3), made for the World of Warcraft Forever beta. Works with Xbox controllers and on the Steam Deck; PlayStation button layouts are planned.

## Features

- **Tap to swap bars:** tap RT to switch to the next bar (default → RT → LT+RT → LT), or tap LT to go the other way. The bar stays selected until you tap again, so you can use its abilities without holding a trigger.
- **Hold still works:** hold LT, RT or LT+RT to use that bar for as long as you hold it, just like the default UI.
- **Rotate into the main position (optional):** the selected bar moves to the top-centre position and the other bars rotate around it, with a smooth animation.
- **Never lose your default bar:** an icon marks your default bar, and it can switch back automatically when a fight ends.
- **Looks like the default crossbar:** the same layout, buttons and art as Blizzard's crossbar, in the same place on your screen. You can make the bars you're not using smaller.
- **Uses your existing bars:** it shows the abilities you placed with Blizzard's own controller bar editor, so there's nothing to set up again.
- **Works in combat:** swapping, rotating and resizing all work mid-fight.

## Options

Open the options with **`/ccs options`**, or from the game menu: **Options → AddOns → Controller Crossbar Swap → Open options window**. With a controller, press **Y** on that page.

In the options window, use the D-pad to move, A to change a setting and B to close. The mouse works too.

| Option | What it does | Default |
|---|---|---|
| Revert to default bar after combat | When a fight ends, switch back to your default bar | Off |
| Rotate bars into the main position | Tapping LT/RT moves the selected bar into the top-centre position, and the other bars rotate around it | Off |
| ↳ Animate bar rotation | Bars glide to their new position instead of jumping | On |
| Highlight the default bar | Shows an icon above your default bar, so you can always find it | On |
| ↳ Default bar icon | Choose the icon: gold star, page badge, raid markers (star, diamond, skull), checkmark or gold crest | Gold star |
| Size of inactive bars | Make the bars you're not using smaller: Normal, Small or Smaller | Normal |

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

To place abilities on the bars, use Blizzard's own controller bar editor as usual.

## Good to know

- **Blizzard's own crossbar is hidden** while the addon is active.
- **LT and RT act as Shift and Ctrl** while the addon is active, which is how holding a trigger selects a bar. This is undone when you switch back to keyboard and mouse.
- **The LT/RT labels under the bars are hidden** while "Rotate bars" is on, because the bars no longer stay in their fixed spots.

## Not supported yet

- Blizzard's extra bar pages: only the first page is shown.
- Stance, shapeshift, possess and vehicle bars.
- PlayStation button layouts (symbols and button art).

## Feedback

Found a bug or have an idea? Open an issue on [GitHub](https://github.com/mikevromen/ControllerCrossbarSwap/issues).
