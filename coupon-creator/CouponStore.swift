//
//  CouponStore.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import Foundation
import SwiftUI
import PassKit
import UIKit

@Observable
class CouponStore {
    var coupons: [Coupon] = []
    var isLoading = false
    var errorMessage: String?

    private let saveKey = "SavedCoupons"

    init() {
        load()
    }

    func addCoupon(_ coupon: Coupon) {
        coupons.insert(coupon, at: 0)
        save()
    }

    func updateCoupon(_ coupon: Coupon) {
        if let index = coupons.firstIndex(where: { $0.id == coupon.id }) {
            coupons[index] = coupon
            save()
        }
    }

    func deleteCoupon(_ coupon: Coupon) {
        coupons.removeAll { $0.id == coupon.id }
        save()
    }

    func deleteCoupons(at offsets: IndexSet) {
        coupons.remove(atOffsets: offsets)
        save()
    }

    func deleteCoupons(withIDs ids: Set<UUID>) {
        coupons.removeAll { ids.contains($0.id) }
        save()
    }

    /// Use a coupon once, returns true if successful
    func useCoupon(_ coupon: Coupon) -> Bool {
        guard let index = coupons.firstIndex(where: { $0.id == coupon.id }) else {
            return false
        }

        if coupons[index].useCount < coupons[index].maxUse {
            coupons[index].useCount += 1
            save()
            return true
        }
        return false
    }

    /// Recharge a coupon back to 0 uses
    func rechargeCoupon(_ coupon: Coupon) -> Bool {
        guard let index = coupons.firstIndex(where: { $0.id == coupon.id }),
              coupons[index].isRechargeable else {
            return false
        }
        coupons[index].useCount = 0
        save()
        return true
    }

    /// Find a coupon by its ID
    func findCoupon(byID id: UUID) -> Coupon? {
        coupons.first(where: { $0.id == id })
    }

    // MARK: - Wallet Pass Integration

    /// Sign a new pass, store the auth token, and return a PKPass ready to add to wallet
    func signWalletPass(for coupon: Coupon) async throws -> PKPass {
        let icon = coupon.iconImageData.flatMap { UIImage(data: $0) }
        let result = try await WalletPassService.signPass(for: coupon, icon: icon)
        // Save the auth token for future updates
        if let token = result.authToken,
           let index = coupons.firstIndex(where: { $0.id == coupon.id }) {
            coupons[index].authToken = token
            save()
        }
        return try WalletPassService.createPKPass(from: result.passData)
    }

    /// Update a pass on the server and return a PKPass ready to add to wallet
    func updateWalletPass(for coupon: Coupon) async throws -> PKPass {
        let icon = coupon.iconImageData.flatMap { UIImage(data: $0) }
        let data = try await WalletPassService.updatePass(for: coupon, icon: icon, authToken: coupon.authToken)
        return try WalletPassService.createPKPass(from: data)
    }

    /// Create a one-time share link for a coupon's wallet pass
    func createShareLink(for coupon: Coupon) async throws -> URL {
        try await WalletPassService.createShareLink(for: coupon)
    }

    /// Use a coupon and update the wallet pass on the server
    func useCouponAndUpdatePass(_ coupon: Coupon) async throws -> PKPass {
        guard useCoupon(coupon) else {
            throw WalletPassError.serverError(statusCode: 0, message: "Could not use coupon")
        }
        // Get the updated coupon after use
        guard let updated = coupons.first(where: { $0.id == coupon.id }) else {
            throw WalletPassError.serverError(statusCode: 0, message: "Coupon not found after update")
        }
        return try await updateWalletPass(for: updated)
    }

    /// Recharge a coupon and update the wallet pass on the server
    func rechargeCouponAndUpdatePass(_ coupon: Coupon) async throws -> PKPass {
        guard rechargeCoupon(coupon) else {
            throw WalletPassError.serverError(statusCode: 0, message: "Could not recharge coupon")
        }
        guard let updated = coupons.first(where: { $0.id == coupon.id }) else {
            throw WalletPassError.serverError(statusCode: 0, message: "Coupon not found after recharge")
        }
        return try await updateWalletPass(for: updated)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(coupons) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Coupon].self, from: data) {
            coupons = decoded
        }
    }
}
