const std = @import("std");
const Args = @import("args.zig");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("sys/xattr.h");
});

const ProgramMode = enum { Usage, List, Get, Set, Remove };

fn usage() void {
    std.debug.print(
        \\Usage: xattr -g attrname pathname
        \\       xattr -s attrname [ -V attrvalue ] pathname
        \\       xattr -r attrname pathname
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
            'r' => {
                mode = .Remove;
                attrname = try args.readString();
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
            const ret = c.listxattr(path, retbuf.ptr, retbuf.len);
            if (ret < 0) {
                c.perror("listxattr failed");
                std.process.exit(1);
            }

            const retlen: usize = @intCast(ret);
            var slice = retbuf[0..retlen];
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

            const ret = c.getxattr(path, attrnameZ, retbuf.ptr, retbuf.len);
            if (ret < 0) {
                c.perror("getxattr failed");
                std.process.exit(1);
            }

            const retlen: usize = @intCast(ret);
            try writer.print("{s}\n", .{retbuf[0..retlen]});
        },
        .Set => {
            if (attrvalue == null) {
                const stdin = std.io.getStdIn().reader();
                const ret = try stdin.readAll(retbuf);
                // TODO: what if the input is larger than the buffer...?

                attrvalue = retbuf[0..ret];
            }

            const attrnameZ = try allocator.dupeZ(u8, attrname.?);
            const attrvalueV: *const void = @ptrCast(attrvalue.?.ptr);

            const ret = c.setxattr(path, attrnameZ, attrvalueV, attrvalue.?.len, 0);
            if (ret != 0) {
                c.perror("setxattr failed");
                std.process.exit(1);
            }
        },
        .Remove => {
            const attrnameZ = try allocator.dupeZ(u8, attrname.?);

            const ret = c.removexattr(path, attrnameZ);
            if (ret != 0) {
                c.perror("removexattr failed");
                std.process.exit(1);
            }
        },
        else => {
            usage();
        },
    }

    try stdout_buf.flush();
}
