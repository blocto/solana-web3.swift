//
//  File.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/4/12.
//

import Foundation

/// Epoch schedule
/// (see https://docs.solana.com/terminology#epoch)
/// Can be retrieved with the connection.getEpochSchedule method
public struct EpochSchedule: Decodable {

    /// The maximum number of slots in each epoch
    public let slotsPerEpoch: UInt64

    /// The number of slots before beginning of an epoch to calculate a leader schedule for that epoch
    public let leaderScheduleSlotOffset: UInt64

    /// Indicates whether epochs start short and grow
    public let warmup: Bool

    /// The first epoch with `slotsPerEpoch` slots
    public let firstNormalEpoch: Int64

    /// The first slot of `firstNormalEpoch`
    public let firstNormalSlot: UInt64

    public init(
        slotsPerEpoch: UInt64,
        leaderScheduleSlotOffset: UInt64,
        warmup: Bool,
        firstNormalEpoch: Int64,
        firstNormalSlot: UInt64
    ) {
        self.slotsPerEpoch = slotsPerEpoch
        self.leaderScheduleSlotOffset = leaderScheduleSlotOffset
        self.warmup = warmup
        self.firstNormalEpoch = firstNormalEpoch
        self.firstNormalSlot = firstNormalSlot
    }

}
