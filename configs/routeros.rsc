/routing ospf instance
add disabled=no name=ospf-main router-id=***ROUTER-ID(Router's IP)***
/routing ospf area
add disabled=no instance=ospf-main name=***OSPF-AREA-NAME***
/routing ospf interface-template
add area=***OSPF-AREA-NAME*** auth=md5 auth-id=1 auth-key=***CHANGE WITH YOUR KEY*** cost=10 disabled=no \
    interfaces=***WIREGUARD-INTERFACE*** networks=***WIREGUARD-NETWORK(x.x.x.x/x)*** priority=10 type=ptp


/interface wireguard
add listen-port=51820 mtu=1420 name=***WIREGUARD-INTERFACE***
/interface wireguard peers
add allowed-address=0.0.0.0/0 client-address=::/0 endpoint-address=***PEER-PUB-IP*** endpoint-port=51820 interface=***WIREGUARD-INTERFACE*** name=***PEER-NAME*** persistent-keepalive=\
    10s public-key=***PEER-PUB-KEY***
