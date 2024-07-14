const std = @import("std");

pub const Vertex = struct {
    left: u32 = undefined,
    right: u32 = undefined,
    sum: i32 = 0,
    count: u32 = 0,
    left_child: ?*Vertex = null,
    right_child: ?*Vertex = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, lb: u32, rb: u32) Vertex {
        return Vertex {
            .left = lb,
            .right = rb,
            .allocator = allocator,
        };
    }

    fn extend(self: *Vertex) !void {
        if (self.left_child == null and self.left + 1 < self.right) {
            const mid = (self.left + self.right) / 2;
            const lc = try self.allocator.create(Vertex);
            const rc = try self.allocator.create(Vertex);
            lc.* = Vertex.init(self.allocator, self.left, mid);
            rc.* = Vertex.init(self.allocator, mid, self.right);
            self.left_child = lc;
            self.right_child = rc;
        }
    }

    pub fn add(self: *Vertex, loc: u32, val: i32) !void {
        try extend(self);
        self.sum += val;
        self.count += 1;

        if (self.left_child) |lc| {
            if (loc < lc.right) {
                try lc.add(loc, val);
            } else {
                try self.right_child.?.add(loc, val);
            }
        }
    }

    pub fn getSumAndCount(self: *Vertex, lq: u32, rq: u32) !struct { sum: i32, count: u32} {
        if (lq <= self.left and self.right <= rq) return .{ .sum = self.sum, .count = self.count };
        if (@max(lq, self.left) >= @min(rq, self.right)) return .{ .sum = 0, .count = 0};
        try extend(self);
        
        const scl = try self.left_child.?.getSumAndCount(lq, rq);
        const scr = try self.right_child.?.getSumAndCount(lq, rq);
        return .{ .sum = scl.sum + scr.sum, .count = scl.count + scr.count };
    }
};

test "protohackers example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();

    var SST: Vertex = Vertex.init(allocator, 0, (1 << 32) - 1);
    std.debug.print("2^32 - 1 == {any}\n", .{(1 << 32) - 1});
    try SST.add(12345, 101);
    try SST.add(12346, 102);
    try SST.add(12347, 100);
    try SST.add(40960, 5);
    
    const res = try SST.getSumAndCount(12288, 16384);

    try std.testing.expect(res.sum == 303);
    try std.testing.expect(res.count == 3);
}
