import {
  Approval as ApprovalEvent,
  BuyEvent as BuyEventEvent,
  CurveParametersUpdated as CurveParametersUpdatedEvent,
  LotteryPoolUpdated as LotteryPoolUpdatedEvent,
  LotteryTaxStatusChanged as LotteryTaxStatusChangedEvent,
  SellEvent as SellEventEvent,
  TokensPurchased as TokensPurchasedEvent,
  TokensSold as TokensSoldEvent,
  Transfer as TransferEvent,
} from "../generated/BondingCurvePool/BondingCurvePool"
import {
  Approval,
  BuyEvent,
  CurveParametersUpdated,
  LotteryPoolUpdated,
  LotteryTaxStatusChanged,
  SellEvent,
  TokensPurchased,
  TokensSold,
  Transfer,
} from "../generated/schema"

export function handleApproval(event: ApprovalEvent): void {
  let entity = new Approval(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.owner = event.params.owner
  entity.spender = event.params.spender
  entity.value = event.params.value

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleBuyEvent(event: BuyEventEvent): void {
  let entity = new BuyEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.tokenAddress = event.params.tokenAddress
  entity.timestamp = event.params.timestamp
  entity.ethPrice = event.params.ethPrice

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleCurveParametersUpdated(
  event: CurveParametersUpdatedEvent,
): void {
  let entity = new CurveParametersUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.virtualTokenRes = event.params.virtualTokenRes
  entity.virtualEthRes = event.params.virtualEthRes
  entity.k = event.params.k

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleLotteryPoolUpdated(event: LotteryPoolUpdatedEvent): void {
  let entity = new LotteryPoolUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.newLotteryPool = event.params.newLotteryPool

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleLotteryTaxStatusChanged(
  event: LotteryTaxStatusChangedEvent,
): void {
  let entity = new LotteryTaxStatusChanged(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.isActive = event.params.isActive

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSellEvent(event: SellEventEvent): void {
  let entity = new SellEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.tokenAddress = event.params.tokenAddress
  entity.timestamp = event.params.timestamp
  entity.ethPrice = event.params.ethPrice

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTokensPurchased(event: TokensPurchasedEvent): void {
  let entity = new TokensPurchased(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.buyer = event.params.buyer
  entity.grossEthAmount = event.params.grossEthAmount
  entity.netEthForCurve = event.params.netEthForCurve
  entity.tokensReceived = event.params.tokensReceived
  entity.lotteryFeeApplied = event.params.lotteryFeeApplied

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTokensSold(event: TokensSoldEvent): void {
  let entity = new TokensSold(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.seller = event.params.seller
  entity.amountTokens = event.params.amountTokens
  entity.amountEth = event.params.amountEth

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTransfer(event: TransferEvent): void {
  let entity = new Transfer(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.from = event.params.from
  entity.to = event.params.to
  entity.value = event.params.value

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
