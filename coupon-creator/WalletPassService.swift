//
//  WalletPassService.swift
//  coupon-creator
//
//  Created by Nelson Lin on 2026/3/5.
//

import Foundation
import PassKit
import UIKit

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
        let labelColor: ColorComponents
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
            labelColor: .init(
                red: coupon.labelColor.red,
                green: coupon.labelColor.green,
                blue: coupon.labelColor.blue
            ),
            description: coupon.description,
            expirationDate: coupon.expirationDate.map { isoFormatter.string(from: $0) },
            termsAndConditions: coupon.termsAndConditions.isEmpty ? nil : coupon.termsAndConditions
        )
    }

    /// Sign a new pass - returns .pkpass file data
    static func signPass(for coupon: Coupon, icon: UIImage? = nil) async throws -> Data {
        try await postRequest(endpoint: "/sign-pass", coupon: coupon, icon: icon)
    }

    /// Update an existing pass - returns updated .pkpass file data
    static func updatePass(for coupon: Coupon, icon: UIImage? = nil) async throws -> Data {
        try await postRequest(endpoint: "/update-pass", coupon: coupon, icon: icon)
    }

    /// Create a PKPass from raw .pkpass data
    static func createPKPass(from data: Data) throws -> PKPass {
        try PKPass(data: data)
    }

    /// Response from the create-share-link endpoint
    private struct ShareLinkResponse: Decodable {
        let token: String
    }

    /// Create a one-time share link for a pass identified by its serial number (coupon ID)
    static func createShareLink(for coupon: Coupon) async throws -> URL {
        let serialNumber = coupon.id.uuidString
        guard let url = URL(string: "\(baseURL)/api/create-share-link/\(serialNumber)") else {
            throw WalletPassError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletPassError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WalletPassError.serverError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let decoded = try JSONDecoder().decode(ShareLinkResponse.self, from: data)

        guard let shareURL = URL(string: "\(baseURL)/api/share/\(decoded.token)") else {
            throw WalletPassError.invalidURL
        }

        return shareURL
    }

    // MARK: - Private

    private static func postRequest(endpoint: String, coupon: Coupon, icon: UIImage?) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw WalletPassError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let passRequest = makeRequest(from: coupon)
        let jsonData = try JSONEncoder().encode(passRequest)

        var body = Data()

        // — data part (JSON string) —
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"data\"\r\n\r\n".data(using: .utf8)!)
        body.append(jsonData)
        body.append("\r\n".data(using: .utf8)!)

        // — icon part (optional) —
        if let icon, let pngData = icon.pngData() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"icon\"; filename=\"icon.png\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(pngData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

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
