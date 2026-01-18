# Technical Write Up
In this document I'll briefly go over my findings and what I did while reverse engineering the binary with Ghidra to discover the issue with the 5 unobtainable achievements in Spartan Assault iOS.

This is not meant to showcase all of the game's code or be used as a tutorial for reverse engineering, but merely to give an idea about what was wrong and spare me from having to copy paste explanations everywhere.

## TL;DR
343i/Vanguard forgot to add the 5 unobtainable achievement IDs to a table, which means that the game always tried to unlock these achievements when you did the requirements legitimately but missing IDs prevented the game from sending the Xbox Live request or showing them in-game.

## Recap
Spartan Assault on iOS has 5 out of its 25 achievements (on every platform) unobtainable, which are the following:
- **Pension Plan**: Earn 25000 XP throughout your career.
  - This has the ID 14 (0xE) on Xbox Live.
- **Weapon of Choice**: Score a kill with every handheld weapon.
  - This has the ID 16 (0x10) on Xbox Live.
- **Skull Combo**: Complete any mission with 2 skulls active.
  - This has the ID 18 (0x12) on Xbox Live.
- **Extra Credit**: Complete 75 mission specific challenges.
  - This has the ID 20 (0x14) on Xbox Live.
- **A for Effort**: Complete all Operation F mission challenges.
  - This has the ID 32 (0x20) on Xbox Live.
 
The game for some reason was always aware of all the 25 achievements on Apple's GameCenter achievement list and would unlock them there but the Xbox list are missing the 5 above, preventing them from unlocking on your Xbox profile.

This did give a hint that the achievements themselves are not broken and they work as intended given the Apple unlock. It's just that the game did not consider these valid for Xbox, even though they were.

## Deep Dive
The next logical step would be to try to find the functions that are responsible for unlocking achievements and see what's going on there.

Having already fixed the login and (earning) achievements of these games beforehand with the **Proxy** way, I booted Ghidra back up and searched for the old deprecated "https://services." URI string to find all the functions that deal with achievements and Xbox Live directly.

3 functions come up in the search: one deals with the profile login (hinted by appending `/users/me/id` to the URL) and the other 2 deal with achievements (by appending `/achievements/` in the URL).
Interestingly, the function at address `0x10040F4D4` (Ghidra address) differs slightly from the other achievement related function. In the decompilation, we can see the following:

<img width="600" height="1002" alt="image" src="https://github.com/user-attachments/assets/24139cb3-1d6b-4534-af9e-a1d973048f7f" />

This function seems to grab an ID and also write an `unlocked: true` field in JSON format, which makes me believe it's the main function responsible for sending the Xbox Live achievement unlock request.

We can also see the old deprecated `services` URI in the code.

Since we know that after using our proxy server to redirect `services` to `achievements` make achievements work again, there's nothing wrong with this function in particular, especially since by the time we reach this function we already received an achievement ID so the issue would be higher up.

Tracing references to this function and going 2 levels above, we can find the following function at address `0x100406DF4`:

*(Please note that the function name and variable names were added by me so there's a possibility they might be slightly inaccurate, but they did their job in helping me understand the function)*
<img width="699" height="688" alt="UnmodifiedDecomp" src="https://github.com/user-attachments/assets/f31d6e6d-1b4d-48f4-a24e-89d5de3c4452" />

We can see that we have 2 while loops that seem to reference 2 separate pieces of data and they all go up to value `0x14` which is 20 in decimal, coincidentally matching how many achievements we have in the (broken) Xbox Live list.

Inspecting the first while loop, we can see that we start from an int value from inside the `INT_100A146D4` table reference but then we advance by 2 ints instead of 1, effectively skipping over one value each time, and then check the second parameter of function with the one we skipped over... Huh!?

Going over to `INT_100A146D4` we can see the following (with my naming modifications to make it easier to understand later):

<img width="1065" height="702" alt="UnmodifiedPairTable" src="https://github.com/user-attachments/assets/e2778005-8a5e-4a48-9f22-ef7dde9fdea7" />

We seem to be starting from the first red value, which is 1, and then skipping over all the blue values for each iteration, but when we want to check the second parameter of the function, we do so with the blue values.

We can also see something interesting in here, all values seem to be duplicated except for the first 0 value and the higher values starting with 0xD. There's also some skipping that occurs here at the end of this table:

<img width="2190" height="1308" alt="image" src="https://github.com/user-attachments/assets/4619ea28-bcc8-4b27-b31c-b70119d5400c" />

Near 0x14 we start jumping up and down to some high values, such as 0x1C and then back down to 0x15. If we also go back to the part where values stop being duplicated, they seem to match up with our unobtainable achievements.

For example if we consider the red values to be IDs (because we start checking with the first red value which is ID 1) and see that **Pension Plan** has ID 0xE which belongs to the blue fields, it seems that none of the unobtainable achievements (0xE, 0x10, 0x12, 0x14, 0x20) seem to have their IDs in the red fields. Pretty interesting if you ask me...

Going back to our second while loop in that function, we inspect the other table:

<img width="1108" height="514" alt="UnmodifiedIndexTable" src="https://github.com/user-attachments/assets/b3de2965-39e0-4eee-b1eb-6fa5bf2cf3ca" />

Checking this one, we seem to start from 0 and go all the way up to 0x17 with some skips near 0xD once again, but this time we can see the unobtainable IDs here. Interestingly, the values here seem to match up perfectly with the blue field values from the other table...

The red fields in the other table also seem to match up with the Xbox Live achievement IDs of the 20 achievements we have available, because for example we don't have an ID 0x17 achievement but we do have a 0x1F (31) ID achievement which is **Vidmaster 2.0**.

Considering that the second while loop simply goes over each value from this table and checks it against the second function parameter, while the other data table starts from the red fields but checks the same parameter against the blue fields (which are the same values as this one), we can then assume that this is some sort of an achievement index table and the other one is a table of pairs linking these indices (blue fields) to XBL IDs (red fields).

### So what's the problem?
Basically the game stores the achievements as indices and uses these values internally but when it wants to send an Xbox Live achievement unlock request, it must supply the ID that Xbox Live uses to recognize these achievements.
Going back up now to the pictures showing the function and tables should make more sense now and we can figure out what's going on.

For example, if you did the requirements for **Vidmaster 2.0**, the unlock function will receive index 0x17 and say "unlock this achievement pls". The function will then go and see what's the XBL ID (red fields) for the given index (blue field) and will retrieve ID 0x1F (31) for this specific index.

After getting the correct XBL ID, we'll eventually reach the first function we found which will craft the XBL request and send it with `unlocked: true` parameter, which is how the achievement is unlocked on your profile.

**The problem** is that we seem to be missing both the indices for the unobtainable achievements and the pair listing that links the missing indices to the missing IDs.

These tables are also filled up to their max so it's not possible to add the missing values directly without overwriting other important data and possibly causing a crash.

## The Fix
Luckily iPhones use the ARM architecture which uses fixed length (4 bytes) length compared to something like our PCs and consoles that use x86-64 with variable length instructions. This means that it's possible to modify existing instructions to any other instruction without having to create a code cave from potential length issues.

We can also see that both of our indices and IDs have no reason to go over 255, which is the max value of a byte, but they're both stored as 4 byte ints which can go up to 2 or 4 billions, depending if they're unsigned or not, which can seem wasteful.

The reason why they're stored as such though is that ARM expects aligned memory access so it's much faster to store simple numbers as 4 bytes instead of how much you would actually need, but because of this we can try to implement a neat little trick.

We can add the missing indices into the `AchievsIndexTable` at the end (so we don't mess up other code that expects the current index order), overwriting into the pair table, which will result in this:

<img width="994" height="655" alt="ModifiedIndexTable" src="https://github.com/user-attachments/assets/9271bf72-fbd2-4114-984e-d6a56acaf649" />

Afterwards, because we had to use space from the pair table, where we didn't have space to add the missing values anyway, we modify each value there to be byte based instead of 4 byte ints, which results in this:

<img width="942" height="698" alt="ModifiedPairTable" src="https://github.com/user-attachments/assets/067683f0-3c72-4d76-ad43-3591dcbc0345" />

Because of this, we also have quite a bit of empty space left which we'll zero out and also toss in the correct achievements URL string so we can do the earning achievements fix in the same patch, eliminating the need to use the proxy way:

<img width="882" height="532" alt="ModifiedPairTable2" src="https://github.com/user-attachments/assets/61ca63be-9306-44fb-aac5-63d3c3973b2c" />

We'll also go ahead and change `"https://services."` to `"https://profile."` to fix the login issue, which is easily done as the new URL is shorter than the old one so we don't have to do any tricks for it. We only have to change the 2 out of 3 locations that `services` was previously used for achievements to point to the new location above where we inserted the new string.

### So what now?
After doing the neat tricks above, we have to go and modify instructions that deal with both tables in different ways:
- For `AchievsIndexTable`, we just have to go and increase the limit check from 20 achievs to 25, pretty easy to do.
- For the pair table, it is slightly more complex: We have to change all of the pointer types from int pointers to byte pointers, make sure we advance the pointers by 2 (2 bytes) instead of 8 (2 ints) and such
  - Do note that doing this might incur some performance penalty as ARM requires aligned memory access and it must do additional processing to access bytes by bytes.
  - This penalty might be insignificant in the end as the functions are not used that often and just called for each time you unlock an achievement which we can afford to have a barely noticeable blip, if any.

After doing everything, the `Verify...` function we found in the beginning of the deep dive should look like this:

<img width="682" height="689" alt="ModifiedDecomp" src="https://github.com/user-attachments/assets/abfc7199-d2c3-4021-a16c-f88ff0286edd" />

## Is That All?
You can notice a third table that's not been mentioned in the picture above, labelled as `achiev_table_begin_addr` which is a table constructed at runtime that seems to be responsible for tracking which achievements have been unlocked or not.

The purpose for it is to skip over sending an XBL request if the achievement is unlocked already in your save, but because this is a table that is available only at runtime, it makes it a bit difficult to track it using static analysis tools such as Ghidra.

Leaving it unmodified does mean that we do write some 1 values in some places that might possibly be intended for the missing achievements or not, but extensive testing from myself and some volunteers showed the game not changing in stability after the patch (though the game itself is pretty crashy on modern iOS).

What happens is that on some phones, everything works as intended and on other phones, the game will simply just send an unlock request once again for the 5 unobtainables if you unlocked them and do their requirements once again, but Microsoft servers should just ignore this anyway. Basically in the end it doesn't matter much.

When this patch was made, I didn't have access to a jailbroken iPhone at the time that could allow me to do live debugging and see exactly the behaviour of this table, so it is possible the patch might be modified later once I can properly debug the game and see if I need to intervene there as well.
