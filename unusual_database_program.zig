const std = @import("std");
const net = std.net;
const print = std.debug.print;

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
    const parsed_ipv4 = try net.Address.parseIp4(ipv4, port_number);

    const sock: std.posix.socket_t = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.DGRAM, 0);
    defer std.posix.close(sock);

    try std.posix.bind(sock, &parsed_ipv4.any, parsed_ipv4.getOsSockLen());

    print("Listening on {}...\n", .{ port_number });
    
    const client_address: *std.posix.sockaddr = try allocator.create(std.posix.sockaddr);
    var client_address_size: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);
    
    var store = std.StringHashMap([]u8).init(allocator);
    defer store.deinit();

    var buffer: [1024]u8 = undefined;
    //listen for incoming connections and create a new thread for each client
    while (true) {
        const len = try std.posix.recvfrom(sock, &buffer, 0, client_address, &client_address_size);
    
        print("Received {d} bytes from {any}.\nstring: {s}\n", .{ len, client_address, buffer[0..len] });
        
        if (std.mem.indexOf(u8, buffer[0..len], "=")) |ind| {
            const key = try allocator.dupe(u8, buffer[0..ind]);
            const value = try allocator.dupe(u8, buffer[ind+1..len]);
            try store.put(key, value);
        } else {
            if (std.mem.eql(u8, buffer[0..len], "version")) {
                const response = "version=1.0";
                _ = try std.posix.sendto(sock, response, 0, client_address, client_address_size);
            } else {
                const val: []u8 = store.get(buffer[0..len]) orelse "";
                const response = try std.mem.concat(allocator, u8, &[_][]const u8{ buffer[0..len], "=", val[0..val.len]});
                print("res: {s}\n", .{ response });
                _ = try std.posix.sendto(sock, response, 0, client_address, client_address_size);
            }
        }
    }
}
