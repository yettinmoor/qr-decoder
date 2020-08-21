const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const page_allocator = std.heap.page_allocator;
const ArrayList = std.ArrayList;
const expect = std.testing.expect;

const QrImage = struct {
    data: []const []const u8,
};

const BitDirection = enum {
    Up,
    Down,
    LeftCW,
    LeftCCW,
};

const ByteData = struct {
    x: usize,
    y: usize,
    dir: BitDirection,
};

fn generatePositions(allocator: *Allocator, qr: *const QrImage) ![]ByteData {
    const dirs = [_]BitDirection{
        .Up, .LeftCCW, .Down, .Down, .LeftCW, .Up, .Up,
    };
    var positions = ArrayList(ByteData).init(allocator);

    var x: usize = 19;
    var y: usize = 15;
    var last_dir: BitDirection = .Up;
    const len = decodeByte(qr, .{ .x = x, .y = y, .dir = .Up });

    for (dirs[0..@intCast(usize, len)]) |dir| {
        switch (dir) {
            .Up => y -= @as(usize, if (last_dir != .Up) 2 else 4),
            .Down => y += @as(usize, if (last_dir != .Down) 2 else 4),
            .LeftCW => {
                x -= 2;
                y += 4;
            },
            .LeftCCW => {
                x -= 2;
                y -= 2;
            },
        }
        try positions.append(.{ .x = x, .y = y, .dir = dir });
        last_dir = dir;
    }
    return positions.items;
}

fn decodeByte(qr: *const QrImage, byte_data: ByteData) u8 {
    const x = byte_data.x;
    const y = byte_data.y;
    const is_masked = (x + y) % 2 == 0;

    const bit_positions: [8]struct { dx: usize, dy: usize } = switch (byte_data.dir) {
        .Up => .{
            .{ .dx = 1, .dy = 3 }, .{ .dx = 0, .dy = 3 },
            .{ .dx = 1, .dy = 2 }, .{ .dx = 0, .dy = 2 },
            .{ .dx = 1, .dy = 1 }, .{ .dx = 0, .dy = 1 },
            .{ .dx = 1, .dy = 0 }, .{ .dx = 0, .dy = 0 },
        },
        .Down => .{
            .{ .dx = 1, .dy = 0 }, .{ .dx = 0, .dy = 0 },
            .{ .dx = 1, .dy = 1 }, .{ .dx = 0, .dy = 1 },
            .{ .dx = 1, .dy = 2 }, .{ .dx = 0, .dy = 2 },
            .{ .dx = 1, .dy = 3 }, .{ .dx = 0, .dy = 3 },
        },
        .LeftCW => .{
            .{ .dx = 3, .dy = 0 }, .{ .dx = 2, .dy = 0 },
            .{ .dx = 3, .dy = 1 }, .{ .dx = 2, .dy = 1 },
            .{ .dx = 1, .dy = 1 }, .{ .dx = 0, .dy = 1 },
            .{ .dx = 1, .dy = 0 }, .{ .dx = 0, .dy = 0 },
        },
        .LeftCCW => .{
            .{ .dx = 3, .dy = 1 }, .{ .dx = 2, .dy = 1 },
            .{ .dx = 3, .dy = 0 }, .{ .dx = 2, .dy = 0 },
            .{ .dx = 1, .dy = 0 }, .{ .dx = 0, .dy = 0 },
            .{ .dx = 1, .dy = 1 }, .{ .dx = 0, .dy = 1 },
        },
    };

    var byte: u8 = 0;
    for (bit_positions) |d| byte = (byte << 1) | qr.data[y + d.dy][x + d.dx];

    const mask: u8 = switch (byte_data.dir) {
        .Up => 0b1001_1001,
        .Down => 0b0110_0110,
        .LeftCW => 0b0110_1001,
        .LeftCCW => 0b1001_0110,
    };

    return byte ^ if (is_masked) mask else ~mask;
}

test "decode one byte" {
    const byte = decodeByte(
        &qr_data1,
        .{ .x = 19, .y = 15, .dir = .Up },
    );
    expect(byte == 0b00000101);
}

test "decode qr image" {
    try testDecoder(&qr_data1, "Hello");
    try testDecoder(&qr_data2, "T!st");
}

fn testDecoder(qr: *const QrImage, expected: []const u8) !void {
    const positions = try generatePositions(page_allocator, qr);
    expect(positions.len == expected.len);
    var bytes = try page_allocator.alloc(u8, positions.len);
    for (positions) |p, i| bytes[i] = decodeByte(qr, p);
    expect(mem.eql(u8, bytes, expected));
}

const qr_data1 = QrImage{
    // Hello
    .data = &[_][]const u8{
        &[_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1 },
        &[_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1 },
        &[_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1 },
        &[_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1 },
        &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        &[_]u8{ 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1 },
        &[_]u8{ 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1 },
        &[_]u8{ 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1 },
        &[_]u8{ 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0 },
        &[_]u8{ 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0 },
        &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0 },
        &[_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1 },
        &[_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1 },
        &[_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0 },
        &[_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1 },
    },
};

const qr_data2 = QrImage{
    // T!st
    .data = &[_][]const u8{
        &[_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1 },
        &[_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1 },
        &[_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 },
        &[_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1 },
        &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        &[_]u8{ 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1 },
        &[_]u8{ 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1 },
        &[_]u8{ 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1 },
        &[_]u8{ 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0 },
        &[_]u8{ 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1 },
        &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0 },
        &[_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1 },
        &[_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0 },
        &[_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1 },
        &[_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0 },
        &[_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1 },
    },
};
