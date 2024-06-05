const std = @import("std");
const net = std.net;
const print = std.debug.print;

fn echo(client: net.Server.Connection) !void {
    var message: [1024]u8 = undefined;
    
    while (true) {
        const len = try client.stream.read(&message);
        //if client has nothing else to send close the connection 
        if (len == 0) break;

        //send the message back to the client
        const write_len = try client.stream.write(message[0..len]);
        print("Sending {} bytes...\n", .{ write_len });
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

    const port_name = args_iter.next() orelse return error.MissingArgument;
    
    //parse port number to int
    const port_number = try std.fmt.parseInt(u16, port_name, 10);

    //parse local ipv6 to computer readable format
    const parsed_local_ipv6 = try net.Ip6Address.parse("::1", port_number);
    //create address struct
    const host = net.Address{ .in6 = parsed_local_ipv6 };


    var server = try host.listen(.{
        .reuse_address = true,
    });

    defer server.deinit();

    print("Listening on {}...\n", .{ port_number });
    
    //listen for incoming connections and create a new thread for each client
    while (true) {
        const client = try server.accept();

        print("Connection received! {} is sending data.\n", .{client.address});
        var thread = try std.Thread.spawn(.{}, echo, .{ client });
        defer thread.detach();
    }
}
