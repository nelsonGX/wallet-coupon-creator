//
//  WalletPassService.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import Foundation
import PassKit

/// API client for the wallet coupon creator server
enum WalletPassService {
    private static let baseURL = "https://coupon-creator.nelsongx.com"

    /// Request body matching the server's PassRequest schema
    struct PassRequest: Encodable {
        let title: String
        let discount: String
        let organizationName: String
        let useCount: Int
        let maxUse: Int
        let isRechargeable: Bool
        let keepAfterUsedUp: Bool
        let couponID: String
        let backgroundColor: ColorComponents
        let foregroundColor: ColorComponents
        let description: String
        let expirationDate: String?
        let termsAndConditions: String?

        struct ColorComponents: Encodable {
            let red: Double
            let green: Double
            let blue: Double
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Creates a PassRequest from a Coupon model
    static func makeRequest(from coupon: Coupon) -> PassRequest {
        PassRequest(
            title: coupon.title,
            discount: coupon.discount,
            organizationName: coupon.organizationName,
            useCount: coupon.useCount,
            maxUse: coupon.maxUse,
            isRechargeable: coupon.isRechargeable,
            keepAfterUsedUp: coupon.keepAfterUsedUp,
            couponID: coupon.id.uuidString,
            backgroundColor: .init(
                red: coupon.backgroundColor.red,
                green: coupon.backgroundColor.green,
                blue: coupon.backgroundColor.blue
            ),
            foregroundColor: .init(
                red: coupon.foregroundColor.red,
                green: coupon.foregroundColor.green,
                blue: coupon.foregroundColor.blue
            ),
            description: coupon.description,
            expirationDate: coupon.expirationDate.map { isoFormatter.string(from: $0) },
            termsAndConditions: coupon.termsAndConditions.isEmpty ? nil : coupon.termsAndConditions
        )
    }

    /// Sign a new pass - returns .pkpass file data
    static func signPass(for coupon: Coupon) async throws -> Data {
        try await postRequest(endpoint: "/sign-pass", coupon: coupon)
    }

    /// Update an existing pass - returns updated .pkpass file data
    static func updatePass(for coupon: Coupon) async throws -> Data {
        try await postRequest(endpoint: "/update-pass", coupon: coupon)
    }

    /// Create a PKPass from raw .pkpass data
    static func createPKPass(from data: Data) throws -> PKPass {
        try PKPass(data: data)
    }

    /// Save .pkpass data to a temporary file for sharing
    static func saveTempPassFile(data: Data, couponID: UUID) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(couponID.uuidString).pkpass")
        try data.write(to: fileURL)
        return fileURL
    }

    // MARK: - Private

    private static func postRequest(endpoint: String, coupon: Coupon) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw WalletPassError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = makeRequest(from: coupon)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletPassError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WalletPassError.serverError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        return data
    }
}

enum WalletPassError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}
