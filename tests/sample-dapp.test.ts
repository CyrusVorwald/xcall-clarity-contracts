import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";
import { encode } from "rlp";

const DAPP_SAMPLE_CONTRACT_NAME = "dapp-sample";
const CALL_SERVICE_CONTRACT_NAME = "call-service";
const CALL_SERVICE_NETWORK_ADDRESS = "stacks-address";

describe("dapp-sample", () => {
  const accounts = simnet.getAccounts();
  const deployer = accounts.get("deployer")!;
  const user = accounts.get("wallet_1")!;
  const callService = accounts.get("wallet_2")!;
  const dappSampleContract = Cl.contractPrincipal(deployer, DAPP_SAMPLE_CONTRACT_NAME);
  const callServiceContract = Cl.contractPrincipal(callService, CALL_SERVICE_CONTRACT_NAME);

  it("should initialize the contract correctly", () => {
    const { result } = simnet.callPublicFn(
      dappSampleContract.contractName.content,
      "send-message",
      [Cl.stringAscii("to"), Cl.bufferFromAscii("0x00"), Cl.bufferFromAscii("0x00")],
      user
    );

    const { result: callSvcResult } = simnet.callReadOnlyFn(
      dappSampleContract.contractName.content,
      "call-svc",
      [],
      deployer
    );

    expect(callSvcResult).toEqual(callServiceContract);
  });

  it("should send a message without rollback", () => {
    const { result } = simnet.callPublicFn(
      dappSampleContract.contractName.content,
      "send-message",
      [Cl.stringAscii("to"), Cl.bufferFromAscii("0x1234"), Cl.bufferFromAscii("0x00")],
      user
    );
  });

  it("should send a message with rollback", () => {
    const { result } = simnet.callPublicFn(
      dappSampleContract.contractName.content,
      "send-message",
      [Cl.stringAscii("to"), Cl.bufferFromAscii("0x1234"), Cl.bufferFromAscii("0x5678")],
      user
    );
  });

  it("should handle a call message with rollback", () => {
    const id = 1;
    const rollback = "0x5678";
    const ssn = 100;

    simnet.callPublicFn(
      dappSampleContract.contractName.content,
      "map-set",
      [Cl.stringAscii("rollbacks"), Cl.uint(id), Cl.tuple({ id: Cl.uint(id), rollback: Cl.bufferFromAscii(rollback), ssn: Cl.uint(ssn) })],
      deployer
    );

    const data = Cl.buffer(encode([id, rollback]));

    simnet.callPublicFn(
      dappSampleContract.contractName.content,
      "handle-call-message",
      [Cl.stringAscii(CALL_SERVICE_NETWORK_ADDRESS), data],
      callService
    );

    const mapEntry = simnet.getMapEntry(
      dappSampleContract.contractName.content,
      "rollbacks",
      Cl.uint(id)
    );

    expect(mapEntry).toEqual(Cl.some(Cl.tuple({ id: Cl.uint(id), rollback: Cl.bufferFromAscii(rollback), ssn: Cl.uint(ssn) })));
  });

  it("should handle a call message with mismatched rollback", () => {
    const id = 1;
    const rollback = "0x5678";
    const mismatchedRollback = "0x1234";
    const ssn = 100;

    // Set up the rollback data in the map
    simnet.callPublicFn(
      dappSampleContract.contractName.content,
      "map-set",
      [Cl.stringAscii("rollbacks"), Cl.uint(id), Cl.tuple({ id: Cl.uint(id), rollback: Cl.bufferFromAscii(rollback), ssn: Cl.uint(ssn) })],
      deployer
    );

    // Encode the input data using RLP
    const data = Cl.buffer(encode([id, mismatchedRollback]));

    // Call the handle-call-message function
    const { result } = simnet.callPublicFn(
      dappSampleContract.contractName.content,
      "handle-call-message",
      [Cl.stringAscii(CALL_SERVICE_NETWORK_ADDRESS), data],
      callService
    );

    expect(result).toBeErr(Cl.stringAscii("ERR_ROLLBACK_MISMATCH"));
  });

  it("should handle a call message without rollback", () => {
    const data = "0x1234";

    // Call the handle-call-message function
    const { result } = simnet.callPublicFn(
      dappSampleContract.contractName.content,
      "handle-call-message",
      [Cl.bufferFromAscii("from"), Cl.bufferFromAscii(data)],
      callService
    );
  });
});
