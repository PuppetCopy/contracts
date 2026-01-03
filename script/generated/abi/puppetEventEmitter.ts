// This file is auto-generated from forge-artifacts/EventEmitter.sol/EventEmitter.json
// Do not edit manually.

export default [
  {
    "type": "function",
    "name": "logEvent",
    "inputs": [
      {
        "name": "_method",
        "type": "string",
        "internalType": "string"
      },
      {
        "name": "_data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "PuppetEventLog",
    "inputs": [
      {
        "name": "source",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "method",
        "type": "string",
        "indexed": true,
        "internalType": "string"
      },
      {
        "name": "data",
        "type": "bytes",
        "indexed": false,
        "internalType": "bytes"
      }
    ],
    "anonymous": false
  }
] as const
