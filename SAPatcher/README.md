# SAPatcher
This program will patch your Spartan Assault binary (only v1.1.1 supported for now) to enable profile login and achievements unlock so you won't need to always fiddle with a proxy server to play and earn achievements.

Additionally this will also fix the previously unobtainable 5 achievements to be obtainable once again.

***A write up detailing the fix and how it was found is available [here](https://github.com/brkzlr/SASSFix/blob/master/SAPatcher/WRITEUP.md).***

## Update 2026/05/04
As of a few days ago, Microsoft has started blocking the `XBL2.0` token authorization flow which both SA and SS used, effectively breaking the login for these games once again.

You will now need to use the new ***`SASSInterceptV2.py`*** mitmproxy script to be able to login to both games, ***including patched iOS SA***. More info **[here](https://github.com/brkzlr/SASSFix/blob/master/Proxy/README.md)**.

**Note: You now only need this patcher if you're interested in obtaining the 5 unobtainable achievements in the iOS version, as the login fix included in this patch is now obsolete. If you don't care about the 5 achievements for whatever reason and just want to be able to login again, you can skip this and just use the Proxy way.**

## Usage
Head over to [Releases](https://github.com/brkzlr/SASSFix/releases) and grab the latest version for your OS and architecture.

### Patching an IPA
If you already have the `.IPA` file of SA v1.1.1, this is the easiest way.
- Put the patcher and your `.IPA` file in the same folder.
- Open a terminal/command prompt in that folder.
- Run the patcher with the `.IPA` file as the input.
- Linux/MacOS: `./SAPatcher "Halo - Spartan Assault.ipa"`
  - If you downloaded the patcher from Releases instead of building it yourself, you might have to `chmod +x SAPatcher` first.
- Windows: `SAPatcher.exe "Halo - Spartan Assault.ipa"`
  - On Windows 11, you might have Powershell as default instead of command prompt, in which case you need to type `.\SAPatcher.exe "Halo - Spartan Assault.ipa"` instead.

This should produce a new file ending with `-patched.ipa` next to the original IPA. Install that IPA file using your preferred installation method.

***Make sure the IPA has a decrypted `Game` binary inside. If you got the IPA directly from the App Store, it will probably still contain Apple's FairPlay DRM and won't patch.***

Instructions on how to dump or install IPA files are out of scope, plenty of tutorials and methods are available if you look it up on Google.

### Patching the Game binary manually
You can still patch the `Game` binary directly if you have the game already installed and your iPhone is jailbroken.
- Go to the game installation folder and inside `Game.app` you should find another file simply called `Game`.
- Transfer this file to your PC/Laptop by using scp/Filza/USB transfer/etc..., up to you how you bring that file over to your PC.
  - ***Make sure that this binary is decrypted first if you got it directly from the App Store as it will contain Apple's FairPlay DRM***.
  - How to do this is out of this guide's scope so it's on you to find out how, but you can look into DumpDecrypt or TrollDecrypt.
- Put the `Game` file next to your patcher.
- Open a terminal/command prompt in the folder where the patcher and binary is and then run the following:
  - Linux/MacOS: `./SAPatcher Game`
  - Windows: `SAPatcher.exe Game`
    - On Windows 11, you might have Powershell as default instead of command prompt, in which case you need to type `.\SAPatcher.exe Game` instead.

This should produce a `GamePatched` binary next to where the patcher is. Copy `GamePatched` back to where you got the original `Game` from and rename it to `Game`.

## Build
You don't need to build the patcher yourself if there's already a prebuilt package for your OS/Arch combo in [Releases](https://github.com/brkzlr/SASSFix/releases).

You'll need [Zig](https://ziglang.org/download/) to compile the source code into the patcher executable. Once you have it installed, simply run the following in the SAPatcher folder:
```
zig build-exe -O ReleaseFast SAPatcher.zig
```
