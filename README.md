[![codecov](https://codecov.io/github/CyrusVorwald/xcall-clarity-contracts/graph/badge.svg?token=8G28RT32CM)](https://codecov.io/github/CyrusVorwald/xcall-clarity-contracts)

# xCall Clarity Implementation

This repository contains an implementation of the xCall protocol in Clarity, a smart contract language for the Stacks blockchain. The xCall protocol enables cross-chain communication and interoperability between different blockchain networks.

## Deviations from xCall Specification

While this Clarity implementation aims to provide similar functionality to the [xCall specification](https://github.com/icon-project/xcall-multi/blob/main/docs/adr/xcall.md), there are some key differences due to the characteristics and limitations of the Clarity language.

Clarity does not support dynamic dispatch, meaning that generic contract calls are not possible. In the xCall specification, the `handleCallMessage` function can dynamically call the target contract based on the provided contract address. However, in the Clarity implementation, the contract calls need to be explicitly defined and hardcoded.

Due to the limitations of dynamic dispatch in Clarity, this implementation takes a library approach. It provides a set of utility functions for tracking message sequences, ensuring message safety, and handling cross-chain communication. The actual execution of messages on target contracts needs to be handled explicitly by the calling contract.

xCall's specification defines a built-in fee management system for setting and collecting protocol fees. In Clarity, the fee management functionality is pushed to the dApp.

Despite these differences, this implementation aims to provide a standard for enabling cross-chain communication and interoperability within the Stacks ecosystem. It offers a set of utilities and patterns that can be used by Clarity smart contracts to facilitate cross-chain interactions.

Please refer to the source code and documentation in this repository for more details on how to use and integrate the xCall Clarity implementation into your Stacks-based projects.
