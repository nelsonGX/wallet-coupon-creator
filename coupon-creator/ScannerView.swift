//
//  ScannerView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI
import Vision
import VisionKit
import PassKit

struct ScannerView: View {
    @Environment(CouponStore.self) private var store

    @State private var scannedCoupon: Coupon?
    @State private var showScannedCoupon = false
    @State private var scanError: String?
    @State private var showError = false
    @State private var isScannerActive = true

    var body: some View {
        NavigationStack {
            VStack {
                if DataScannerViewController.isSupported {
                    ZStack {
                        DataScannerRepresentable(
                            onScan: handleScan,
                            isActive: isScannerActive
                        )
                        .ignoresSafeArea()

                        scanOverlay
                    }
                } else {
                    unsupportedView
                }
            }
            .navigationTitle("Scan Coupon")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showScannedCoupon, onDismiss: {
                scannedCoupon = nil
                isScannerActive = true
            }) {
                if let coupon = scannedCoupon {
                    ScannedCouponSheet(coupon: coupon)
                }
            }
            .alert("Scan Error", isPresented: $showError) {
                Button("OK") { isScannerActive = true }
            } message: {
                Text(scanError ?? "Unable to read QR code")
            }
        }
    }

    private var scanOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                Text("Point camera at a coupon QR code")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding()
            .background(.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 40)
        }
    }

    private var unsupportedView: some View {
        ContentUnavailableView(
            "Scanner Not Available",
            systemImage: "camera.fill",
            description: Text("Camera scanning is not supported on this device.")
        )
    }

    private func handleScan(_ payload: String) {
        guard scannedCoupon == nil else { return }

        isScannerActive = false

        if let couponID = UUID(uuidString: payload),
           let coupon = store.findCoupon(byID: couponID) {
            scannedCoupon = coupon
            showScannedCoupon = true
        } else {
            scanError = UUID(uuidString: payload) != nil
                ? "This coupon is not in your library."
                : "This QR code doesn't contain valid coupon data."
            showError = true
        }
    }
}

// MARK: - DataScanner UIKit Wrapper

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    var isActive: Bool

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isActive {
            if !uiViewController.isScanning {
                context.coordinator.hasScanned = false
                try? uiViewController.startScanning()
            }
        } else {
            if uiViewController.isScanning {
                uiViewController.stopScanning()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }
            for item in addedItems {
                switch item {
                case .barcode(let barcode):
                    if let payload = barcode.payloadStringValue {
                        hasScanned = true
                        dataScanner.stopScanning()
                        onScan(payload)
                        return
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Scanned Coupon Sheet

struct ScannedCouponSheet: View {
    @Environment(CouponStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let coupon: Coupon

    @State private var showRedeemConfirm = false
    @State private var showRechargeConfirm = false
    @State private var showEditSheet = false
    @State private var passToAdd: PKPass?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var redeemResult: String?
    @State private var showResult = false

    private var currentCoupon: Coupon {
        store.coupons.first(where: { $0.id == coupon.id }) ?? coupon
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)

                    Text("Coupon Scanned")
                        .font(.title2)
                        .fontWeight(.bold)

                    CouponCardView(coupon: currentCoupon)

                    // Usage info
                    VStack(spacing: 8) {
                        HStack {
                            Text("Uses")
                            Spacer()
                            Text("\(currentCoupon.useCount) / \(currentCoupon.maxUse)")
                        }
                        ProgressView(value: Double(currentCoupon.useCount), total: Double(currentCoupon.maxUse))
                            .tint(currentCoupon.isFullyUsed ? .red : .green)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Actions
                    VStack(spacing: 12) {
                        if !currentCoupon.isFullyUsed {
                            Button {
                                showRedeemConfirm = true
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Label("Redeem (Use 1)", systemImage: "minus.circle")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(isLoading)
                        }

                        if currentCoupon.isRechargeable && currentCoupon.useCount > 0 {
                            Button {
                                showRechargeConfirm = true
                            } label: {
                                Label("Recharge", systemImage: "arrow.circlepath")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoading)
                        }

                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Coupon", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Redeem Coupon", isPresented: $showRedeemConfirm) {
                Button("Redeem", role: .destructive) {
                    redeemCoupon()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Use one redemption of \"\(currentCoupon.title)\"?")
            }
            .alert("Recharge Coupon", isPresented: $showRechargeConfirm) {
                Button("Recharge") {
                    rechargeCoupon()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Reset usage count to 0?")
            }
            .alert("Result", isPresented: $showResult) {
                Button("OK") {}
            } message: {
                Text(redeemResult ?? "")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showEditSheet) {
                EditCouponView(coupon: currentCoupon)
            }
            .sheet(item: $passToAdd) { pass in
                WalletPassSheet(pass: pass) { _ in
                    passToAdd = nil
                }
            }
        }
    }

    private func redeemCoupon() {
        isLoading = true
        Task {
            do {
                let pass = try await store.useCouponAndUpdatePass(currentCoupon)
                redeemResult = "Coupon redeemed! Updated pass ready."
                showResult = true
                passToAdd = pass
            } catch {
                // Still try local-only use if server fails
                let success = store.useCoupon(currentCoupon)
                redeemResult = success
                    ? "Coupon redeemed locally. Server update failed: \(error.localizedDescription)"
                    : "Could not redeem coupon."
                showResult = true
            }
            isLoading = false
        }
    }

    private func rechargeCoupon() {
        isLoading = true
        Task {
            do {
                let pass = try await store.rechargeCouponAndUpdatePass(currentCoupon)
                redeemResult = "Coupon recharged! Updated pass ready."
                showResult = true
                passToAdd = pass
            } catch {
                _ = store.rechargeCoupon(currentCoupon)
                redeemResult = "Coupon recharged locally. Server update failed: \(error.localizedDescription)"
                showResult = true
            }
            isLoading = false
        }
    }
}
