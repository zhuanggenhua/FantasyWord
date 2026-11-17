# Character command gate slice

Source: locked Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`, `CharacterCommandExecutor.cs` and `PlayerCommandRequest.cs`; base Godot `d409494`.

The real opt-in ClickMoveTest entry now creates a command router alongside its same-owner interaction resolver. `submit_human_command` checks existing actor ownership, explicit current input-target selection and accepts/capability gates (no selection returns MissingInputTarget; fallback player identity alone is insufficient); then the router preserves character → enabled → actor → dispatch validation. Explicit interaction targets cannot bypass `CanInteractNow`'s character action gate. No receiver returns BlockedByState, not success.

Fire checks the actual resolver's same-frame interaction latch before building activation context or invoking the slot. StopFire bypasses that latch. Source result order is HasAbilitySource → Valid result → rejection event. The default ability index is -1, not slot 0. Movement delegates to the existing movement executor. OpenGameMenu is still unsupported, rather than emitting an invented menu event.

## Explicit remaining formal host boundary

`bind_abilities` requires four real host adapters: fire(index, original command context, activation context), stop(index), activation-context builder(request), and failure notification(code, result). Fire returns `has_ability_source`, `result` (source Valid = 0), and `formal_gas_ability_code`. This module does **not** implement GAS, equipment selection, eligibility, activation-context construction, or effects. An unbound Fire/Stop returns InvalidCommand (unsupported migration slice), not fabricated MissingAbility. Tests inject a visibly synthetic result provider to prove routing only.

The request `actor` is the resolved projection of `GameCommandContext.Actor`, never an independent override. A dictionary `command_context.actor` is authoritative; contradictory projections are rejected. An opaque source context must be projected by its owning adapter. Target/direction/world position fields pass intact into the activation-context adapter. No input map, keyboard alias, target cell or direction is guessed here.

The existing raw movement path and diagnostic unified attack fixture remain compatible. This stage adds an executable command submission path to the real opt-in Human entry; it does not claim a complete input-to-GAS/gameplay pipeline or visual equivalence. Entry stop detaches both command router and resolver. Source interaction refresh/reset remains the only latch reset owner.
