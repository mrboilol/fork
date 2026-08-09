based on remorseism by kazoo
content https://steamcommunity.com/sharedfiles/filedetails/?id=3493194513&savesuccess=1
DO NOT USE THIS FOR YOUR OWN "PUBLIC" SERVER WITHOUT MY PERMISSION, please

## Cherry-pick recovery note

The August 8, 2026 batch cherry-pick dropped core files that later code still depends on. The CAI runtime, Homigrad utility/fake/appearance modules, attachment registry, weapon-base modules, base SWEPs, and `projectile_base` were recovered to stop the downstream nil/base-registration cascade.

The weapon base also owns the shared manual-action API used by reload and jam handling. Every ballistic `Primary.Ammo` declared by a Homigrad weapon must have matching ammo and ammo-entity entries in `sh_ammostuff.lua`; firing validates `BulletSettings` before entering the shot pipeline. Single-projectile shots follow the resolved live muzzle ray without an additional random accuracy cone, while multi-pellet ammunition retains its configured spread. Successful shots perform the server jam roll; once jammed, trigger attempts are blocked and play `jam.ogg` until the weapon is cleared. Ammo HUD modes stay anchored to the live muzzle position; the replicated `hg_weirdmags` convar selects block magazines (`1`) or bullet icons (`0`).

The organism subsystem uses this repository's last pre-batch snapshot, commit `959d1868`, as its compatibility source of truth. Its server modules keep the original names `sv_blood.lua`, `sv_lungs.lua`, and `sv_pain.lua`. Do not replace them with Judge's overlapping `sv_circulation.lua`, `sv_respiration.lua`, or `sv_physical.lua`; those files register the same module owners and create a mixed-generation organism runtime.

The organism stamina module depends on the shared `hg.GetCarryWeight` utility. Keep raw carried-weight calculation in `sh_utility.lua`, and keep manual armor hitboxes synchronized with the live armor IDs in `sh_armorstuff.lua`; removed armor IDs must not remain as load-time protection lookups.

Pickup discovery and Alt targeting are owned by `sh_pickup_selector.lua`. Its shared eligibility check mirrors the manual weapon exclusions and the 14 kg `PlayerUse` limit; the client only selects and displays candidates, while `FindUseEntity` consumes the server-validated target.

Blood-dependent organism stats use continuous formulas rather than lookup tables. Oxygen capacity, perfusion, pulse, cardiac output, and the normalized delivery stats reach exactly zero at the shared 2000 mL terminal threshold; raw blood volume owns that lethal cutoff and resilience effects cannot move it. A patient at 3000 mL is severely weakened but must retain enough myocardial oxygen and circulation to avoid a blood-loss-only death spiral.

Dying modes 6 (`fuck.mp3`) and 10 (`itshopeless.mp3`) share persistent playback channels with OTRUB modes 6 and 7, respectively, so losing consciousness changes volume without restarting the track. The Homigrad weapon base also keeps per-shot muzzle offsets and a damped recoil-wobble tail in the rendered weapon pose. Underwater respiration is reserve-based: loss of intake drains existing tissue oxygen instead of zeroing brain oxygen, while back armor with `underwaterOxygen = true` (currently the aqualung) continues feeding the current O2, body-oxygen, and brain-oxygen model.

Hypothermia uses a central-survival response from 35 C toward full effect near 30 C: shivering initially raises oxygen demand, deeper cooling reduces it, and blood flow is diverted away from limbs and whole-body perfusion to preserve cerebral and myocardial oxygen. This response never bypasses failed breathing, absent circulation, traumatic penalties, or the 2000 mL terminal blood threshold; deep-cold arrhythmia and arrest remain lethal risks.

Hemothorax progression is owned by `sv_lungs.lua`: thoracic organ damage guarantees a slow pleural complication, while unrelated internal bleeding gets one severity-scaled risk roll per bleeding episode. Concussion and its post-concussion tail use the faster recovery constants in `sv_trauma.lua`.
