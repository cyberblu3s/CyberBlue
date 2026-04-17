##! CyberBlueSOC - Zeek site policy
##!
##! Loads the standard Zeek policy plus a few high-value additions:
##!  - JSON output for easy ingestion into OpenSearch / Wazuh-indexer
##!  - File extraction for hashes (MD5, SHA1, SHA256)
##!  - Notice forwarding suitable for SIEM consumption
##!  - Common protocol analyzers enabled

@load base/protocols/conn
@load base/protocols/dns
@load base/protocols/http
@load base/protocols/ssl
@load base/protocols/ssh
@load base/protocols/smtp
@load base/protocols/ftp
@load base/protocols/dhcp
@load base/protocols/ntp
@load base/protocols/snmp
@load base/protocols/krb
@load base/protocols/smb
@load base/files/hash
@load base/files/extract

@load policy/protocols/conn/known-hosts
@load policy/protocols/conn/known-services
@load policy/protocols/ssl/known-certs
@load policy/protocols/ssl/validate-certs
@load policy/protocols/http/detect-sqli
@load policy/protocols/dns/detect-external-names

@load policy/frameworks/files/hash-all-files

redef LogAscii::use_json = T;

redef Site::local_nets = {
    10.0.0.0/8,
    172.16.0.0/12,
    192.168.0.0/16,
};
