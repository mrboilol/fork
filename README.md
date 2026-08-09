based on remorseism by kazoo
content https://steamcommunity.com/sharedfiles/filedetails/?id=3493194513&savesuccess=1
DO NOT USE THIS FOR YOUR OWN "PUBLIC" SERVER WITHOUT MY PERMISSION, please

## Cherry-pick recovery note

The August 8, 2026 batch cherry-pick dropped core files that later code still depends on. The CAI runtime, Homigrad utility/organism/fake/appearance modules, attachment registry, weapon-base modules, base SWEPs, and `projectile_base` were restored from the fetched `judge/main` source state. Keep those dependency owners when importing future Judge commits; deleting them produces a large downstream nil/base-registration cascade.
