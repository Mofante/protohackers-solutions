const std = @import("std");

pub const Vertex = struct {
    left: i32 = undefined,
    right: i32 = undefined,
    sum: i64 = 0,
    count: i32 = 0,
    left_child: ?*Vertex = null,
    right_child: ?*Vertex = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, lb: i32, rb: i32) !*Vertex {
        const vertex: *Vertex = try allocator.create(Vertex);
        vertex.* =  Vertex {
            .left = lb,
            .right = rb,
            .allocator = allocator,
        };
        return vertex;
    }

    fn extend(self: *Vertex) !void {
        if (self.left_child == null and self.left < self.right) {
            var mid64: i64 = self.left;
            mid64 += self.right;
            mid64 = @divFloor(mid64, 2);
            const mid: i32 = @truncate(mid64);
            self.left_child = try Vertex.init(self.allocator, self.left, mid);
            self.right_child = try Vertex.init(self.allocator, mid + 1, self.right);
        }
    }

    pub fn add(self: *Vertex, loc: i32, val: i32) !void {
        try extend(self);
        self.sum += val;
        self.count += 1;
        
        //std.debug.print("Added {d} to node [{d}, {d}]\n", .{ val, self.left, self.right});

        if (self.left_child) |lc| {
            if (loc <= lc.right) {
                try lc.add(loc, val);
            } else {
                try self.right_child.?.add(loc, val);
            }
        }
    }

    pub fn getSumAndCount(self: *Vertex, lq: i32, rq: i32) !struct { sum: i64, count: i32} {
        if (lq <= self.left and self.right <= rq) return .{ .sum = self.sum, .count = self.count };
        if (@max(lq, self.left) > @min(rq, self.right)) return .{ .sum = 0, .count = 0};
        try extend(self);
        
        const scl = try self.left_child.?.getSumAndCount(lq, rq);
        const scr = try self.right_child.?.getSumAndCount(lq, rq);
        return .{ .sum = scl.sum + scr.sum, .count = scl.count + scr.count };
    }

    pub fn deinit(self: *Vertex) void {
        if (self.left_child) |lc| {
            deinit(lc);
            deinit(self.right_child.?);
        }
        self.allocator.destroy(self);
    }
};

test "protohackers example" {
    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    
    //const allocator = arena.allocator();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var SST: *Vertex = try Vertex.init(allocator, 0, 6);
    defer SST.deinit();

    std.debug.print("2^32 - 1 == {any}\n", .{(1 << 32) - 1});
    try SST.add(1, 101);
    try SST.add(3, 102);
    try SST.add(5, 100);
    //try SST.add(40960, 5);
    
    const res = try SST.getSumAndCount(2, 4);

    try std.testing.expect(res.sum == 102);
    try std.testing.expect(res.count == 1);
}
