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

    var isScannerEnabled: Bool

    @State private var scannedCouponID: UUID?
    @State private var scanError: String?
    @State private var showError = false
    @State private var isScannerActive = true

    // Fast scan mode
    @State private var isFastScan = false
    @State private var preventDuplicates = true
    @State private var fastScanSessionIDs: Set<UUID> = []
    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var fastScanCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                if DataScannerViewController.isSupported {
                    if isScannerEnabled {
                        DataScannerRepresentable(
                            onScan: handleScan,
                            isActive: isScannerActive
                        )
                        .ignoresSafeArea()
                    } else {
                        Color.black.ignoresSafeArea()
                    }

                    scanOverlay
                } else {
                    unsupportedView
                }

                // Toast overlay for fast scan feedback
                if let message = toastMessage {
                    VStack {
                        fastScanToast(message: message, isError: toastIsError)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .animation(.easeInOut(duration: 0.3), value: toastMessage)
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
            // Fast scan controls at top
            VStack(spacing: 8) {
                Toggle(isOn: $isFastScan) {
                    Label("Fast Scan", systemImage: "bolt.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)
                .tint(.orange)
                .onChange(of: isFastScan) { _, newValue in
                    if newValue {
                        // Reset session when entering fast scan
                        fastScanSessionIDs.removeAll()
                        fastScanCount = 0
                    }
                }

                if isFastScan {
                    Toggle(isOn: $preventDuplicates) {
                        Label("Prevent Duplicates", systemImage: "shield.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .toggleStyle(.switch)
                    .tint(.blue)

                    if fastScanCount > 0 {
                        Text("\(fastScanCount) scanned this session")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            // Viewfinder frame
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                .frame(width: 240, height: 240)
                .background(.clear)

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: isFastScan ? "bolt.fill" : "qrcode.viewfinder")
                    .font(.system(size: 32))
                    .foregroundStyle(isFastScan ? .orange : .white)
                Text(isFastScan ? "Fast scan: auto-redeem on scan" : "Point camera at a coupon QR code")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 40)
        }
    }

    private func fastScanToast(message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)
            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isError ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 60)
    }

    private var unsupportedView: some View {
        ContentUnavailableView(
            "Scanner Not Available",
            systemImage: "camera.fill",
            description: Text("Camera scanning is not supported on this device.")
        )
    }

    private func handleScan(_ payload: String) {
        if isFastScan {
            handleFastScan(payload)
        } else {
            handleNormalScan(payload)
        }
    }

    private func handleNormalScan(_ payload: String) {
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

    private func handleFastScan(_ payload: String) {
        guard let couponID = UUID(uuidString: payload) else {
            showFastScanToast("Invalid QR code", isError: true)
            resumeScanning()
            return
        }

        guard let coupon = store.findCoupon(byID: couponID) else {
            showFastScanToast("Coupon not in library", isError: true)
            resumeScanning()
            return
        }

        // Duplicate prevention
        if preventDuplicates && fastScanSessionIDs.contains(couponID) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showFastScanToast("Already scanned: \(coupon.title)", isError: true)
            resumeScanning()
            return
        }

        // Check if usable
        if coupon.isFullyUsed {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showFastScanToast("Fully used: \(coupon.title)", isError: true)
            resumeScanning()
            return
        }

        if coupon.isExpired {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showFastScanToast("Expired: \(coupon.title)", isError: true)
            resumeScanning()
            return
        }

        // Redeem immediately
        fastScanSessionIDs.insert(couponID)
        fastScanCount += 1

        Task {
            do {
                _ = try await store.useCouponAndUpdatePass(coupon)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let updated = store.findCoupon(byID: couponID)
                let remaining = updated?.remainingUses ?? 0
                showFastScanToast("\(coupon.title) — \(remaining) left", isError: false)
            } catch {
                // Coupon was used locally even if pass update failed
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                let updated = store.findCoupon(byID: couponID)
                let remaining = updated?.remainingUses ?? 0
                showFastScanToast("\(coupon.title) — \(remaining) left (pass sync failed)", isError: false)
            }
            resumeScanning()
        }
    }

    private func showFastScanToast(_ message: String, isError: Bool) {
        withAnimation {
            toastMessage = message
            toastIsError = isError
        }
        // Auto-dismiss toast
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func resumeScanning() {
        // Brief delay before reactivating to avoid re-scanning the same code
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            isScannerActive = false
            try? await Task.sleep(for: .milliseconds(100))
            isScannerActive = true
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

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
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
        Task {
            do {
                _ = try await store.useCouponAndUpdatePass(coupon)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                resultMessage = "Coupon redeemed! Pass updated."
            } catch {
                // Local use already happened inside useCouponAndUpdatePass,
                // so the coupon count is updated even if the server fails.
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                resultMessage = "Coupon redeemed locally. Pass update failed: \(error.localizedDescription)"
            }
            showResult = true
            isLoading = false
        }
    }

    private func rechargeCoupon() {
        isLoading = true
        Task {
            do {
                _ = try await store.rechargeCouponAndUpdatePass(coupon)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                resultMessage = "Coupon recharged! Pass updated."
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                resultMessage = "Coupon recharged locally. Pass update failed: \(error.localizedDescription)"
            }
            showResult = true
            isLoading = false
        }
    }
}
