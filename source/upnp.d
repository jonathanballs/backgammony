module upnp;
import std.stdio;
import std.socket;
import std.string;
import std.array;
import std.uni;
import std.xml;
import core.thread;

import url;
import requests;

/// Finds the IGD SOAP url for a UPnP device location.
private string getIGDurl(string location) {
    string IGDUrl = "";

    try {
        auto req = Request();
        req.timeout = 2.seconds;
        Response resp = req.get(location);

        // TODO: get baseurl from response
        auto url = parseURL(location);
        url.path = "";

        // Parse XML to find device type
        check(cast(string) resp.responseBody);

        auto xml = new DocumentParser(cast(string) resp.responseBody);
        xml.onEndTag["deviceType"]       = (in Element e) {
            if (e.text() == "urn:schemas-upnp-org:device:InternetGatewayDevice:1") {
                // Find services
                xml.onStartTag["service"] = (ElementParser xml) {
                    string serviceType;
                    string controlURL;
                    xml.onEndTag["serviceType"]   = (in Element e) { serviceType = e.text(); };
                    xml.onEndTag["controlURL"]    = (in Element e) { controlURL  = e.text(); };
                    xml.parse();

                    if (serviceType == "urn:schemas-upnp-org:service:WANPPPConnection:1") {
                        url.path = controlURL;
                        IGDUrl = url.toString();
                    }
                };
            }
        };
        xml.parse();

    } catch (Exception e) {
        writeln("Error getting IGD URL: ", location);
    }

    return IGDUrl;
}

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
    socket.blocking = true;
    auto sent = socket.sendTo(msg, address);

    // Wait for three seconds to receive response
    Thread.sleep(3.seconds);

    socket.blocking = false;
    ubyte[10_000] buf;
    long numBytesRecieved;

    do {
        numBytesRecieved = socket.receiveFrom(buf);
        if (numBytesRecieved > 0) {
            auto response = cast(string) (buf[0..numBytesRecieved]);
            auto headers = response.split('\n');
            foreach (header; headers) {
                auto headerKV = header.split(": ");
                if (headerKV.length < 2) continue;
                if (headerKV[0].toLower() == "location") {
                    auto IGDLocation = getIGDurl(headerKV[1].chomp);
                    if (IGDLocation.length) writeln("Final IGD: ", IGDLocation);
                }
            }
        }

    } while(numBytesRecieved > 0);

    // Get information about these clients
}
