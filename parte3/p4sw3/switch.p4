/* Obligatorio 2 - Parte 2: esqueleto del switch P4 (v1model / BMv2).
 *
 * Provisto por el curso: definicion del encabezado Ethernet, parser y
 * deparser. El resto de la logica debe ser implementada por el grupo.
 */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
 *  Encabezados
 *************************************************************************/
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<8>  flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct headers_t {
    ethernet_t ethernet;
    ipv4_t     ipv4;
    tcp_t      tcp;
}

struct metadata_t {
}

/*************************************************************************
 *  Parser
 *************************************************************************/
parser MyParser(packet_in pkt,
                out headers_t hdr,
                inout metadata_t meta,
                inout standard_metadata_t std_meta) {
    state start {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            6: parse_tcp;
            default: accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }
}

/*************************************************************************
 *  Verificacion de checksum
 *************************************************************************/
control MyVerifyChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply { }
}

/*************************************************************************
 *  Ingress
 *************************************************************************/
control MyIngress(inout headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t std_meta) {

    counter(512, CounterType.packets) pkts_in;
    counter(2, CounterType.packets) acl_cnt;
    counter(2, CounterType.packets) port_security_cnt;

    action send_to(bit<9> port) {
        std_meta.egress_spec = port;
    }

    action distribute() {
        std_meta.mcast_grp = 123;
    }

    action drop() {
        mark_to_drop(std_meta);
    }

    action allow() {
        acl_cnt.count(0);
    }

    action deny() {
        acl_cnt.count(1);
        mark_to_drop(std_meta);
    }

    table acl {
        key = {
            std_meta.ingress_port: ternary;
            hdr.ethernet.etherType: ternary;
            hdr.ipv4.dstAddr: ternary;
            hdr.ipv4.protocol: ternary;
            hdr.tcp.dstPort: ternary;
        }
        actions = {allow; deny;}
        default_action = deny();
    }

    action src_authorized() {
    }

    action src_unauthorized() {
        port_security_cnt.count(1);
        mark_to_drop(std_meta);
    }

    table port_security {
        key = {
            std_meta.ingress_port: exact;
            hdr.ethernet.srcAddr: exact;
        }
        actions = {src_authorized; src_unauthorized;}
        default_action = src_unauthorized();
    }

    table send_frame {
        key = { hdr.ethernet.dstAddr: exact; }
        actions = {send_to; drop; distribute;}
        default_action = drop();
    }

    apply {
        pkts_in.count((bit<32>) std_meta.ingress_port);
        switch (port_security.apply().action_run) {
            src_authorized: { 
                switch (acl.apply().action_run) {
                    allow: {
                        send_frame.apply(); 
                    }
                }
            }
        }
    }
}

/*************************************************************************
 *  Egress
 *************************************************************************/
control MyEgress(inout headers_t hdr,
                 inout metadata_t meta,
                 inout standard_metadata_t std_meta) {
    counter(64, CounterType.packets) pkts_out;
    apply {
        if (std_meta.egress_port == std_meta.ingress_port) {
            mark_to_drop(std_meta);
        } else {
            pkts_out.count((bit<32>) std_meta.egress_port);
        }
    }
}

/*************************************************************************
 *  Calculo de checksum
 *************************************************************************/
control MyComputeChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply { }
}

/*************************************************************************
 *  Deparser
 *************************************************************************/
control MyDeparser(packet_out pkt, in headers_t hdr) {
    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.tcp);
    }
}

V1Switch(MyParser(),
         MyVerifyChecksum(),
         MyIngress(),
         MyEgress(),
         MyComputeChecksum(),
         MyDeparser()) main;
