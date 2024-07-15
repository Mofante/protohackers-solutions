const std = @import("std");
const print = std.debug.print;
const net = std.net;
const SST = @import("sparse_segment_tree.zig").Vertex;

fn handleClient(allocator: std.mem.Allocator, client: net.Server.Connection) !void {
    const sst: *SST = try SST.init(allocator, 0, (1 << 31) - 1);
    defer sst.deinit();
    
    while (true) {
        const req: [9]u8 = client.stream.reader().readBytesNoEof(9) catch break;
    
        if (req[0] == 'Q') {
            const t1: i32 = 
                std.mem.bigToNative(i32, std.mem.bytesToValue(i32, req[1..5]));
            const t2: i32
                = std.mem.bigToNative(i32, std.mem.bytesToValue(i32, req[5..9]));
            
            print("Received query: {d}, {d}\n", .{ t1, t2 });

            const result = try sst.getSumAndCount(t1, t2);
            const avg: i64 = if (result.count != 0) @divFloor(result.sum, result.count)
                        else 0;
            
            _ = try client.stream.write(&std.mem.toBytes(std.mem.nativeToBig(i32, @truncate(avg))));

            print("Sent result {d}\n", .{ avg });
        } else if (req[0] == 'I') {
            const timestamp: i32 =
                std.mem.bigToNative(i32, std.mem.bytesToValue(i32, req[1..5]));
            const value: i32 =
                std.mem.bigToNative(i32, std.mem.bytesToValue(i32, req[5..9]));
    
            print("Received insert: {d}, {d}\n", .{ timestamp, value });
            
            try sst.add(timestamp, value);
        } else {
            continue;
        }
    }
    client.stream.close();
    print("Client disconnected!\n", .{});
}

pub fn main() !void {
    //initialize memory allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    
    //get instance of allocator
    const allocator = gpa.allocator();
    
    defer {
        const allocator_status = gpa.deinit();
        if (allocator_status == .leak) print("Memory leak detected!\n", .{});
    }
    
    //process command line args
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    //skip program name
    _  = args_iter.next();

    const ipv4 = args_iter.next() orelse return error.MissingArgument;
    const port_name = args_iter.next() orelse return error.MissingArgument;
    
    //parse port number to int
    const port_number = try std.fmt.parseInt(u16, port_name, 10);

    //parse local ipv4 to computer readable format
    const parsed_local_ipv4 = try net.Ip4Address.parse(ipv4, port_number);
    //create address struct
    const host = net.Address{ .in = parsed_local_ipv4 };


    var server = try host.listen(.{
        .reuse_address = true,
    });

    defer server.deinit();

    print("Listening on {}...\n", .{ port_number });
    
    //listen for incoming connections and create a new thread for each client
    while (true) {
        const client = try server.accept();

        print("Connection received! {} is sending data.\n", .{client.address});
        var thread = try std.Thread.spawn(.{}, handleClient, .{ allocator, client });
        defer thread.detach();
    }
}
