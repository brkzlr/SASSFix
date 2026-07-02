# SAPatcher
This program will patch your Spartan Assault binary (only v1.1.1 supported for now) to enable profile login and achievements unlock so you won't need to always fiddle with a proxy server to play and earn achievements.

Additionally this will also fix the previously unobtainable 5 achievements to be obtainable once again.

***A write up detailing the fix and how it was found is available [here](https://github.com/brkzlr/SASSFix/blob/master/SAPatcher/WRITEUP.md).***

## Update 2026/05/04
~~As of a few days ago, Microsoft has started blocking the `XBL2.0` token authorization flow which both SA and SS used, effectively breaking the login for these games once again.~~

~~You will now need to use the new ***`SASSInterceptV2.py`*** mitmproxy script to be able to login to both games, ***including patched iOS SA***. More info **[here](https://github.com/brkzlr/SASSFix/blob/master/Proxy/README.md)**.~~

~~**Note: You now only need this patcher if you're interested in obtaining the 5 unobtainable achievements in the iOS version, as the login fix included in this patch is now obsolete. If you don't care about the 5 achievements for whatever reason and just want to be able to login again, you can skip this and just use the Proxy way.**~~

No longer relevant as of the v3 patcher, because the new proxy fix is integrated into the patch.

## Usage
Head over to [Releases](https://github.com/brkzlr/SASSFix/releases) and grab the latest version zip package for your OS and architecture.

The patcher package now contains two required files for IPA patching:
- `SAPatcher`/`SAPatcher.exe`: the patcher executable.
- `SASSFix.dylib`: the in-app login hook that gets added to the IPA.

Keep `SASSFix.dylib` next to the patcher executable. IPA patching will fail if the dylib is missing or renamed.

### Patching an IPA
***Make sure the IPA has a decrypted `Game` binary inside. If you got the IPA directly from the App Store, it will probably still contain Apple's FairPlay DRM and won't patch.***
If you got it directly from a website, it's most likely decrypted already.
- Put the patcher, `SASSFix.dylib` and your `.IPA` file in the same folder.
- Open a terminal/command prompt in that folder.
- Run the patcher with the `.IPA` file as the input:
    - Linux/MacOS: `./SAPatcher "Halo - Spartan Assault.ipa"` (or whatever is the name of the IPA file)
      - If you downloaded the patcher from Releases instead of building it yourself, you might have to `chmod +x SAPatcher` first.
    - Windows: `SAPatcher.exe "Halo - Spartan Assault.ipa"` (or whatever is the name of the IPA file)
      - On Windows 11, you might have Powershell as default instead of command prompt, in which case you need to type `.\SAPatcher.exe "Halo - Spartan Assault.ipa"` instead.

This should produce a new file ending with `-patched.ipa` next to the original IPA. The new IPA contains both the patched `Game` binary and `Payload/Game.app/Frameworks/SASSFix.dylib`. Install that IPA file using your preferred installation method.

*Instructions on how to install IPA files are out of scope, plenty of tutorials and methods are available if you look it up on Google.*

### What if I already have the game installed on a jailbroken device?
You can still use the normal IPA patching method above and install the patched IPA. If you want to keep your existing installation and avoid uninstalling/reinstalling the game, patch an IPA first and then copy the patched files out of it. This is useful because uninstalling and reinstalling the IPA can wipe your game save.
- Patch the IPA using the instructions above.
- Rename the patched IPA extension to `.zip` and extract it.
- In the extracted folder, find `Payload/Game.app/Game` and `Payload/Game.app/Frameworks/SASSFix.dylib`.
- On your device, open the installed game's `Game.app` folder using Filza, SSH or whatever file manager you prefer.
- Replace the existing `Game` file with the patched `Game` file from the extracted IPA.
- Open the `Frameworks` folder inside `Game.app`. If it does not exist, create it.
- Copy `SASSFix.dylib` into that `Frameworks` folder.
- Make sure both `Game` and `SASSFix.dylib` are executable. In Filza, this means the files need Read + Execute enabled for everyone and Write enabled for the owner. If using SSH, run `chmod 755 Game Frameworks/SASSFix.dylib` from inside `Game.app`.

**Note: Running the patcher directly on a standalone `Game` binary still works for the static Spartan Assault binary patch and writes `GamePatched`, but it does not add `SASSFix.dylib`. This means that you'll need to run the proxy server together with the patch to login. For the full current login fix, use a patched IPA as the source for both files so you skip the need for a proxy.**

## Build
You don't need to build the patcher yourself if there's already a prebuilt package for your OS/Arch combo in [Releases](https://github.com/brkzlr/SASSFix/releases).

You'll need [Zig](https://ziglang.org/download/) to compile the source code into the patcher executable.
```
zig build-exe -O ReleaseFast SAPatcher.zig
```

To build `SASSFix.dylib`, you need MacOS with Xcode and an iPhoneOS SDK:
```
sh build_hook.sh
```

`build_hook.sh` always tries to build `arm64` and will also build `armv7` if your installed iPhoneOS SDK still supports it. If both builds succeed, it creates a fat `SASSFix.dylib` containing `armv7` and `arm64`, otherwise it falls back to an `arm64` only dylib.

For a full local build from the `SAPatcher` folder:
```
sh build_hook.sh
zig build-exe -O ReleaseFast SAPatcher.zig
```

Keep the generated `SASSFix.dylib` next to the generated `SAPatcher` executable when patching IPAs.
