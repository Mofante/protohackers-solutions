# Protohackers challanges solutions in zig
https://protohackers.com
## Challenge 0 - Smoke Test
Implementation of the TCP echo service
## Challenge 1 - Prime Timet
Implementation of a simple JSON-based request-response protocol. Request is a valid JSON containing a number and a valid response is a valid JSON containing a boolean indicating weather the number is prime or not. (more details https://protohackers.com/problem/1)
## Challenge 2 - Means to an End
Implementation of a TCP server that accepts 2 types of requests:
 - Insert of a value at coordinate x in range [0, 2^32 - 1]
 - Query for average of values in between 2 coordinates


I decided to use a segment tree to handle insterts and queries in O(log(n)), but had to opt for the sparse variant, because the traditional implementation requires an array of size 2n, which (if i'm not wrong) in this case would take up 2 * 2^32 * 4B = 2^35B = 32 GB of memory per client. (which is quite a lot)


Whereas the sparse segement tree takes up O(k * log(n)) where k is number of inserts. This adds up to 200000 (largest test case) * log(2^32) * 4B = around 25 MB per client (which is quite a bit less)
## Challenge 2 - Budget Chat
Simple TCP-based chat room.
## Challenge 2 - Unusual Database Program
A key-value store allowing for insertion and retrieval over UDP.
