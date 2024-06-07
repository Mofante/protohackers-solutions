const std = @import("std");
const net = std.net;
const print = std.debug.print;
const expect = std.testing.expect;
const json = std.json;

const Request1 = struct {
    method: []const u8,
    number: i64,
};

const Request2 = struct {
    method: []const u8,
    number: f64,
};

const Request3 = struct {
    method: []const u8,
    number: []const u8,
};

const Response = struct {
    method: []const u8,
    prime: bool,
};

fn handleClient(allocator: std.mem.Allocator, client: net.Server.Connection) !void {
    var buff: [1024]u8 = undefined;

    while (true) {
        const message = try client.stream.reader().readUntilDelimiterOrEof(&buff, '\n');

        if (message == null) break;
        if (std.mem.eql(u8, message.?, "")) continue;
        
        print("req: {s}\n", .{ message.? });

        const req1: ?json.Parsed(Request1) = json.parseFromSlice(Request1, allocator, message.?, .{ .ignore_unknown_fields = true }) catch null;
        const req2: ?json.Parsed(Request2) = json.parseFromSlice(Request2, allocator, message.?, .{ .ignore_unknown_fields = true }) catch null;
        const req3: ?json.Parsed(Request3) = json.parseFromSlice(Request3, allocator, message.?, .{ .ignore_unknown_fields = true }) catch null;

        var res: Response = undefined;

        if (req1) |req| {
            defer req.deinit();
            
            if (!std.mem.eql(u8, req.value.method, "isPrime")) {
                _ = try client.stream.write("Invalid request!\n");
                break;
            }
        
            res = Response{ .method = "isPrime", .prime = isPrime(req.value.number)};
        } else if (req2) |req| {
            defer req.deinit();
            
            if (!std.mem.eql(u8, req.value.method, "isPrime")) {
                _ = try client.stream.write("Invalid request!\n");
                break;
            }
            
            const is_prime = (@floor(req.value.number) == @ceil(req.value.number)) and isPrime(@intFromFloat(req.value.number));
            res = Response{ .method = "isPrime", .prime = is_prime };
        } else if (req3) |req| {
            defer req.deinit();
            
            if (!std.mem.eql(u8, req.value.method, "isPrime")) {
                _ = try client.stream.write("Invalid request!\n");
                break;
            }
            
            const num: ?i64 = std.fmt.parseInt(i64, req.value.number, 10) catch null;
            
            if (num) |n| {
                res = Response{ .method = "isPrime", .prime = isPrime(n)};
            } else {
                _ = try client.stream.write("Invalid request!\n");
                break;
            }
        } else {
            _ = try client.stream.write("Invalid request!\n");
            break;
        }

        const response_string = try json.stringifyAlloc(allocator, res, .{});
        defer allocator.free(response_string);
        
        print("response: {s}\n", .{ response_string });

        const newline = "\n";
        const string_with_newline = try std.mem.concat(allocator, u8, &[_][]const u8{ response_string, newline });
        defer allocator.free(string_with_newline);

        _ = try client.stream.write(string_with_newline);
    }

    client.stream.close();
    print("Client disconnected!\n", .{});
}

fn isPrime(number: i64) bool {
    var i: i64 = 2;

    if (number < 2) return false;
    if (number < 4) return true;

    return while (i * i <= number) : (i += 1) {
        if (@mod(number, i) == 0) {
            break false;
        }
    } else true;
}

test "is_prime" {
    try expect(isPrime(0) == false);
    try expect(isPrime(2) == true);
    try expect(isPrime(3) == true);
    try expect(isPrime(4) == false);
    try expect(isPrime(7) == true);
    try expect(isPrime(8) == false);
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

    const ipv6 = args_iter.next() orelse return error.MissingArgument;
    const port_name = args_iter.next() orelse return error.MissingArgument;
    
    //parse port number to int
    const port_number = try std.fmt.parseInt(u16, port_name, 10);

    //parse local ipv6 to computer readable format
    const parsed_local_ipv6 = try net.Ip6Address.parse(ipv6, port_number);
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
        var thread = try std.Thread.spawn(.{}, handleClient, .{ allocator, client });
        defer thread.detach();
    }
}
