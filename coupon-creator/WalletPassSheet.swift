//
//  WalletPassSheet.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import SwiftUI
import PassKit

/// Makes PKPass usable with SwiftUI's .sheet(item:)
extension PKPass: @retroactive Identifiable {
    public var id: String {
        serialNumber
    }
}

/// A SwiftUI wrapper around PKAddPassesViewController for presenting the "Add to Wallet" dialog
struct WalletPassSheet: UIViewControllerRepresentable {
    let pass: PKPass
    let onCompletion: (Bool) -> Void

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        let controller = PKAddPassesViewController(pass: pass)!
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(pass: pass, onCompletion: onCompletion)
    }

    class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let onCompletion: (Bool) -> Void
        let pass: PKPass

        init(pass: PKPass, onCompletion: @escaping (Bool) -> Void) {
            self.pass = pass
            self.onCompletion = onCompletion
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            let passLibrary = PKPassLibrary()
            let wasAdded = passLibrary.containsPass(pass)
            onCompletion(wasAdded)
        }
    }
}
