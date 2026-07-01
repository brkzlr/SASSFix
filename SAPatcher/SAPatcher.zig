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

// MD5 hash of latest (as of writing) SA v1.1.1 from App Store.
const @"SAv1.1.1" = "04dbdf21ce13c6adbcc1dfd13185cd10";
// MD5 hash of Spartan Assault v1.1.1 Game.app/Game fat Mach-0 binary.
const @"SAv1.1.1-FAT" = "bdab763fa996e04e4cf2c7cb38edaccf";

pub fn main(init: std.process.Init) void {
    const allocator = init.gpa;

    var argsIt = init.minimal.args.iterateAllocator(allocator) catch {
        std.debug.print("Error trying to process command line args! Aborting...\n", .{});
        return;
    };
    defer argsIt.deinit();

    _ = argsIt.skip();
    const filePath = argsIt.next() orelse {
        std.debug.print("Missing path to Game binary or IPA! Aborting...\n", .{});
        return;
    };

    if (std.ascii.eqlIgnoreCase(std.fs.path.extension(filePath), ".ipa")) {
        patchIpa(init, allocator, filePath) catch |err| {
            std.debug.print("Error patching IPA \"{s}\"! Error: {s}\n", .{ filePath, @errorName(err) });
        };
        return;
    }

    const gameBinary = std.Io.Dir.cwd().readFileAlloc(init.io, filePath, allocator, .unlimited) catch |err| {
        std.debug.print("Error opening file \"{s}\"! Error: {s}\n", .{ filePath, @errorName(err) });
        return;
    };
    defer allocator.free(gameBinary);

    const digest = std.fmt.bytesToHex(std.crypto.hash.Md5.hashResult(gameBinary), .lower);
    if (std.mem.eql(u8, @"SAv1.1.1", &digest)) {
        PatchSA(gameBinary, 0);
    } else if (std.mem.eql(u8, @"SAv1.1.1-FAT", &digest)) {
        // Since this "Game" is a Mach-O fat binary that contains both 32bits and 64bits ARM code
        // we'll have to patch both the 32bits and 64bits parts.
        PatchSA(gameBinary, 0xB44000);
        PatchSA32(gameBinary, 0);
    } else {
        std.debug.print("Binary does not match internal v1.1.1 hashes!\nMake sure you supply an unmodified SA v1.1.1 \"Game\" binary.\n", .{});
        return;
    }

    var patchedFile = std.Io.Dir.cwd().createFile(init.io, "GamePatched", .{}) catch |err| {
        std.debug.print("Error creating file for patched binary! Error: {s}\n", .{@errorName(err)});
        return;
    };
    defer patchedFile.close(init.io);

    var fileWriter = patchedFile.writerStreaming(init.io, &.{});
    defer fileWriter.end() catch |err| {
        std.debug.print("Error closing fileWriter! Error: {s}\n", .{@errorName(err)});
    };

    fileWriter.interface.writeAll(gameBinary) catch |err| {
        std.debug.print("Error writing file for patched binary! Error: {s}\n", .{@errorName(err)});
        return;
    };
}

fn PatchSA(binaryBuf: []u8, fileOffset: u32) void {
    // Modify achievements index table to include the missing 5 indices.
    // Add them to the end of the table to not mess with the order other instructions might rely on.
    binaryBuf[0xA146D0 + fileOffset] = 0x0D;
    binaryBuf[0xA146D4 + fileOffset] = 0x0F;
    binaryBuf[0xA146D8 + fileOffset] = 0x11;
    binaryBuf[0xA146DC + fileOffset] = 0x13;
    binaryBuf[0xA146E0 + fileOffset] = 0x18;

    // Since we increased the above table by 5 ints, we overwrote into the next adjacent table containing pairs of achievement IDs and indices
    // where the pairs are Index first then ID second, but each value in pair is stored as a 4 bytes int.
    // We already lost 5 slots from the modifications above and we can't afford to overwrite into the next table from this one
    // so we'll modify each pair to be byte based instead and insert the missing ones from all the extra space we gained.
    binaryBuf[0xA146E4 + fileOffset] = 0x00; // Index
    binaryBuf[0xA146E5 + fileOffset] = 0x01; // ID
    binaryBuf[0xA146E6 + fileOffset] = 0x01; // Index
    binaryBuf[0xA146E7 + fileOffset] = 0x02; // ID
    binaryBuf[0xA146E8 + fileOffset] = 0x02; // Index
    binaryBuf[0xA146E9 + fileOffset] = 0x03; // ID
    binaryBuf[0xA146EA + fileOffset] = 0x03; // Index
    binaryBuf[0xA146EB + fileOffset] = 0x04; // ID
    binaryBuf[0xA146EC + fileOffset] = 0x04; // Index
    binaryBuf[0xA146ED + fileOffset] = 0x05; // ID
    binaryBuf[0xA146EE + fileOffset] = 0x05; // Index
    binaryBuf[0xA146EF + fileOffset] = 0x06; // ID
    binaryBuf[0xA146F0 + fileOffset] = 0x06; // Index
    binaryBuf[0xA146F1 + fileOffset] = 0x07; // ID
    binaryBuf[0xA146F2 + fileOffset] = 0x07; // Index
    binaryBuf[0xA146F3 + fileOffset] = 0x08; // ID
    binaryBuf[0xA146F4 + fileOffset] = 0x08; // Index
    binaryBuf[0xA146F5 + fileOffset] = 0x09; // ID
    binaryBuf[0xA146F6 + fileOffset] = 0x09; // Index
    binaryBuf[0xA146F7 + fileOffset] = 0x0A; // ID
    binaryBuf[0xA146F8 + fileOffset] = 0x0A; // Index
    binaryBuf[0xA146F9 + fileOffset] = 0x0B; // ID
    binaryBuf[0xA146FA + fileOffset] = 0x0B; // Index
    binaryBuf[0xA146FB + fileOffset] = 0x0C; // ID
    binaryBuf[0xA146FC + fileOffset] = 0x0C; // Index
    binaryBuf[0xA146FD + fileOffset] = 0x0D; // ID
    binaryBuf[0xA146FE + fileOffset] = 0x0D; // Index
    binaryBuf[0xA146FF + fileOffset] = 0x0E; // ID
    binaryBuf[0xA14700 + fileOffset] = 0x0E; // Index
    binaryBuf[0xA14701 + fileOffset] = 0x0F; // ID
    binaryBuf[0xA14702 + fileOffset] = 0x0F; // Index
    binaryBuf[0xA14703 + fileOffset] = 0x10; // ID
    binaryBuf[0xA14704 + fileOffset] = 0x10; // Index
    binaryBuf[0xA14705 + fileOffset] = 0x11; // ID
    binaryBuf[0xA14706 + fileOffset] = 0x11; // Index
    binaryBuf[0xA14707 + fileOffset] = 0x12; // ID
    binaryBuf[0xA14708 + fileOffset] = 0x12; // Index
    binaryBuf[0xA14709 + fileOffset] = 0x13; // ID
    binaryBuf[0xA1470A + fileOffset] = 0x13; // Index
    binaryBuf[0xA1470B + fileOffset] = 0x14; // ID
    binaryBuf[0xA1470C + fileOffset] = 0x14; // Index
    binaryBuf[0xA1470D + fileOffset] = 0x1C; // ID
    binaryBuf[0xA1470E + fileOffset] = 0x15; // Index
    binaryBuf[0xA1470F + fileOffset] = 0x1D; // ID
    binaryBuf[0xA14710 + fileOffset] = 0x16; // Index
    binaryBuf[0xA14711 + fileOffset] = 0x1E; // ID
    binaryBuf[0xA14712 + fileOffset] = 0x17; // Index
    binaryBuf[0xA14713 + fileOffset] = 0x1F; // ID
    binaryBuf[0xA14714 + fileOffset] = 0x18; // Index
    binaryBuf[0xA14715 + fileOffset] = 0x20; // ID

    // Zero out most of the remaining unused spaces from this table, leaving last 22 bytes for another change below.
    @memset(binaryBuf[0xA14716 + fileOffset .. 0xA1475A + fileOffset], 0);

    // SA/SS uses URIs beginning with "https://services" for both profile login and achievements unlock/status
    // but this is deprecated and no longer allowed by Microsoft, which is the reason why you can't login or earn achievements.
    // Now you need to use "achievements" for achiev unlock/status and "profile" for login related functionality
    // which means that previously one string that handled both cases will now need to be split for each case.

    // The last 22 bytes we gained from the above table shenanigans will be used to store the new achievements string for the unlock/status logic.
    const achievementsUrl = "https://achievements.";
    @memcpy(binaryBuf[0xA1475A + fileOffset .. 0xA1475A + fileOffset + achievementsUrl.len], achievementsUrl);
    binaryBuf[0xA1475A + fileOffset + achievementsUrl.len] = 0;

    // Lastly, we change the existing deprecated string "https://services." to current "https://profile." to allow proper Xbox Live login.
    const profileUrl = "https://profile.";
    @memcpy(binaryBuf[0xA70D3f + fileOffset .. 0xA70D3F + fileOffset + profileUrl.len], profileUrl);
    binaryBuf[0xA70D3F + fileOffset + profileUrl.len] = 0;

    // Previously "services" URI was used in 3 places: one for achievement unlock logic, one for achievements status and the last for profile login.
    // Since we already changed "services" to "profile", the profile login case is already handled, so we have to change the remaining two places of
    // achievement unlock and achievement status to point to the new URI we inserted in the achievs pair table above.
    binaryBuf[0x40F17C + fileOffset] = 0x21; // Achievements status
    binaryBuf[0x40F17D + fileOffset] = 0x30;
    binaryBuf[0x40F181 + fileOffset] = 0x68;
    binaryBuf[0x40F182 + fileOffset] = 0x1D;
    binaryBuf[0x40F51C + fileOffset] = 0x21; // Achievements unlock
    binaryBuf[0x40F51D + fileOffset] = 0x30;
    binaryBuf[0x40F521 + fileOffset] = 0x68;
    binaryBuf[0x40F522 + fileOffset] = 0x1D;

    // Now all that remains is to change code instructions that interact with the tables we modified above to be byte based and stop at 25 instead of 20.
    // Change 9F 43 01 F1: cmp x28,#0x50 -> 9F 93 01 F1: cmp x28,#0x64
    // as achievements increased from 20 (*4 for this section of code) to 25
    binaryBuf[0x406D09 + fileOffset] = 0x93;
    // Change 08 11 00 91: add x8,x8,#0x4 -> 08 55 00 91: add x8,x8,#0x15
    // because we shifted our pair table down when we added the missing indices.
    binaryBuf[0x406E19 + fileOffset] = 0x55;
    // Change 0A C1 5F B8: ldur w10,[x8, #-0x4] -> 0A F1 5F 38: ldur w10,[x8, #-0x1]
    // because our pair table now contains bytes instead of 4 byte ints.
    binaryBuf[0x406E1D + fileOffset] = 0xF1;
    binaryBuf[0x406E1F + fileOffset] = 0x38;
    // Change 08 21 00 91: add x8,x8,#0x8 -> 08 09 00 91: add x8,x8,#0x2
    // so we advance 2 bytes (jump from pair start to pair start) instead of 8 when table was int based.
    binaryBuf[0x406E29 + fileOffset] = 0x09;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    // because pair table has 25 (0x18) values now instead of 20 (0x13)
    binaryBuf[0x406E31 + fileOffset] = 0x61;
    // Change 00 01 40 B9: ldr w0,[x8] -> 00 01 40 39: ldrb w0,[x8]
    // because table values are now bytes not ints
    binaryBuf[0x406E43 + fileOffset] = 0x39;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    // because index table has 25 (0x18) values now instead of 20 (0x13)
    binaryBuf[0x406E65 + fileOffset] = 0x61;
    // Change 1F 4D 00 71: cmp w8,#0x13 -> 1F 61 00 71: cmp w8,#0x18
    // ditto
    binaryBuf[0x406EAD + fileOffset] = 0x61;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    // ditto
    binaryBuf[0x406F05 + fileOffset] = 0x61;

    // Remaining code changes are for the GetPlayerStats function which uses both tables to check what achievs you unlocked
    // so it's mostly a repeat of the changes above
    // Change 08 11 00 91: add x8,x8,#0x4 -> 08 55 00 91: add x8,x8,#0x15
    binaryBuf[0x407409 + fileOffset] = 0x55;
    // Change 0A 01 40 B9: ldr w10,[x8] -> 0A 01 40 39: ldrb w10,[x8]
    binaryBuf[0x40740F + fileOffset] = 0x39;
    // Change 08 21 00 91: add x8,x8,#0x8 -> 08 09 00 91: add x8,x8,#0x2
    binaryBuf[0x407419 + fileOffset] = 0x09;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    binaryBuf[0x407421 + fileOffset] = 0x61;
    // Change 08 C1 5F B8: ldur w8,[x8, #-0x4] -> 08 F1 5F 38: ldur w8,[x8, #-0x1]
    binaryBuf[0x407431 + fileOffset] = 0xF1;
    binaryBuf[0x407433 + fileOffset] = 0x38;
    // Change 3F 4D 00 71: cmp w9,#0x13 -> 3F 61 00 71: cmp w9,#0x18
    binaryBuf[0x407449 + fileOffset] = 0x61;
}

fn PatchSA32(binaryBuf: []u8, fileOffset: u32) void {
    // Same logic as the ARM64 part (PatchSA), just different addresses and some opcodes.

    binaryBuf[0x95EC78 + fileOffset] = 0x0D;
    binaryBuf[0x95EC7C + fileOffset] = 0x0F;
    binaryBuf[0x95EC80 + fileOffset] = 0x11;
    binaryBuf[0x95EC84 + fileOffset] = 0x13;
    binaryBuf[0x95EC88 + fileOffset] = 0x18;

    binaryBuf[0x95EC8C + fileOffset] = 0x00; // Index
    binaryBuf[0x95EC8D + fileOffset] = 0x01; // ID
    binaryBuf[0x95EC8E + fileOffset] = 0x01; // Index
    binaryBuf[0x95EC8F + fileOffset] = 0x02; // ID
    binaryBuf[0x95EC90 + fileOffset] = 0x02; // Index
    binaryBuf[0x95EC91 + fileOffset] = 0x03; // ID
    binaryBuf[0x95EC92 + fileOffset] = 0x03; // Index
    binaryBuf[0x95EC93 + fileOffset] = 0x04; // ID
    binaryBuf[0x95EC94 + fileOffset] = 0x04; // Index
    binaryBuf[0x95EC95 + fileOffset] = 0x05; // ID
    binaryBuf[0x95EC96 + fileOffset] = 0x05; // Index
    binaryBuf[0x95EC97 + fileOffset] = 0x06; // ID
    binaryBuf[0x95EC98 + fileOffset] = 0x06; // Index
    binaryBuf[0x95EC99 + fileOffset] = 0x07; // ID
    binaryBuf[0x95EC9A + fileOffset] = 0x07; // Index
    binaryBuf[0x95EC9B + fileOffset] = 0x08; // ID
    binaryBuf[0x95EC9C + fileOffset] = 0x08; // Index
    binaryBuf[0x95EC9D + fileOffset] = 0x09; // ID
    binaryBuf[0x95EC9E + fileOffset] = 0x09; // Index
    binaryBuf[0x95EC9F + fileOffset] = 0x0A; // ID
    binaryBuf[0x95ECA0 + fileOffset] = 0x0A; // Index
    binaryBuf[0x95ECA1 + fileOffset] = 0x0B; // ID
    binaryBuf[0x95ECA2 + fileOffset] = 0x0B; // Index
    binaryBuf[0x95ECA3 + fileOffset] = 0x0C; // ID
    binaryBuf[0x95ECA4 + fileOffset] = 0x0C; // Index
    binaryBuf[0x95ECA5 + fileOffset] = 0x0D; // ID
    binaryBuf[0x95ECA6 + fileOffset] = 0x0D; // Index
    binaryBuf[0x95ECA7 + fileOffset] = 0x0E; // ID
    binaryBuf[0x95ECA8 + fileOffset] = 0x0E; // Index
    binaryBuf[0x95ECA9 + fileOffset] = 0x0F; // ID
    binaryBuf[0x95ECAA + fileOffset] = 0x0F; // Index
    binaryBuf[0x95ECAB + fileOffset] = 0x10; // ID
    binaryBuf[0x95ECAC + fileOffset] = 0x10; // Index
    binaryBuf[0x95ECAD + fileOffset] = 0x11; // ID
    binaryBuf[0x95ECAE + fileOffset] = 0x11; // Index
    binaryBuf[0x95ECAF + fileOffset] = 0x12; // ID
    binaryBuf[0x95ECB0 + fileOffset] = 0x12; // Index
    binaryBuf[0x95ECB1 + fileOffset] = 0x13; // ID
    binaryBuf[0x95ECB2 + fileOffset] = 0x13; // Index
    binaryBuf[0x95ECB3 + fileOffset] = 0x14; // ID
    binaryBuf[0x95ECB4 + fileOffset] = 0x14; // Index
    binaryBuf[0x95ECB5 + fileOffset] = 0x1C; // ID
    binaryBuf[0x95ECB6 + fileOffset] = 0x15; // Index
    binaryBuf[0x95ECB7 + fileOffset] = 0x1D; // ID
    binaryBuf[0x95ECB8 + fileOffset] = 0x16; // Index
    binaryBuf[0x95ECB9 + fileOffset] = 0x1E; // ID
    binaryBuf[0x95ECBA + fileOffset] = 0x17; // Index
    binaryBuf[0x95ECBB + fileOffset] = 0x1F; // ID
    binaryBuf[0x95ECBC + fileOffset] = 0x18; // Index
    binaryBuf[0x95ECBD + fileOffset] = 0x20; // ID

    @memset(binaryBuf[0x95ECBE + fileOffset .. 0x95ED02 + fileOffset], 0);

    const achievementsUrl = "https://achievements.";
    @memcpy(binaryBuf[0x95ED02 + fileOffset .. 0x95ED02 + fileOffset + achievementsUrl.len], achievementsUrl);
    binaryBuf[0x95ED02 + fileOffset + achievementsUrl.len] = 0;

    const profileUrl = "https://profile.";
    @memcpy(binaryBuf[0x8E9CDB + fileOffset .. 0x8E9CDB + fileOffset + profileUrl.len], profileUrl);
    binaryBuf[0x8E9CDB + fileOffset + profileUrl.len] = 0;

    binaryBuf[0x322DEC + fileOffset] = 0x4B; // Achievements status
    binaryBuf[0x322DEE + fileOffset] = 0x02;
    binaryBuf[0x322DEF + fileOffset] = 0x71;
    binaryBuf[0x322DF6 + fileOffset] = 0x63;
    binaryBuf[0x3230A8 + fileOffset] = 0x4B; // Achievements unlock
    binaryBuf[0x3230AA + fileOffset] = 0x4A;
    binaryBuf[0x3230B0 + fileOffset] = 0x63;

    // Cba to comment all the individual changes... we're doing the same logic as the 64 bits part
    // changing all cmps to 25 values instead of 20 and all 4 byte access instructions to 1 byte
    binaryBuf[0x31C48C + fileOffset] = 0x19;
    binaryBuf[0x31C530 + fileOffset] = 0x4E;
    binaryBuf[0x31C53C + fileOffset] = 0x11;
    binaryBuf[0x31C53E + fileOffset] = 0x10;
    binaryBuf[0x31C546 + fileOffset] = 0x18;
    binaryBuf[0x31C54E + fileOffset] = 0x40;
    binaryBuf[0x31C55B + fileOffset] = 0x78;
    binaryBuf[0x31C56C + fileOffset] = 0x18;
    binaryBuf[0x31C5A0 + fileOffset] = 0x18;
    binaryBuf[0x31C5D6 + fileOffset] = 0x18;
    binaryBuf[0x31C8FA + fileOffset] = 0x7E;
    binaryBuf[0x31C944 + fileOffset] = 0x40;
    binaryBuf[0x31C947 + fileOffset] = 0x78;
    binaryBuf[0x31C94E + fileOffset] = 0x18;
    binaryBuf[0x31C958 + fileOffset] = 0x1B;
    binaryBuf[0x31C95A + fileOffset] = 0x10;
    binaryBuf[0x31C968 + fileOffset] = 0x18;
}

const ZipEntryInfo = struct {
    central_header: std.zip.CentralDirectoryFileHeader,
    entry: std.zip.Iterator.Entry,
    filename: []u8,
    extra: []u8,
    comment: []u8,
    new_file_offset: u32 = 0,

    fn deinit(self: ZipEntryInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.filename);
        allocator.free(self.extra);
        allocator.free(self.comment);
    }
};

fn patchIpa(init: std.process.Init, allocator: std.mem.Allocator, ipaPath: []const u8) !void {
    var ipaFile = try std.Io.Dir.cwd().openFile(init.io, ipaPath, .{});
    defer ipaFile.close(init.io);

    var inputBuffer: [64 * 1024]u8 = undefined;
    var ipaReader = ipaFile.reader(init.io, &inputBuffer);

    var entries: std.ArrayList(ZipEntryInfo) = .empty;
    defer {
        for (entries.items) |entry| entry.deinit(allocator);
        entries.deinit(allocator);
    }

    var iterator = try std.zip.Iterator.init(&ipaReader);
    var patched_game: ?[]u8 = null;
    defer if (patched_game) |game| allocator.free(game);
    var target_offset: u64 = undefined;

    while (try iterator.next()) |entry| {
        try ipaReader.seekTo(entry.header_zip_offset);
        const central_header = try ipaReader.interface.takeStruct(std.zip.CentralDirectoryFileHeader, .little);
        if (!std.mem.eql(u8, &central_header.signature, &std.zip.central_file_header_sig))
            return error.ZipBadCdOffset;
        if (entry.file_offset > std.math.maxInt(u32) or
            central_header.local_file_header_offset == std.math.maxInt(u32) or
            central_header.compressed_size == std.math.maxInt(u32) or
            central_header.uncompressed_size == std.math.maxInt(u32))
        {
            return error.Zip64Unsupported;
        }

        const filename = try ipaReader.interface.readAlloc(allocator, central_header.filename_len);
        errdefer allocator.free(filename);
        const extra = try ipaReader.interface.readAlloc(allocator, central_header.extra_len);
        errdefer allocator.free(extra);
        const comment = try ipaReader.interface.readAlloc(allocator, central_header.comment_len);
        errdefer allocator.free(comment);

        var parts = std.mem.splitScalar(u8, filename, '/');
        if (std.mem.eql(u8, parts.next() orelse "", "Payload") and
            std.mem.endsWith(u8, parts.next() orelse "", ".app") and
            std.mem.eql(u8, parts.next() orelse "", "Game") and
            parts.next() == null)
        {
            if (patched_game != null) {
                std.debug.print("Found more than one Payload/*.app/Game file inside the IPA. Aborting to avoid patching the wrong file...\n", .{});
                return error.MultipleGameBinariesFound;
            }
            target_offset = entry.file_offset;
            if (entry.uncompressed_size > std.math.maxInt(usize))
                return error.FileTooBig;
            switch (entry.compression_method) {
                .store, .deflate => {},
                else => return error.UnsupportedCompressionMethod,
            }

            try ipaReader.seekTo(entry.file_offset);
            const local_header = try ipaReader.interface.takeStruct(std.zip.LocalFileHeader, .little);
            if (!std.mem.eql(u8, &local_header.signature, &std.zip.local_file_header_sig))
                return error.ZipBadFileOffset;
            if (local_header.filename_len != entry.filename_len)
                return error.ZipMismatchFilenameLen;

            patched_game = try allocator.alloc(u8, @intCast(entry.uncompressed_size));
            try ipaReader.seekTo(entry.file_offset +
                @as(u64, @sizeOf(std.zip.LocalFileHeader)) +
                @as(u64, local_header.filename_len) +
                @as(u64, local_header.extra_len));
            switch (entry.compression_method) {
                .store => try ipaReader.interface.readSliceAll(patched_game.?),
                .deflate => {
                    var flate_buffer: [std.compress.flate.max_window_len]u8 = undefined;
                    var decompress: std.compress.flate.Decompress = .init(&ipaReader.interface, .raw, &flate_buffer);
                    try decompress.reader.readSliceAll(patched_game.?);
                },
                else => unreachable,
            }

            const digest = std.fmt.bytesToHex(std.crypto.hash.Md5.hashResult(patched_game.?), .lower);
            if (std.mem.eql(u8, @"SAv1.1.1", &digest)) {
                PatchSA(patched_game.?, 0);
            } else if (std.mem.eql(u8, @"SAv1.1.1-FAT", &digest)) {
                PatchSA(patched_game.?, 0xB44000);
                PatchSA32(patched_game.?, 0);
            } else {
                std.debug.print("Binary inside IPA does not match internal v1.1.1 hashes!\nMake sure you supply an unmodified SA v1.1.1 IPA.\n", .{});
                return error.UnsupportedGameBinary;
            }
        }

        try entries.append(allocator, .{
            .central_header = central_header,
            .entry = entry,
            .filename = filename,
            .extra = extra,
            .comment = comment,
        });
    }

    const game = patched_game orelse {
        std.debug.print("Could not find Payload/*.app/Game inside the IPA.\nMake sure this is a Spartan Assault IPA, not an extracted folder or another app.\n", .{});
        return error.GameBinaryNotFound;
    };
    if (game.len > std.math.maxInt(u32))
        return error.ZipOutputTooLarge;
    const patched_crc32 = std.hash.crc.Crc32.hash(game);
    const patched_size: u32 = @intCast(game.len);
    var compressed_game_writer = try std.Io.Writer.Allocating.initCapacity(allocator, game.len);
    defer compressed_game_writer.deinit();
    var compress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var compress = try std.compress.flate.Compress.init(&compressed_game_writer.writer, &compress_buffer, .raw, .default);
    try compress.writer.writeAll(game);
    try compress.finish();
    const compressed_game = compressed_game_writer.written();
    if (compressed_game.len > std.math.maxInt(u32))
        return error.ZipOutputTooLarge;
    const compressed_size: u32 = @intCast(compressed_game.len);
    if (entries.items.len > std.math.maxInt(u16))
        return error.ZipTooManyEntries;

    std.sort.pdq(ZipEntryInfo, entries.items, {}, struct {
        fn lessThan(_: void, lhs: ZipEntryInfo, rhs: ZipEntryInfo) bool {
            return lhs.entry.file_offset < rhs.entry.file_offset;
        }
    }.lessThan);

    const out_basename = try std.fmt.allocPrint(allocator, "{s}-patched.ipa", .{std.fs.path.stem(std.fs.path.basename(ipaPath))});
    defer allocator.free(out_basename);
    const outPath = if (std.fs.path.dirname(ipaPath)) |dir|
        try std.fs.path.join(allocator, &.{ dir, out_basename })
    else
        try allocator.dupe(u8, out_basename);
    defer allocator.free(outPath);

    var outFile = try std.Io.Dir.cwd().createFile(init.io, outPath, .{});
    defer outFile.close(init.io);

    var outputBuffer: [64 * 1024]u8 = undefined;
    var outWriter = outFile.writerStreaming(init.io, &outputBuffer);
    defer outWriter.end() catch |err| {
        std.debug.print("Error closing output IPA writer! Error: {s}\n", .{@errorName(err)});
    };
    const out = &outWriter.interface;

    for (entries.items, 0..) |*entry, index| {
        const output_pos = outWriter.logicalPos();
        if (output_pos > std.math.maxInt(u32))
            return error.ZipOutputTooLarge;
        entry.new_file_offset = @intCast(output_pos);

        if (entry.entry.file_offset == target_offset) {
            try out.writeAll(&std.zip.local_file_header_sig);
            try out.writeInt(u16, 20, .little);
            try out.writeInt(u16, 0, .little);
            try out.writeInt(u16, @intFromEnum(std.zip.CompressionMethod.deflate), .little);
            try out.writeInt(u16, entry.central_header.last_modification_time, .little);
            try out.writeInt(u16, entry.central_header.last_modification_date, .little);
            try out.writeInt(u32, patched_crc32, .little);
            try out.writeInt(u32, compressed_size, .little);
            try out.writeInt(u32, patched_size, .little);
            try out.writeInt(u16, @intCast(entry.filename.len), .little);
            try out.writeInt(u16, 0, .little);
            try out.writeAll(entry.filename);
            try out.writeAll(compressed_game);
            std.debug.print("Patched {s} inside the IPA.\n", .{entry.filename});
        } else {
            const end = if (index + 1 < entries.items.len)
                entries.items[index + 1].entry.file_offset
            else
                iterator.cd_zip_offset;
            try ipaReader.seekTo(entry.entry.file_offset);
            try ipaReader.interface.streamExact64(out, end - entry.entry.file_offset);
        }
    }

    const central_dir_offset_u64 = outWriter.logicalPos();
    if (central_dir_offset_u64 > std.math.maxInt(u32))
        return error.ZipOutputTooLarge;
    const central_dir_offset: u32 = @intCast(central_dir_offset_u64);

    for (entries.items) |entry| {
        const header = entry.central_header;
        const is_target_game = entry.entry.file_offset == target_offset;
        const extra: []const u8 = if (is_target_game) &.{} else entry.extra;
        const comment: []const u8 = if (is_target_game) &.{} else entry.comment;
        if (entry.filename.len > std.math.maxInt(u16) or
            extra.len > std.math.maxInt(u16) or
            comment.len > std.math.maxInt(u16))
        {
            return error.ZipOutputTooLarge;
        }
        const has_unix_mode = (header.version_made_by >> 8) == 3 and (header.external_file_attributes & 0xFFFF0000) != 0;
        const external_file_attributes: u32 = if (is_target_game)
            0x81ED0000
        else if (has_unix_mode)
            header.external_file_attributes
        else if (std.mem.endsWith(u8, entry.filename, "/") or (header.external_file_attributes & 0x10) != 0)
            0x41ED0010
        else if ((header.external_file_attributes & 0x01) != 0)
            0x81240000
        else
            0x81A40000;

        try out.writeAll(&std.zip.central_file_header_sig);
        // 0x0314: made by Unix (3), ZIP 2.0 (20), for entries with synthesized POSIX attrs.
        try out.writeInt(u16, if (has_unix_mode) header.version_made_by else @as(u16, (3 << 8) | 20), .little);
        try out.writeInt(u16, if (is_target_game) 20 else header.version_needed_to_extract, .little);
        try out.writeInt(u16, if (is_target_game) 0 else @as(u16, @bitCast(header.flags)), .little);
        try out.writeInt(u16, if (is_target_game) @intFromEnum(std.zip.CompressionMethod.deflate) else @intFromEnum(header.compression_method), .little);
        try out.writeInt(u16, header.last_modification_time, .little);
        try out.writeInt(u16, header.last_modification_date, .little);
        try out.writeInt(u32, if (is_target_game) patched_crc32 else header.crc32, .little);
        try out.writeInt(u32, if (is_target_game) compressed_size else header.compressed_size, .little);
        try out.writeInt(u32, if (is_target_game) patched_size else header.uncompressed_size, .little);
        try out.writeInt(u16, @intCast(entry.filename.len), .little);
        try out.writeInt(u16, @intCast(extra.len), .little);
        try out.writeInt(u16, @intCast(comment.len), .little);
        try out.writeInt(u16, header.disk_number, .little);
        try out.writeInt(u16, header.internal_file_attributes, .little);
        // Preserve Unix modes if present, otherwise synthesize dir 040755, Game 100755, files 100644/100444.
        try out.writeInt(u32, external_file_attributes, .little);
        try out.writeInt(u32, entry.new_file_offset, .little);
        try out.writeAll(entry.filename);
        try out.writeAll(extra);
        try out.writeAll(comment);
    }

    const central_dir_size_u64 = outWriter.logicalPos() - central_dir_offset_u64;
    if (central_dir_size_u64 > std.math.maxInt(u32))
        return error.ZipOutputTooLarge;

    try out.writeAll(&std.zip.end_record_sig);
    try out.writeInt(u16, 0, .little);
    try out.writeInt(u16, 0, .little);
    try out.writeInt(u16, @intCast(entries.items.len), .little);
    try out.writeInt(u16, @intCast(entries.items.len), .little);
    try out.writeInt(u32, @intCast(central_dir_size_u64), .little);
    try out.writeInt(u32, central_dir_offset, .little);
    try out.writeInt(u16, 0, .little);

    std.debug.print("Done! Wrote patched IPA to \"{s}\"\n", .{outPath});
}
