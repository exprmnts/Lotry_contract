import {
  Approval as ApprovalEvent,
  LotteryTaxStatusChanged as LotteryTaxStatusChangedEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  RewardsDistributed as RewardsDistributedEvent,
  TradeEvent as TradeEventEvent,
  Transfer as TransferEvent,
} from "../generated/BondingCurvepool/BondingCurvepool"
import {
  Approval,
  LotteryTaxStatusChanged,
  OwnershipTransferred,
  RewardsDistributed,
  TradeEvent,
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

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent,
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleRewardsDistributed(event: RewardsDistributedEvent): void {
  let entity = new RewardsDistributed(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.winner = event.params.winner
  entity.winnerPrizeAmount = event.params.winnerPrizeAmount
  entity.totalForProtocol = event.params.totalForProtocol
  entity.devTax = event.params.devTax

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTradeEvent(event: TradeEventEvent): void {
  let entity = new TradeEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32()),
  )
  entity.tokenAddress = event.params.tokenAddress
  entity.ethPrice = event.params.ethPrice

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
