# SASSFix
This project aims to fix Halo Spartan Assault and Spartan Strike for iOS in both a non-invasive (**Proxy**) way and binary modification (**SAPatcher**, only for SA) way.

For more information about each variant, feel free to check their respective README.md in the folders.

## Update 2026/05/04
As of a few days ago, Microsoft has started blocking the `XBL2.0` token authorization flow which both SA and SS used, effectively breaking the login for these games once again.

You will now need to use the new ***`SASSInterceptV2.py`*** mitmproxy script to be able to login to both games, ***including patched iOS SA***. More info **[here](https://github.com/brkzlr/SASSFix/blob/master/Proxy/README.md)**.

**Note: You now only need the SAPatcher if you're interested in obtaining the 5 unobtainable achievements in the iOS version of SA, as the login fix included in the patch is now obsolete. If you don't care about the 5 achievements for whatever reason and just want to be able to login again, you can skip this and just use the Proxy way.**

## What's wrong with the games?
The games started refusing Xbox profile login requests near the beginning of 2024, stopping people from being able to earn the iOS version of achievements for these multi-platform games.

These games were also delisted for a very long time from Apple's AppStore, way before the "server shutdown" of 2024, so on top of being very hard to grab a copy to play for yourself, they're also pretty buggy and crash prone, depending on your iOS version and iPhone model.

## Why did this happen?
What happened is that during the development of this game they used a deprecated Xbox Live URI endpoint, which near Xbox 360 sunset were shutdown, effectively breaking the games' login functionality which means no more shiny new achievements for your profile.

This endpoind is "https://services.xboxlive.com" which was used for profile login and achievement unlocking/status checking, but Microsoft now expects you to use:
- "https://profile.xboxlive.com" for profile login
- "https://achievements.xboxlive.com" for anything achievements related

## What's the fix for this?
The logical answer would be that the developers would have to push a new update changing the URLs used to the new ones to allow proper login and achievement unlocking again. The new versions support the same requests that were being sent to "services" before so the only thing to do would be to change the URLs, nothing else.

***That is until Microsoft kills these new versions too...***

But given that these games were delisted for a very long time, it's extremely unlikely the devs would push even a simple update like this.

Luckily, because the fix requires only changing some URLs, we can handle this ourselves by either patching the URLs used inside the binary (**SAPatcher**, only for SA) or using a proxy server (**Proxy**) to redirect the calls made by the iPhone to point to the new URLs.

Instructions on how to fix the games and the files necessary can be found in the respective folders, good luck Spartan!

## Is that all that's wrong with these games?
Additionally, Spartan Assault also has 5 unobtainable achievements in this iOS port, resulting in you being able to earn only 20 out of the 25 achievements that SA has for every platform it is on (yes, including iOS, they show up in lists). They are as following:
- **Pension Plan**: Earn 25000 XP throughout your career.
- **Weapon of Choice**: Score a kill with every handheld weapon.
- **Skull Combo**: Complete any mission with 2 skulls active.
- **Extra Credit**: Complete 75 mission specific challenges.
- **A for Effort**: Complete all Operation F mission challenges.

So even if you were able to login and earn achievements on this version of SA, you were stuck with a game you couldn't 100% on your profile.

***That was the case until now...***

Using the patcher I wrote inside the **SAPatcher** folder will also fix these 5 missing achievements to be finally obtainable for the first time since the iOS version released. Just to be clear, the patcher does not modify the requirements or tamper with the achievements in any way, it simply lets the game know it forgot about 5 achievements.

The game would always try to unlock these 5 achievements when you fulfilled the requirements, it's just that the game is suffering from Alzheimers and will forget about them on the way to unlock them.

## Will I get in trouble using these?
I doubt Microsoft will care that Halo fans are redirecting calls from old deprecated endpoints to the newer functioning ones, especially since they both work the same, to play some old, forgotten and delisted games for some achievements.

Having said this, use this on your own risk.

***Please bear in mind that using any of the methods from this repo might cause your profile to be banned or invalidated from achievement tracking websites, depending on their policy.*** AFAIK, TrueAchievements does consider both variants to violate their policy so this might earn you a ban from their website.

If you don't care about the achievement tracking websites and just want that nice and shiny 100% on your Xbox profile, feel free to go wild with these.
