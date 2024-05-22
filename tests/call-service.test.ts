import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";
import { encode } from "rlp";

const CALL_SERVICE_CONTRACT_NAME = "call-service";
const ICON_NID = "0x2.ICON";
const ICON_DAPP_NETWORK_ADDRESS = "0xa";
const BASE_ICON_CONNECTION = "0xb";
const STACKS_NID = "0x1.STACKS";
const STACKS_DAPP_NETWORK_ADDRESS = "0xc";

describe("call-service", () => {
  const accounts = simnet.getAccounts();
  const deployer = accounts.get("deployer");
  const user = accounts.get("wallet_1")!;
  const xCallClarity = Cl.contractPrincipal(
    deployer!,
    CALL_SERVICE_CONTRACT_NAME
  );

  it("allows the admin to set a new admin", () => {
    const newAdmin = Cl.address(user);

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "set-admin",
      [newAdmin],
      deployer!
    );

    expect(result).toBeOk(Cl.bool(true));

    const { result: adminResult } = simnet.callReadOnlyFn(
      xCallClarity.contractName.content,
      "get-admin",
      [],
      deployer!
    );

    expect(adminResult).toBeOk(newAdmin);
  });

  it("allows the admin to set the protocol fee", () => {
    const newFee = 500;

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "set-protocol-fee",
      [Cl.uint(newFee)],
      deployer!
    );

    expect(result).toBeOk(Cl.bool(true));

    const { result: feeResult } = simnet.callReadOnlyFn(
      xCallClarity.contractName.content,
      "get-protocol-fee",
      [],
      deployer!
    );

    expect(feeResult).toBeOk(Cl.uint(newFee));
  });

  it("allows the admin to set the fee handler", () => {
    const newHandler = Cl.address(user);

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "set-fee-handler",
      [newHandler],
      deployer!
    );

    expect(result).toBeOk(Cl.bool(true));

    const { result: handlerResult } = simnet.callReadOnlyFn(
      xCallClarity.contractName.content,
      "get-fee-handler",
      [],
      deployer!
    );

    expect(handlerResult).toBeOk(newHandler);
  });

  it("allows the admin to set the default connection for a chain", () => {
    const chainId = "test-chain";
    const connection = Cl.address(user);

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "set-default-connection",
      [Cl.stringAscii(chainId), connection],
      deployer!
    );

    expect(result).toBeOk(Cl.bool(true));

    const { result: connectionResult } = simnet.callReadOnlyFn(
      xCallClarity.contractName.content,
      "get-default-connection",
      [Cl.stringAscii(chainId)],
      deployer!
    );

    expect(connectionResult).toBeOk(connection);
  });

  it("allows sending a cross-chain message with sufficient fee", () => {
    const to = ICON_DAPP_NETWORK_ADDRESS;
    const data = Uint8Array.from(encode(["test-message"]));
    const fee = 1000;

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "send-message",
      [Cl.stringAscii(to), Cl.buffer(data), Cl.none(), Cl.uint(fee)],
      user
    );

    expect(result).toBeOk(Cl.bool(true));
  });

  it("fails to send a cross-chain message with insufficient fee", () => {
    const to = ICON_DAPP_NETWORK_ADDRESS;
    const data = Uint8Array.from(encode(["test-message"]));
    const fee = 500;

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "send-message",
      [Cl.stringAscii(to), Cl.buffer(data), Cl.none(), Cl.uint(fee)],
      user
    );

    expect(result).toBeErr(Cl.uint(103));
  });

  it("handles an incoming cross-chain message with valid sequence", () => {
    const from = ICON_DAPP_NETWORK_ADDRESS;
    const sequence = 1;
    const data = Uint8Array.from(encode(["test-message"]));

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "handle-message",
      [Cl.stringAscii(from), Cl.uint(sequence), Cl.buffer(data)],
      user
    );

    expect(result).toBeOk(Cl.bool(true));
  });

  it("fails to handle an incoming cross-chain message with invalid sequence", () => {
    const from = ICON_DAPP_NETWORK_ADDRESS;
    const sequence = 2;
    const data = Uint8Array.from(encode(["test-message"]));

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "handle-message",
      [Cl.stringAscii(from), Cl.uint(sequence), Cl.buffer(data)],
      user
    );

    expect(result).toBeErr(Cl.uint(102));
  });

  it("executes a cross-chain message successfully", () => {
    const from = ICON_DAPP_NETWORK_ADDRESS;
    const to = STACKS_DAPP_NETWORK_ADDRESS;
    const sequence = 1;
    const data = Uint8Array.from(encode(["test-message"]));

    simnet.callPublicFn(
      xCallClarity.contractName.content,
      "handle-message",
      [Cl.stringAscii(from), Cl.uint(sequence), Cl.buffer(data)],
      user
    );

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "execute-message",
      [Cl.stringAscii(ICON_NID), Cl.uint(sequence), Cl.buffer(data)],
      user
    );

    expect(result).toBeOk(Cl.bool(true));
  });

  it("fails to execute a cross-chain message with invalid sequence", () => {
    const from = ICON_DAPP_NETWORK_ADDRESS;
    const to = STACKS_DAPP_NETWORK_ADDRESS;
    const sequence = 1;
    const data = Uint8Array.from(encode(["test-message"]));

    const { result } = simnet.callPublicFn(
      xCallClarity.contractName.content,
      "execute-message",
      [Cl.stringAscii(ICON_NID), Cl.uint(sequence), Cl.buffer(data)],
      user
    );

    expect(result).toBeErr(Cl.uint(107));
  });
});
