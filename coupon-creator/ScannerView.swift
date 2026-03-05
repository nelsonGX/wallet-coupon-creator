//
//  ScannerView.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI
import Vision
import VisionKit

struct ScannerView: View {
    @Environment(CouponStore.self) private var store

    @State private var scannedCouponID: UUID?
    @State private var scanError: String?
    @State private var showError = false
    @State private var isScannerActive = true

    var body: some View {
        NavigationStack {
            ZStack {
                if DataScannerViewController.isSupported {
                    DataScannerRepresentable(
                        onScan: handleScan,
                        isActive: isScannerActive
                    )
                    .ignoresSafeArea()

                    scanOverlay
                } else {
                    unsupportedView
                }
            }
            .navigationTitle("Scan Coupon")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $scannedCouponID) { couponID in
                ScannedCouponPage(couponID: couponID)
            }
            .alert("Scan Error", isPresented: $showError) {
                Button("OK") { isScannerActive = true }
            } message: {
                Text(scanError ?? "Unable to read QR code")
            }
            .onChange(of: scannedCouponID) { _, newValue in
                isScannerActive = (newValue == nil)
            }
        }
    }

    private var scanOverlay: some View {
        VStack {
            Spacer()

            // Viewfinder frame
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                .frame(width: 240, height: 240)
                .background(.clear)

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                Text("Point camera at a coupon QR code")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding()
            .background(.ultraThinMaterial)
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
        guard scannedCouponID == nil else { return }

        if let couponID = UUID(uuidString: payload),
           store.findCoupon(byID: couponID) != nil {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            scannedCouponID = couponID
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
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
                        DispatchQueue.main.async {
                            self.onScan(payload)
                        }
                        return
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Scanned Coupon Page (pushed, not a sheet)

struct ScannedCouponPage: View {
    @Environment(CouponStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let couponID: UUID

    @State private var showRedeemConfirm = false
    @State private var showRechargeConfirm = false
    @State private var showEditSheet = false
    @State private var isLoading = false
    @State private var resultMessage: String?
    @State private var showResult = false
    @State private var showSuccessCheck = true

    private var coupon: Coupon {
        store.coupons.first(where: { $0.id == couponID }) ?? Coupon(title: "Unknown")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success header
                if showSuccessCheck {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce, value: showSuccessCheck)

                        Text("Coupon Found")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 8)
                    .transition(.opacity)
                }

                CouponCardView(coupon: coupon)

                // Usage info
                VStack(spacing: 8) {
                    HStack {
                        Text("Uses")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(coupon.useCount) / \(coupon.maxUse)")
                            .fontWeight(.semibold)
                    }
                    ProgressView(value: Double(coupon.useCount), total: Double(coupon.maxUse))
                        .tint(coupon.isFullyUsed ? .red : .green)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    if !coupon.isFullyUsed && !coupon.isExpired {
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
                        .controlSize(.large)
                        .disabled(isLoading)
                    } else if coupon.isExpired {
                        Label("Expired", systemImage: "clock.badge.xmark")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Fully Used", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.secondary)
                    }

                    if coupon.isRechargeable && coupon.useCount > 0 {
                        Button {
                            showRechargeConfirm = true
                        } label: {
                            Label("Recharge", systemImage: "arrow.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(isLoading)
                    }

                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Coupon", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Scanned Coupon")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Scan Again", systemImage: "qrcode.viewfinder")
                }
            }
        }
        .alert("Redeem Coupon", isPresented: $showRedeemConfirm) {
            Button("Redeem", role: .destructive) {
                redeemCoupon()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use one redemption of \"\(coupon.title)\"?")
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
            Text(resultMessage ?? "")
        }
        .sheet(isPresented: $showEditSheet) {
            EditCouponView(coupon: coupon)
        }
    }

    private func redeemCoupon() {
        isLoading = true
        let success = store.useCoupon(coupon)
        if success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            resultMessage = "Coupon redeemed! \(coupon.remainingUses - 1) uses remaining."
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            resultMessage = "Could not redeem coupon."
        }
        showResult = true
        isLoading = false
    }

    private func rechargeCoupon() {
        isLoading = true
        let success = store.rechargeCoupon(coupon)
        if success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            resultMessage = "Coupon recharged to full."
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            resultMessage = "Could not recharge coupon."
        }
        showResult = true
        isLoading = false
    }
}
