const std = @import("std");
const print = std.debug.print;
const net = std.net;

var names: std.StringArrayHashMap(net.Server.Connection) = undefined;
var mutex: std.Thread.Mutex = undefined;

fn disconnectWithMessage(client: net.Server.Connection, message: []const u8) void {
    _ = client.stream.write(message) catch {
        client.stream.close();
        return;
    };

    client.stream.close();
}

fn sendToAll(comptime format: []const u8, args: anytype) !void {
    mutex.lock();
    for (names.values()) |user| {
        _ = try user.stream.writer().print(format, args);
    }
    mutex.unlock();
}

fn handleClient(allocator: std.mem.Allocator, client: net.Server.Connection) !void {
    _ = try client.stream.write("Welcome to budgetchat! What shall I call you?\n");
    var name_buff: [32]u8 = undefined;
    
    const name = client.stream.reader().readUntilDelimiterOrEof(&name_buff, '\n') catch {
        disconnectWithMessage(client, "chosen name is too long!\n");
        return;
    };

    if (name == null or name.?.len == 0) {
        disconnectWithMessage(client, "You must provide a name!\n");
        return;
    }

    for (name.?) |c| {
        if (c < 48 or (c > 57 and c < 65) or (c > 90 and c < 97) or c > 122) {
            disconnectWithMessage(client, "Name must not contain special characters!\n");
            return;
        }
    }

    if (names.contains(name.?)) {
        disconnectWithMessage(client, "This name is already taken!\n");
        return;
    }

    try sendToAll("* {s} has entered the room.\n", .{ name.? });

    try client.stream.writer().print("* The room contains: {s}\n", .{ names.keys() });

    mutex.lock();
    try names.put(name.?, client);
    mutex.unlock();

    defer {
        mutex.lock();
        _ = names.swapRemove(name.?);
        mutex.unlock();
        sendToAll("* {s} has left the room.\n", .{ name.? }) catch |err| print("err: {}", .{ err });
        client.stream.close();
    }

    const buffer: []u8 = try allocator.alloc(u8, 1024);

    while(true) {
        const message = try client.stream.reader().readUntilDelimiterOrEof(buffer, '\n');
        if (message) |m| {
            if (m.len == 0) break;
            var iter = names.iterator();
            mutex.lock();
            while (iter.next()) |entry| {
                if (std.mem.eql(u8, entry.key_ptr.*, name.?)) continue;
                _ = try entry.value_ptr.stream.writer().print("[{s}] {s}\n", .{ name.?, m });
            }
            mutex.unlock();
        } else break;
    }
    
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
    
    names = std.StringArrayHashMap(net.Server.Connection).init(allocator);
    defer names.deinit();

    mutex = .{};
    
    //listen for incoming connections and create a new thread for each client
    while (true) {
        const client = try server.accept();

        print("Connection received! {} is sending data.\n", .{client.address});
        var thread = try std.Thread.spawn(.{}, handleClient, .{ allocator, client });
        defer thread.detach();
    }
}
