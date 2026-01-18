// Copyright (C) 2026 brkzlr <brksys@icloud.com>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
const std = @import("std");

// Since "Game" is a Mach-O fat binary that contains both 32bits and 64bits ARM code
// we'll have to translate our addresses from Ghidra with an offset that skips Mach headers and beginning 32bits code.
// I could've just used the addresses with the offset built-in but this way you can see the Ghidra addresses in the code directly
// so you can check out stuff by yourself if you wish to. You're welcome ;)
const fbOffset = 0xB44000;

// MD5 hash of Spartan Assault v1.1.1 Game.app/Game binary
const @"SAv1.1.1" = "bdab763fa996e04e4cf2c7cb38edaccf";

pub fn main() void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var argsIt: std.process.ArgIterator = std.process.argsWithAllocator(allocator) catch {
        std.debug.print("Error trying to process command line args! Aborting...\n", .{});
        return;
    };
    defer argsIt.deinit();

    _ = argsIt.skip();
    const filePath = argsIt.next() orelse {
        std.debug.print("Missing path to Game binary! Aborting...\n", .{});
        return;
    };
    const gameBinary = std.fs.cwd().readFileAlloc(allocator, filePath, std.math.maxInt(usize)) catch |err| {
        std.debug.print("Error opening file ({s})! Error: {s}\n", .{ filePath, @errorName(err) });
        return;
    };
    defer allocator.free(gameBinary);

    const digest = std.fmt.bytesToHex(std.crypto.hash.Md5.hashResult(gameBinary), .lower);
    if (!std.mem.eql(u8, @"SAv1.1.1", &digest)) {
        std.debug.print("Binary does not match v1.1.1 hash!\nMake sure you supply an unmodified SA v1.1.1 \"Game\" binary.\n", .{});
        return;
    }

    PatchSA(gameBinary);
}

fn PatchSA(binaryBuf: []u8) void {
    // Modify achievements index table to include the missing 5 indices.
    // Add them to the end of the table to not mess with the order other instructions might rely on.
    binaryBuf[0xA146D0 + fbOffset] = 0x0D;
    binaryBuf[0xA146D4 + fbOffset] = 0x0F;
    binaryBuf[0xA146D8 + fbOffset] = 0x11;
    binaryBuf[0xA146DC + fbOffset] = 0x13;
    binaryBuf[0xA146E0 + fbOffset] = 0x18;

    // Since we increased the above table by 5 ints, we overwrote into the next adjacent table containing pairs of achievement IDs and indices
    // where the pairs are Index first then ID second, but each value in pair is stored as a 4 bytes int.
    // We already lost 5 slots from the modifications above and we can't afford to overwrite into the next table from this one
    // so we'll modify each pair to be byte based instead and insert the missing ones from all the extra space we gained.
    binaryBuf[0xA146E4 + fbOffset] = 0x00; // Index
    binaryBuf[0xA146E5 + fbOffset] = 0x01; // ID
    binaryBuf[0xA146E6 + fbOffset] = 0x01; // Index
    binaryBuf[0xA146E7 + fbOffset] = 0x02; // ID
    binaryBuf[0xA146E8 + fbOffset] = 0x02; // Index
    binaryBuf[0xA146E9 + fbOffset] = 0x03; // ID
    binaryBuf[0xA146EA + fbOffset] = 0x03; // Index
    binaryBuf[0xA146EB + fbOffset] = 0x04; // ID
    binaryBuf[0xA146EC + fbOffset] = 0x04; // Index
    binaryBuf[0xA146ED + fbOffset] = 0x05; // ID
    binaryBuf[0xA146EE + fbOffset] = 0x05; // Index
    binaryBuf[0xA146EF + fbOffset] = 0x06; // ID
    binaryBuf[0xA146F0 + fbOffset] = 0x06; // Index
    binaryBuf[0xA146F1 + fbOffset] = 0x07; // ID
    binaryBuf[0xA146F2 + fbOffset] = 0x07; // Index
    binaryBuf[0xA146F3 + fbOffset] = 0x08; // ID
    binaryBuf[0xA146F4 + fbOffset] = 0x08; // Index
    binaryBuf[0xA146F5 + fbOffset] = 0x09; // ID
    binaryBuf[0xA146F6 + fbOffset] = 0x09; // Index
    binaryBuf[0xA146F7 + fbOffset] = 0x0A; // ID
    binaryBuf[0xA146F8 + fbOffset] = 0x0A; // Index
    binaryBuf[0xA146F9 + fbOffset] = 0x0B; // ID
    binaryBuf[0xA146FA + fbOffset] = 0x0B; // Index
    binaryBuf[0xA146FB + fbOffset] = 0x0C; // ID
    binaryBuf[0xA146FC + fbOffset] = 0x0C; // Index
    binaryBuf[0xA146FD + fbOffset] = 0x0D; // ID
    binaryBuf[0xA146FE + fbOffset] = 0x0D; // Index
    binaryBuf[0xA146FF + fbOffset] = 0x0E; // ID
    binaryBuf[0xA14700 + fbOffset] = 0x0E; // Index
    binaryBuf[0xA14701 + fbOffset] = 0x0F; // ID
    binaryBuf[0xA14702 + fbOffset] = 0x0F; // Index
    binaryBuf[0xA14703 + fbOffset] = 0x10; // ID
    binaryBuf[0xA14704 + fbOffset] = 0x10; // Index
    binaryBuf[0xA14705 + fbOffset] = 0x11; // ID
    binaryBuf[0xA14706 + fbOffset] = 0x11; // Index
    binaryBuf[0xA14707 + fbOffset] = 0x12; // ID
    binaryBuf[0xA14708 + fbOffset] = 0x12; // Index
    binaryBuf[0xA14709 + fbOffset] = 0x13; // ID
    binaryBuf[0xA1470A + fbOffset] = 0x13; // Index
    binaryBuf[0xA1470B + fbOffset] = 0x14; // ID
    binaryBuf[0xA1470C + fbOffset] = 0x14; // Index
    binaryBuf[0xA1470D + fbOffset] = 0x1C; // ID
    binaryBuf[0xA1470E + fbOffset] = 0x15; // Index
    binaryBuf[0xA1470F + fbOffset] = 0x1D; // ID
    binaryBuf[0xA14710 + fbOffset] = 0x16; // Index
    binaryBuf[0xA14711 + fbOffset] = 0x1E; // ID
    binaryBuf[0xA14712 + fbOffset] = 0x17; // Index
    binaryBuf[0xA14713 + fbOffset] = 0x1F; // ID
    binaryBuf[0xA14714 + fbOffset] = 0x18; // Index
    binaryBuf[0xA14715 + fbOffset] = 0x20; // ID

    // Zero out most of the remaining unused spaces from this table, leaving last 22 bytes for another change below.
    @memset(binaryBuf[0xA14716 + fbOffset .. 0xA1475A + fbOffset], 0);

    // SA/SS uses URIs beginning with "https://services" for both profile login and achievements unlock/status
    // but this is deprecated and no longer allowed by Microsoft, which is the reason why you can't login or earn achievements.
    // Now you need to use "achievements" for achiev unlock/status and "profile" for login related functionality
    // which means that previously one string that handled both cases will now need to be split for each case.

    // The last 22 bytes we gained from the above table shenanigans will be used to store the new achievements string for the unlock/status logic.
    const achievementsUrl = "https://achievements.";
    @memcpy(binaryBuf[0xA1475A + fbOffset .. 0xA1475A + fbOffset + achievementsUrl.len], achievementsUrl);
    binaryBuf[0xA1475A + fbOffset + achievementsUrl.len] = 0;

    // Lastly, we change the existing deprecated string "https://services." to current "https://profile." to allow proper Xbox Live login.
    const profileUrl = "https://profile.";
    @memcpy(binaryBuf[0xA70D3f + fbOffset .. 0xA70D3F + fbOffset + profileUrl.len], profileUrl);
    binaryBuf[0xA70D3F + fbOffset + profileUrl.len] = 0;

    // Previously "services" URI was used in 3 places: one for achievement unlock logic, one for achievements status and the last for profile login.
    // Since we already changed "services" to "profile", the profile login case is already handled, so we have to change the remaining two places of
    // achievement unlock and achievement status to point to the new URI we inserted in the achievs pair table above.
    binaryBuf[0x40F17C + fbOffset] = 0x21; // Achievements status
    binaryBuf[0x40F17D + fbOffset] = 0x30;
    binaryBuf[0x40F181 + fbOffset] = 0x68;
    binaryBuf[0x40F182 + fbOffset] = 0x1D;
    binaryBuf[0x40F51C + fbOffset] = 0x21; // Achievements unlock
    binaryBuf[0x40F51D + fbOffset] = 0x30;
    binaryBuf[0x40F521 + fbOffset] = 0x68;
    binaryBuf[0x40F522 + fbOffset] = 0x1D;

    // Now all that remains is to change code instructions that interact with the tables we modified above to be byte based and stop at 25 instead of 20.
    // Change 9F 43 01 F1: cmp x28,#0x50 -> 9F 93 01 F1: cmp x28,#0x64
    // as achievements increased from 20 (*4 for this section of code) to 25
    binaryBuf[0x406D09 + fbOffset] = 0x93;
    // Change 08 11 00 91: add x8,x8,#0x4 -> 08 55 00 91: add x8,x8,#0x15
    // because we shifted our pair table down when we added the missing indices.
    binaryBuf[0x406E19 + fbOffset] = 0x55;
    // Change 0A C1 5F B8: ldur w10,[x8, #-0x4] -> 0A F1 5F 38: ldur w10,[x8, #-0x1]
    // because our pair table now contains bytes instead of 4 byte ints.
    binaryBuf[0x406E1D + fbOffset] = 0xF1;
    binaryBuf[0x406E1F + fbOffset] = 0x38;
    // Change 08 21 00 91: add x8,x8,#0x8 -> 08 09 00 91: add x8,x8,#0x2
    // so we advance 2 bytes (jump from pair start to pair start) instead of 8 when table was int based.
    binaryBuf[0x406E29 + fbOffset] = 0x09;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    // because pair table has 25 (0x18) values now instead of 20 (0x13)
    binaryBuf[0x406E31 + fbOffset] = 0x61;
    // Change 00 01 40 B9: ldr w0,[x8] -> 00 01 40 39: ldrb w0,[x8]
    // because table values are now bytes not ints
    binaryBuf[0x406E43 + fbOffset] = 0x39;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    // because index table has 25 (0x18) values now instead of 20 (0x13)
    binaryBuf[0x406E65 + fbOffset] = 0x61;
    // Change 1F 4D 00 71: cmp w8,#0x13 -> 1F 61 00 71: cmp w8,#0x18
    // ditto
    binaryBuf[0x406EAD + fbOffset] = 0x61;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    // ditto
    binaryBuf[0x406F05 + fbOffset] = 0x61;

    // Remaining code changes are for the GetPlayerStats function which uses both tables to check what achievs you unlocked
    // so it's mostly a repeat of the changes above
    // Change 08 11 00 91: add x8,x8,#0x4 -> 08 55 00 91: add x8,x8,#0x15
    binaryBuf[0x407409 + fbOffset] = 0x55;
    // Change 0A 01 40 B9: ldr w10,[x8] -> 0A 01 40 39: ldrb w10,[x8]
    binaryBuf[0x40740F + fbOffset] = 0x39;
    // Change 08 21 00 91: add x8,x8,#0x8 -> 08 09 00 91: add x8,x8,#0x2
    binaryBuf[0x407419 + fbOffset] = 0x09;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    binaryBuf[0x407421 + fbOffset] = 0x61;
    // Change 08 C1 5F B8: ldur w8,[x8, #-0x4] -> 08 F1 5F 38: ldur w8,[x8, #-0x1]
    binaryBuf[0x407431 + fbOffset] = 0xF1;
    binaryBuf[0x407433 + fbOffset] = 0x38;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    binaryBuf[0x407449 + fbOffset] = 0x61;

    var patchedFile = std.fs.cwd().createFile("GamePatched", .{}) catch |err| {
        std.debug.print("Error creating file for patched binary! Error: {s}\n", .{@errorName(err)});
        return;
    };
    defer patchedFile.close();

    var fileWriter = patchedFile.writerStreaming(&.{});
    defer fileWriter.end() catch |err| {
        std.debug.print("Error closing fileWriter! Error: {s}\n", .{@errorName(err)});
    };

    fileWriter.interface.writeAll(binaryBuf) catch |err| {
        std.debug.print("Error writing file for patched binary! Error: {s}\n", .{@errorName(err)});
        return;
    };
}
