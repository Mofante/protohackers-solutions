const std = @import("std");
const net = std.net;
const print = std.debug.print;
const expect = std.testing.expect;

const Response = struct {
    method: []const u8,
    prime: bool,
};

fn handleClient(allocator: std.mem.Allocator, client: net.Server.Connection) !void {
    var buff: [32768]u8 = undefined; //buffer is huge because of one nasty test

    while (true) {
        const message = try client.stream.reader().readUntilDelimiterOrEof(&buff, '\n');

        if (message == null) break;
        if (std.mem.eql(u8, message.?, "")) continue;
        
        print("req: {s}\n", .{ message.? });

        var res: Response = undefined;
        
        //check if request is valid json and parse
        const req : std.json.Parsed(std.json.Value) =
            std.json.parseFromSlice(std.json.Value, allocator, message.?, .{}) catch {
                _ = try client.stream.write("Invalid Request!\n");
                break;
            };
        defer req.deinit();

        const req_json: std.json.Value = req.value;
        
        //check if the "method" field is set to "isPrime"
        if (req_json.object.get("method")) |method_field| {
            if (method_field != .string or !std.mem.eql(u8, method_field.string, "isPrime")) {
                _ = try client.stream.write("Invalid Request!\n");
                break;
            }
        } else {
            _ = try client.stream.write("Invalid Request!\n");
            break;
        }
        
        //check if the "number" field is a valid number and parse accodingly
        if (req_json.object.get("number")) |number_field| {
            var is_prime: bool = undefined;
            if (number_field == .float) {
                const num: f64 = number_field.float;
                is_prime = (@floor(num) == @ceil(num) and isPrime(@intFromFloat(num)));
            } else if (number_field == .integer) {
                const num: i64 = number_field.integer;
                is_prime = isPrime(num);
            } else if (number_field == .number_string) {
                const num: i512 = try std.fmt.parseInt(i512, number_field.number_string, 10);
                is_prime = isPrime(num);
            } else {
                _ = try client.stream.write("Invalid Request!\n");
                break;
            }
            res = Response{ .method = "isPrime", .prime = is_prime };
        } else {
            _ = try client.stream.write("Invalid Request!\n");
            break;
        }
        
        const response_string = try std.json.stringifyAlloc(allocator, res, .{});
        defer allocator.free(response_string);
        
        print("response: {s}\n", .{ response_string });

        //add newline at the end of a string
        const newline = "\n";
        const string_with_newline = try std.mem.concat(allocator, u8, &[_][]const u8{ response_string, newline });
        defer allocator.free(string_with_newline);

        _ = try client.stream.write(string_with_newline);
    }

    client.stream.close();
    print("Client disconnected!\n", .{});
}

//prime check for integers up to 512 bits
fn isPrime(number: i512) bool {
    var i: i512 = 2;

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
