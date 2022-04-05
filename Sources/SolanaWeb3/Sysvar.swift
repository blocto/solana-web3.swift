//
//  Sysvar.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/20.
//

import Foundation

public enum Sysvar {

    public static let clockPublicKey = try! PublicKey("SysvarC1ock11111111111111111111111111111111")

    public static let epochSchedulePublicKey = try! PublicKey("SysvarEpochSchedu1e111111111111111111111111")

    public static let instructionsPublicKey = try! PublicKey("Sysvar1nstructions1111111111111111111111111")

    public static let recentBlockhashesPublicKey = try! PublicKey("SysvarRecentB1ockHashes11111111111111111111")

    public static let rentPublicKey = try! PublicKey("SysvarRent111111111111111111111111111111111")

    public static let rewardsPublicKey = try! PublicKey("SysvarRewards111111111111111111111111111111")

    public static let slotHashedPublicKey = try! PublicKey("SysvarS1otHashes111111111111111111111111111")

    public static let slotHistoryPublicKey = try! PublicKey("SysvarS1otHistory11111111111111111111111111")

    public static let stakeHistoryPublicKey = try! PublicKey("SysvarStakeHistory1111111111111111111111111")
}
