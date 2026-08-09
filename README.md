based on remorseism by kazoo
content https://steamcommunity.com/sharedfiles/filedetails/?id=3493194513&savesuccess=1
DO NOT USE THIS FOR YOUR OWN "PUBLIC" SERVER WITHOUT MY PERMISSION, please

## Cherry-pick recovery note

The August 8, 2026 batch cherry-pick dropped core files that later code still depends on. The CAI runtime, Homigrad utility/fake/appearance modules, attachment registry, weapon-base modules, base SWEPs, and `projectile_base` were recovered to stop the downstream nil/base-registration cascade.

The organism subsystem uses this repository's last pre-batch snapshot, commit `959d1868`, as its compatibility source of truth. Its server modules keep the original names `sv_blood.lua`, `sv_lungs.lua`, and `sv_pain.lua`. Do not replace them with Judge's overlapping `sv_circulation.lua`, `sv_respiration.lua`, or `sv_physical.lua`; those files register the same module owners and create a mixed-generation organism runtime.
