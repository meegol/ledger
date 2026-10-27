# Ledger

A pixel-art merchant sim made in Godot 4.7. You run a market stall where prices move like a real market. Buy stock on the wholesale board, sell to whoever walks up, and pay the landlord every seven days. The rent goes up every time.

**[Play it in the browser](https://ledger-merchant.vercel.app)**

## How it plays

- **Market:** eight goods, each with a fair price. Every in-game hour the live price moves part of the way toward fair, plus some random noise. You buy at the ask and sell back at the bid, so trading back and forth costs you the spread.
- **Rumours:** each evening the square talks about tomorrow: a dragon, raiders, plague, a festival, a storm, a silver rush, a blood moon, a caravan, a royal wedding. Most rumours come true, but not all. Events change fair prices and foot traffic, so stocking up on the right rumour is where the money is.
- **Customers:** offer a price for some quantity. You can sell, haggle (they may walk off) or refuse. Overcharging hurts your reputation.
- **Night customers (after 20:00):**
  - **Vampire:** pays well. Refuse and it bites you, and you lose 90 minutes.
  - **Ghost:** pays triple in ghost gold. Only 20–80% of it survives sunrise.
  - **Wolf:** can't pay, but if you feed it meat it guards your next raid. Refuse and it steals something.
- **Raids:** raiders come for your strongbox at night. Click them to fight them off. Hit one while it runs away and you get the stolen gold back.
- **Angry mob:** if your reputation drops below 30, a mob can turn up during the day. You can pay them off, hand out goods, or chase them off in the same click-to-defend minigame.
- **Tavern:** Bones dice with an old gambler, open from 18:00. Ties go to the house; snake eyes pays 5x.
- **Ledger:** the board shows your average buy price for everything you hold, in green or red depending on whether selling back now would make or lose money. Customer offers show the profit or loss before you accept, and the buy button shows how a purchase would change your average.
- **Saving:** the game autosaves every in-game hour and each morning. Continue from the title screen.
- **Sleep:** you can go to bed from 18:00. If you're still up at midnight you pass out in the street: pickpockets take a quarter of your gold and you wake late.

## Run

```sh
godot --path .                     # play
godot --headless --script tests/run_tests.gd     # rule tests
godot --headless --script tests/balance_sim.gd   # bot playthroughs, survival stats
godot --path . -- --ledger=raid    # jump to a scene: day, night, raid, mob, dice, report
```

## Layout

- `scripts/core/game.gd`: all game rules (clock, money, ledger, customers, events, rent). It doesn't touch any nodes, so it can be tested headless.
- `scripts/core/market.gd`: the price model.
- `scripts/data/`: goods, events and visitor tables.
- `scripts/main.gd`: the stall scene and its windows.
- `scripts/ui/raid.gd`: the raid and mob minigame.
- `scripts/ui/dice_table.gd`: the tavern dice game.

## Credits

Art, music and sound: [Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by Pixel-boy and AAA, released as CC0. See `CREDITS.md`.
