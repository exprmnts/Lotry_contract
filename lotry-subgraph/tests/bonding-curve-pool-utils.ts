import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  Approval,
  BuyEvent,
  CurveParametersUpdated,
  LotteryPoolUpdated,
  LotteryTaxStatusChanged,
  SellEvent,
  TokensPurchased,
  TokensSold,
  Transfer
} from "../generated/BondingCurvePool/BondingCurvePool"

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

export function createBuyEventEvent(
  tokenAddress: Address,
  timestamp: BigInt,
  ethPrice: BigInt
): BuyEvent {
  let buyEventEvent = changetype<BuyEvent>(newMockEvent())

  buyEventEvent.parameters = new Array()

  buyEventEvent.parameters.push(
    new ethereum.EventParam(
      "tokenAddress",
      ethereum.Value.fromAddress(tokenAddress)
    )
  )
  buyEventEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )
  buyEventEvent.parameters.push(
    new ethereum.EventParam(
      "ethPrice",
      ethereum.Value.fromUnsignedBigInt(ethPrice)
    )
  )

  return buyEventEvent
}

export function createCurveParametersUpdatedEvent(
  virtualTokenRes: BigInt,
  virtualEthRes: BigInt,
  k: BigInt
): CurveParametersUpdated {
  let curveParametersUpdatedEvent =
    changetype<CurveParametersUpdated>(newMockEvent())

  curveParametersUpdatedEvent.parameters = new Array()

  curveParametersUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "virtualTokenRes",
      ethereum.Value.fromUnsignedBigInt(virtualTokenRes)
    )
  )
  curveParametersUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "virtualEthRes",
      ethereum.Value.fromUnsignedBigInt(virtualEthRes)
    )
  )
  curveParametersUpdatedEvent.parameters.push(
    new ethereum.EventParam("k", ethereum.Value.fromUnsignedBigInt(k))
  )

  return curveParametersUpdatedEvent
}

export function createLotteryPoolUpdatedEvent(
  newLotteryPool: BigInt
): LotteryPoolUpdated {
  let lotteryPoolUpdatedEvent = changetype<LotteryPoolUpdated>(newMockEvent())

  lotteryPoolUpdatedEvent.parameters = new Array()

  lotteryPoolUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newLotteryPool",
      ethereum.Value.fromUnsignedBigInt(newLotteryPool)
    )
  )

  return lotteryPoolUpdatedEvent
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

export function createSellEventEvent(
  tokenAddress: Address,
  timestamp: BigInt,
  ethPrice: BigInt
): SellEvent {
  let sellEventEvent = changetype<SellEvent>(newMockEvent())

  sellEventEvent.parameters = new Array()

  sellEventEvent.parameters.push(
    new ethereum.EventParam(
      "tokenAddress",
      ethereum.Value.fromAddress(tokenAddress)
    )
  )
  sellEventEvent.parameters.push(
    new ethereum.EventParam(
      "timestamp",
      ethereum.Value.fromUnsignedBigInt(timestamp)
    )
  )
  sellEventEvent.parameters.push(
    new ethereum.EventParam(
      "ethPrice",
      ethereum.Value.fromUnsignedBigInt(ethPrice)
    )
  )

  return sellEventEvent
}

export function createTokensPurchasedEvent(
  buyer: Address,
  grossEthAmount: BigInt,
  netEthForCurve: BigInt,
  tokensReceived: BigInt,
  lotteryFeeApplied: BigInt
): TokensPurchased {
  let tokensPurchasedEvent = changetype<TokensPurchased>(newMockEvent())

  tokensPurchasedEvent.parameters = new Array()

  tokensPurchasedEvent.parameters.push(
    new ethereum.EventParam("buyer", ethereum.Value.fromAddress(buyer))
  )
  tokensPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "grossEthAmount",
      ethereum.Value.fromUnsignedBigInt(grossEthAmount)
    )
  )
  tokensPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "netEthForCurve",
      ethereum.Value.fromUnsignedBigInt(netEthForCurve)
    )
  )
  tokensPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "tokensReceived",
      ethereum.Value.fromUnsignedBigInt(tokensReceived)
    )
  )
  tokensPurchasedEvent.parameters.push(
    new ethereum.EventParam(
      "lotteryFeeApplied",
      ethereum.Value.fromUnsignedBigInt(lotteryFeeApplied)
    )
  )

  return tokensPurchasedEvent
}

export function createTokensSoldEvent(
  seller: Address,
  amountTokens: BigInt,
  amountEth: BigInt
): TokensSold {
  let tokensSoldEvent = changetype<TokensSold>(newMockEvent())

  tokensSoldEvent.parameters = new Array()

  tokensSoldEvent.parameters.push(
    new ethereum.EventParam("seller", ethereum.Value.fromAddress(seller))
  )
  tokensSoldEvent.parameters.push(
    new ethereum.EventParam(
      "amountTokens",
      ethereum.Value.fromUnsignedBigInt(amountTokens)
    )
  )
  tokensSoldEvent.parameters.push(
    new ethereum.EventParam(
      "amountEth",
      ethereum.Value.fromUnsignedBigInt(amountEth)
    )
  )

  return tokensSoldEvent
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
