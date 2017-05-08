// Template parser.p4 file for ofdpa
// Edit this file as needed for your P4 program

// This parses an ethernet header

parser start {
    return parse_ethernet;
}


#define ETHERTYPE_VLAN         0x8100
#define ETHERTYPE_QINQ         0x9100
#define ETHERTYPE_IPV4         0x0800
#define ETHERTYPE_IPV6         0x86dd
#define ETHERTYPE_ETHERNET     0x6558

#define IPV4_MULTICAST_MAC 0x01005E
#define IPV6_MULTICAST_MAC 0x3333

/* Tunnel types */
#define INGRESS_TUNNEL_TYPE_NONE               0

#define PARSE_ETHERTYPE                                    \
        ETHERTYPE_VLAN : parse_vlan;                       \
        ETHERTYPE_QINQ : parse_qinq;                       \
        ETHERTYPE_IPV4 : parse_ipv4;                       \
        ETHERTYPE_IPV6 : parse_ipv6;                       \
        default: ingress

#define PARSE_ETHERTYPE_MINUS_VLAN                         \
        ETHERTYPE_IPV4 : parse_ipv4;                       \
        ETHERTYPE_IPV6 : parse_ipv6;                       \
        default: ingress


header ethernet_t ethernet;


parser parse_ethernet {
    extract(ethernet);
    return select(latest.etherType) {
        PARSE_ETHERTYPE;
    }
}



#define VLAN_DEPTH 2
header vlan_tag_t vlan_tag_[VLAN_DEPTH];

parser parse_vlan {
    extract(vlan_tag_[0]);
    return select(latest.etherType) {
        PARSE_ETHERTYPE_MINUS_VLAN;
    }
}

parser parse_qinq {
    extract(vlan_tag_[0]);
    return select(latest.etherType) {
        ETHERTYPE_VLAN : parse_qinq_vlan;
        default : ingress;
    }
}

parser parse_qinq_vlan {
    extract(vlan_tag_[1]);
    return select(latest.etherType) {
        PARSE_ETHERTYPE_MINUS_VLAN;
    }
}


#define IP_PROTOCOLS_IPV4              4
#define IP_PROTOCOLS_TCP               6
#define IP_PROTOCOLS_UDP               17
#define IP_PROTOCOLS_IPV6              41


#define IP_PROTOCOLS_IPHL_IPV4         0x504
#define IP_PROTOCOLS_IPHL_TCP          0x506
#define IP_PROTOCOLS_IPHL_UDP          0x511
#define IP_PROTOCOLS_IPHL_IPV6         0x529


header ipv4_t ipv4;

field_list ipv4_checksum_list {
        ipv4.version;
        ipv4.ihl;
        ipv4.diffserv;
        ipv4.totalLen;
        ipv4.identification;
        ipv4.flags;
        ipv4.fragOffset;
        ipv4.ttl;
        ipv4.protocol;
        ipv4.srcAddr;
        ipv4.dstAddr;
}

field_list_calculation ipv4_checksum {
    input {
        ipv4_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}

calculated_field ipv4.hdrChecksum  {
    verify ipv4_checksum;
    update ipv4_checksum;
}


parser parse_ipv4 {
    extract(ipv4);
    return select(latest.fragOffset, latest.ihl, latest.protocol) {
        IP_PROTOCOLS_IPHL_TCP : parse_tcp;
        IP_PROTOCOLS_IPHL_UDP : parse_udp;
        default: ingress;
    }
}


header ipv6_t ipv6; 

parser parse_ipv6 {
    extract(ipv6);
    return select(latest.nextHdr) {
        IP_PROTOCOLS_TCP : parse_tcp;
        IP_PROTOCOLS_UDP : parse_udp_v6;
        default: ingress;
    }
}

header udp_t udp;

parser parse_udp_v6 {
    extract(udp);
    return ingress;
}


header tcp_t tcp;


parser parse_tcp {
    extract(tcp);
    set_metadata(l3_metadata.lkp_outer_l4_sport, latest.srcPort);
    set_metadata(l3_metadata.lkp_outer_l4_dport, latest.dstPort);
    return ingress;
}


parser parse_udp {
    extract(udp);
    set_metadata(l3_metadata.lkp_outer_l4_sport, latest.srcPort);
    set_metadata(l3_metadata.lkp_outer_l4_dport, latest.dstPort);
    return ingress;
}