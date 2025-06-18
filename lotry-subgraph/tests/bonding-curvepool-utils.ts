import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  Approval,
  LotteryTaxStatusChanged,
  OwnershipTransferred,
  RewardsDistributed,
  TradeEvent,
  Transfer
} from "../generated/BondingCurvepool/BondingCurvepool"

export function createApprovalEvent(
  owner: Address,
  spender: Address,
  value: BigInt
): Approval {
  let approvalEvent = changetype<Approval>(newMockEvent())

  approvalEvent.parameters = new Array()

  approvalEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("spender", ethereum.Value.fromAddress(spender))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return approvalEvent
}

export function createLotteryTaxStatusChangedEvent(
  isActive: boolean
): LotteryTaxStatusChanged {
  let lotteryTaxStatusChangedEvent =
    changetype<LotteryTaxStatusChanged>(newMockEvent())

  lotteryTaxStatusChangedEvent.parameters = new Array()

  lotteryTaxStatusChangedEvent.parameters.push(
    new ethereum.EventParam("isActive", ethereum.Value.fromBoolean(isActive))
  )

  return lotteryTaxStatusChangedEvent
}

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent =
    changetype<OwnershipTransferred>(newMockEvent())

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}

export function createRewardsDistributedEvent(
  winner: Address,
  winnerPrizeAmount: BigInt,
  totalForProtocol: BigInt,
  devTax: BigInt
): RewardsDistributed {
  let rewardsDistributedEvent = changetype<RewardsDistributed>(newMockEvent())

  rewardsDistributedEvent.parameters = new Array()

  rewardsDistributedEvent.parameters.push(
    new ethereum.EventParam("winner", ethereum.Value.fromAddress(winner))
  )
  rewardsDistributedEvent.parameters.push(
    new ethereum.EventParam(
      "winnerPrizeAmount",
      ethereum.Value.fromUnsignedBigInt(winnerPrizeAmount)
    )
  )
  rewardsDistributedEvent.parameters.push(
    new ethereum.EventParam(
      "totalForProtocol",
      ethereum.Value.fromUnsignedBigInt(totalForProtocol)
    )
  )
  rewardsDistributedEvent.parameters.push(
    new ethereum.EventParam("devTax", ethereum.Value.fromUnsignedBigInt(devTax))
  )

  return rewardsDistributedEvent
}

export function createTradeEventEvent(
  tokenAddress: Address,
  ethPrice: BigInt
): TradeEvent {
  let tradeEventEvent = changetype<TradeEvent>(newMockEvent())

  tradeEventEvent.parameters = new Array()

  tradeEventEvent.parameters.push(
    new ethereum.EventParam(
      "tokenAddress",
      ethereum.Value.fromAddress(tokenAddress)
    )
  )
  tradeEventEvent.parameters.push(
    new ethereum.EventParam(
      "ethPrice",
      ethereum.Value.fromUnsignedBigInt(ethPrice)
    )
  )

  return tradeEventEvent
}

export function createTransferEvent(
  from: Address,
  to: Address,
  value: BigInt
): Transfer {
  let transferEvent = changetype<Transfer>(newMockEvent())

  transferEvent.parameters = new Array()

  transferEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return transferEvent
}
