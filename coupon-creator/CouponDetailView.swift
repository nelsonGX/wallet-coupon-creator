//
//  CouponDetailView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI
import PassKit

struct CouponDetailView: View {
    @Environment(CouponStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let coupon: Coupon

    @State private var showingEditSheet = false
    @State private var showRechargeConfirm = false
    @State private var showUseConfirm = false
    @State private var passToAdd: PKPass?
    @State private var isLoadingPass = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var sharePassURL: URL?

    private var currentCoupon: Coupon {
        store.coupons.first(where: { $0.id == coupon.id }) ?? coupon
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CouponCardView(coupon: currentCoupon)

                // Usage progress
                usageSection

                // Actions
                actionSection

                // Info
                infoSection

                // Terms & Conditions
                termsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Coupon Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditCouponView(coupon: currentCoupon)
        }
        .sheet(item: $passToAdd) { pass in
            WalletPassSheet(pass: pass) { _ in
                passToAdd = nil
            }
        }
        .alert("Use Coupon", isPresented: $showUseConfirm) {
            Button("Use", role: .destructive) {
                useCouponAndUpdate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark one use of this coupon? (\(currentCoupon.remainingUses) remaining)")
        }
        .alert("Recharge Coupon", isPresented: $showRechargeConfirm) {
            Button("Recharge") {
                rechargeCouponAndUpdate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reset usage count to 0?")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private var usageSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Usage")
                    .font(.headline)
                Spacer()
                Text("\(currentCoupon.useCount) / \(currentCoupon.maxUse)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(currentCoupon.useCount), total: Double(currentCoupon.maxUse))
                .tint(currentCoupon.isFullyUsed ? .red : .green)

            if currentCoupon.isFullyUsed {
                Label(
                    currentCoupon.keepAfterUsedUp ? "All uses consumed — coupon kept" : "All uses consumed",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            // Add to Apple Wallet
            Button {
                addToWallet()
            } label: {
                if isLoadingPass {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Add to Apple Wallet", systemImage: "wallet.pass")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(isLoadingPass)

            if !currentCoupon.isFullyUsed {
                Button {
                    showUseConfirm = true
                } label: {
                    Label("Use Coupon", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if currentCoupon.isRechargeable && currentCoupon.useCount > 0 {
                Button {
                    showRechargeConfirm = true
                } label: {
                    Label("Recharge", systemImage: "arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if let sharePassURL {
                ShareLink(item: sharePassURL) {
                    Label("Share Pass via AirDrop", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    prepareSharePass()
                } label: {
                    Label("Prepare Share Link", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
    }

    private var infoSection: some View {
        VStack(spacing: 8) {
            Text("Details")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            InfoRow(label: "Category", value: currentCoupon.category.displayName)
            InfoRow(label: "Created", value: currentCoupon.createdDate.formatted(date: .abbreviated, time: .omitted))

            if let expDate = currentCoupon.expirationDate {
                InfoRow(
                    label: "Expires",
                    value: expDate.formatted(date: .abbreviated, time: .omitted),
                    valueColor: currentCoupon.isExpired ? .red : nil
                )
            }

            InfoRow(label: "Rechargeable", value: currentCoupon.isRechargeable ? "Yes" : "No")
            InfoRow(label: "Keep After Used Up", value: currentCoupon.keepAfterUsedUp ? "Yes" : "No")
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var termsSection: some View {
        if !currentCoupon.termsAndConditions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Terms & Conditions")
                    .font(.headline)
                Text(currentCoupon.termsAndConditions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private func addToWallet() {
        isLoadingPass = true
        Task {
            do {
                let pass = try await store.signWalletPass(for: currentCoupon)
                passToAdd = pass
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoadingPass = false
        }
    }

    private func useCouponAndUpdate() {
        Task {
            do {
                let pass = try await store.useCouponAndUpdatePass(currentCoupon)
                passToAdd = pass
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func rechargeCouponAndUpdate() {
        Task {
            do {
                let pass = try await store.rechargeCouponAndUpdatePass(currentCoupon)
                passToAdd = pass
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func prepareSharePass() {
        isLoadingPass = true
        Task {
            do {
                let url = try await store.getPassFileURL(for: currentCoupon)
                sharePassURL = url
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoadingPass = false
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor ?? .primary)
        }
        .font(.subheadline)
    }
}
