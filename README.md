# This project is shared under a GNU AGPL-3 license. Head over to the "License" page for more information
# Z-City
Z-City is a GMod addon which modifies character damage and controls. Z-City also comes with its own weapon base and a gamemode

## Support us
**Donation links:**
- [Yoomoney](https://yoomoney.ru/fundraise/17GFEQH326Q.250101) 
- [Boosty](https://boosty.to/sadsalat/donate)

**Crypto**
- USDT(TRC20): TYgpaZgHQr6qEgemhHzVvV7AQESiyhHpZD
- BTC(BTC): bc1qa8pk9ag6xa5yav2mvlxkra8xk25lg3htgfqh5w
- ETH(ERC20)* 0x72AdCCcCEB4E323C64bCF0955A779DD9298E9483

## Other information 
- https://steamcommunity.com/sharedfiles/filedetails/?id=3657285193 - Steam Workshop link (stable version)
- https://github.com/uzelezz123/8bit_zcity - 8bit module (compiled version is in lua/bin)

## Ballistic ammunition
Held-weapon collision tracing includes animated weapon hitboxes and rendered modular parts, including their installed magazine and stock models. The same equipment trace serves bullets and contact attacks. Synthetic arm bounds yield to equipment inside them; actual body hits and intervening walls still take priority. Physical bullets are enabled on player spawn, with a chat confirmation once the projectile and equipment trace functions are available. Bullet removal reliably sends the server endpoint to clients.

Collision changes should be checked in Garry's Mod with single shots and buckshot against a held receiver, magazine, and stock; hands beside the weapon; a weapon in front of a wall; melee contact; and a ragdoll holding a gun. Verify that blocked shots leave the organism undamaged, shots missing the weapon still damage the body, and respawning displays the physical-bullet confirmation. Restart the server and reconnect clients after changes to the bullet network messages.

Weapon-base projectiles pass their complete per-shot ballistic profile into organism damage. `BulletSettings` damage, diameter, penetration, speed, and mass drive bleeding, pain, permanent and temporary wound channels, organ grazing, structural damage, and retained energy. Specialized ammunition can override `TissueDamage`, `TemporaryCavity`, `ExpansionMultiplier`, `ExpansionRadius`, `ExpansionChance`, `NearbyDamageMul`, `GrazeDamageMul`, `WoundMultiplier`, `PainMultiplier`, `DestructiveMultiplier`, `EnergyRetention`, and `BulletFragmentation`.

Recoil uses the ammunition's force, mass, velocity, energy, diameter, and projectile count together with the weapon's weight and action. Weapon mass strongly reduces immediate kick, while powerful ammunition still increases post-shot sway, stability recovery, and aim-alignment time.

## Persistent organism blood
Organism wounds keep a separate networked visual record from active bleeding, so clotting, bandaging, tourniquets, death, and player or NPC ragdoll transitions do not erase wound marks. Blood that lands on an organism is also anchored to its skeleton. Old marks gradually darken and fade to a visible minimum instead of disappearing.

## Hemorrhage treatment
Tourniquets suppress all current and future external bleeding across their treated limb, including arterial wounds anywhere on that limb. Two tourniquets can be stacked while a wound remains, but cause severe arm effectiveness or leg movement and dragging penalties. Bandages continue protecting their covered bone after application: later venous and arterial wounds at that location bleed less and clot faster.

## Trip inertia
Terrain trips preserve the player's incoming center-of-mass velocity when converting to a ragdoll. Low obstacles and gaps pitch the body forward, while low-friction slips and high wall impacts pitch it backward without replacing forward momentum with a scripted shove.

Optional Discord RPC module for clients:
1. https://github.com/YuRaNnNzZZ/gmcl_steamrichpresencer/releases/tag/2023.07.20 - Steam Rich Presence
2. https://github.com/fluffy-servers/gmod-discord-rpc/releases/tag/1.2.1 - Discord Rich Presence


## Current version in the repository is 1.4.1
### The numbers in the version number indicate:
A.Bcc -> 1.000
- A -> Global updates
- B -> New mechanics, gameplay changes
- c -> Fixes and other small things
