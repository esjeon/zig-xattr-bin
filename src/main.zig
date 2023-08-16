const std = @import("std");
const Args = @import("args.zig");

extern "c" fn perror([*c]const u8) void;

const ProgramMode = enum { Usage, List, Get, Set };

fn usage() void {
    std.debug.print(
        \\Usage: xattr -g attrname pathname
        \\       xattr -s attrname [ -V attrvalue ] pathname
        \\       xattr -l pathname
        \\
    , .{});
    std.os.exit(1);
}

pub fn main() !void {
    var args = Args.parseArgs();
    var mode = ProgramMode.Usage;
    var attrname: ?[]const u8 = null;
    var attrvalue: ?[]const u8 = null;

    while (args.nextFlag()) |flag| {
        switch (flag) {
            'l' => {
                mode = .List;
            },
            'g' => {
                mode = .Get;
                attrname = try args.readString();
            },
            's' => {
                mode = .Set;
                attrname = try args.readString();
            },
            'V' => {
                attrvalue = try args.readString();
            },
            else => usage(),
        }
    }

    if (args.countRest() != 1)
        usage();

    const path = args.nextPositionalRaw().?;

    const allocator = std.heap.page_allocator;
    var retbuf: []u8 = try allocator.alloc(u8, 1 * 1024 * 1024);
    defer allocator.free(retbuf);

    const stdout = std.io.getStdOut();
    var stdout_buf = std.io.bufferedWriter(stdout.writer());
    const writer = stdout_buf.writer();

    switch (mode) {
        .List => {
            const ret = std.os.linux.listxattr(path, retbuf.ptr, retbuf.len);
            if (ret == -1) {
                perror("getxattr failed: ");
                std.os.exit(1);
            }

            var slice = retbuf[0..ret];
            while (slice.len > 0) {
                const name = std.mem.sliceTo(slice, 0);
                if (name.len == slice.len) {
                    break;
                }
                try writer.print("{s}\n", .{name});

                slice = slice[name.len + 1 ..];
            }
        },
        .Get => {
            const attrnameZ = try allocator.dupeZ(u8, attrname.?);

            // XXX: getxattr returns unsigned type, but it also returns -1 for failure.
            const ret = std.os.linux.getxattr(path, attrnameZ, retbuf.ptr, retbuf.len);
            if (ret > retbuf.len) {
                perror("getxattr failed");
                std.os.exit(1);
            }

            try writer.print("{s}\n", .{retbuf[0..ret]});
        },
        .Set => {
            // TODO: Implement reading attr value from stdin.
            std.debug.assert(attrvalue != null);

            const attrnameZ = try allocator.dupeZ(u8, attrname.?);
            const attrvalueV = @ptrCast(*const void, attrvalue.?.ptr);

            const ret = std.os.linux.setxattr(path, attrnameZ, attrvalueV, attrvalue.?.len, 0);
            if (ret != 0) {
                perror("setxattr failed");
                std.os.exit(1);
            }
        },
        else => {
            usage();
        },
    }

    try stdout_buf.flush();
}
