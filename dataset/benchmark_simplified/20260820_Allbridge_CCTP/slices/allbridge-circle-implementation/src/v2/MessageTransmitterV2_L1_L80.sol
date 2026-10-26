/*
 * Copyright 2024 Circle Internet Group, Inc. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
pragma solidity 0.7.6;

import {IMessageTransmitterV2} from "../interfaces/v2/IMessageTransmitterV2.sol";
import {BaseMessageTransmitter} from "./BaseMessageTransmitter.sol";
import {MessageV2} from "../messages/v2/MessageV2.sol";
import {AddressUtils} from "../messages/v2/AddressUtils.sol";
import {TypedMemView} from "@memview-sol/contracts/TypedMemView.sol";
import {IMessageHandlerV2} from "../interfaces/v2/IMessageHandlerV2.sol";
import {FINALITY_THRESHOLD_FINALIZED} from "./FinalityThresholds.sol";

/**
 * @title MessageTransmitterV2
 * @notice Contract responsible for sending and receiving messages across chains.
 */
contract MessageTransmitterV2 is IMessageTransmitterV2, BaseMessageTransmitter {
    // ============ Events ============
    /**
     * @notice Emitted when a new message is dispatched
     * @param message Raw bytes of message
     */
    event MessageSent(bytes message);

    /**
     * @notice Emitted when a new message is received
     * @param caller Caller (msg.sender) on destination domain
     * @param sourceDomain The source domain this message originated from
     * @param nonce The nonce unique to this message
     * @param sender The sender of this message
     * @param finalityThresholdExecuted The finality at which message was attested to
     * @param messageBody message body bytes
     */
    event MessageReceived(
        address indexed caller,
        uint32 sourceDomain,
        bytes32 indexed nonce,
        bytes32 sender,
        uint32 indexed finalityThresholdExecuted,
        bytes messageBody
    );

    // ============ Libraries ============
    using AddressUtils for address;
    using AddressUtils for address payable;
    using AddressUtils for bytes32;
    using MessageV2 for bytes29;
    using TypedMemView for bytes;
    using TypedMemView for bytes29;

    // ============ Constructor ============
    /**
     * @param _localDomain Domain of chain on which the contract is deployed
     * @param _version Message Format version
     */
    constructor(
        uint32 _localDomain,
        uint32 _version
    ) BaseMessageTransmitter(_localDomain, _version) {
        _disableInitializers();
    }

    // ============ Initializers ============
    /**
     * @notice Initializes the contract
