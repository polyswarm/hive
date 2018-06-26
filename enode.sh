#! /bin/sh                                                                                                                                                                                                       

enode=\\`curl -s -X POST -H \\\"Content-Type: application/json\\\" --data '{\\\"jsonrpc\\\":\\\"2.0\\\",\\\"method\\\":\\\"admin_nodeInfo\\\",\\\"params\\\":[\\\"latest\\\", true],\\\"id\\\":1}' \\\"\\${CHAIN}\\\" | jq -r \\\".result.enode\\\"\\`
echo \\$enode > /build/enode

