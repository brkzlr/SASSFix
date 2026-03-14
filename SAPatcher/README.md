# SAPatcher
This program will patch your Spartan Assault binary (only v1.1.1 supported for now) to enable profile login and achievements unlock so you won't need to always fiddle with a proxy server to play and earn achievements.

Additionally this will also fix the previously unobtainable 5 achievements to be obtainable once again.

***A write up detailing the fix and how it was found is available [here](https://github.com/brkzlr/SASSFix/blob/master/SAPatcher/WRITEUP.md).***

## Build
**You can skip this step if there's already a prebuilt package for your OS/Arch combo in [Releases](https://github.com/brkzlr/SASSFix/releases)**

You'll need [Zig](https://ziglang.org/download/) to compile the source code into the patcher executable. Once you have it installed, simply run the following in the SAPatcher folder:
```
zig build-exe -O ReleaseFast SAPatcher.zig
```

## Usage
Head over to [Releases](https://github.com/brkzlr/SASSFix/releases) and grab the latest version for your OS and architecture.

### Prep
Once you have the patcher downloaded, we'll need to do some prep beforehand to grab the main executable from inside the application.

If you have the game already installed and your iPhone is jailbroken, you can go to the game installation folder and inside Game.app you should find another file simply called `Game`.
- You'll have to transfer this file to your PC/Laptop by using scp/Filza/USB transfer/etc..., up to you how you bring that file over to your PC.
  - ***Make sure that this binary is decrypted first if you got it directly from the App Store as it will contain Apple's FairPlay DRM***.
  - How to do this is out of this guide's scope so it's on you to find out how, but you can look into DumpDecrypt or TrollDecrypt.

If you don't have a jailbroken iPhone or the game is not yet installed but have the `.IPA` file of SA v1.1.1, then you can do the following to extract the binary:
- Rename the `.IPA` file to have the extension `.zip`.
- Unzip the archive.
- After extraction, you should probably have 2 files and 2 folders, but we only care about the `Payload` folder.
- Inside you'll find another folder called `Game.app`, go inside.
  - On MacOS, this will simply be called `Game` and have an icon. You'll have to right click on it and choose "Show Package Contents" to explore inside.
- Copy or move the file called `Game` inside to where the patcher is.

### Patching
Once you have the `Game` file next to your patcher, open a terminal/command prompt in the folder where the patcher and binary is and then run the following:
- Linux/MacOS: `./SAPatcher Game`
  - If you downloaded the patcher from Releases instead of building it yourself, you might have to `chmod +x SAPatcher` first.
- Windows: `SAPatcher.exe Game`
  - On Windows 11, you might have Powershell as default instead of command prompt, in which case you need to type `.\SAPatcher.exe Game` instead.

This should produce a `GamePatched` binary next to where the patcher is. If you simply copied/transferred `Game` from an installed copy on a jailbroken iPhone, just simply copy back `GamePatched` and rename it to `Game`.

Otherwise if you're using the IPA, follow the steps below.

### Re-packaging
- Copy the `GamePatched` binary back to where you got the original `Game` from.
- Delete existing `Game` file if any exists and rename `GamePatched` to `Game`.
- Package the `Payload` folder and any accompanying file/folder that it came with into a zip file.
  - On MacOS/Linux, you can simply run `zip -qr Halo-SA-FIXED.ipa *` from a terminal in the folder where `Payload` and the others are.
  - On Windows, you'll have to use your favourite zipping program to zip up `Payload` and the neighbouring files/folders.
- Rename the `.zip` extension to `.ipa`.
- Install the IPA file using your preferred installation method.
  - Instructions on how to do this are out of scope, plenty of tutorials and methods available if you look it up on Google.
