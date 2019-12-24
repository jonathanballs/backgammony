module upnp;
import std.stdio;
import std.socket;

// Service discovery
void serviceDiscovery() {
    auto msg = "M-SEARCH * HTTP/1.1\r\n"
        ~ "HOST:239.255.255.250:1900\r\n"
        ~ "ST:upnp:rootdevice\r\n"
        ~ "MX:2\r\n"
        ~ "MAN:\"ssdp:discover\"\r\n"
        ~ "\r\n";
    
    auto socket = new UdpSocket(AddressFamily.INET);
    auto address = new InternetAddress("239.255.255.250", 1900);
    auto sent = socket.sendTo(msg, address);
    writeln(sent);
    writeln(msg);
    while(true) {
        ubyte[1000] buf;
        auto numrec = socket.receiveFrom(buf);
        if (numrec) writeln(cast(string) (buf[0..numrec]));
    }
}
