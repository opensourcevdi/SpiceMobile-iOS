//
//  ConnectionToast.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 18.09.26.
//

import SwiftUI

struct ConnectionToast: View {

    let quality: VMConnectionQuality
    let isOffline: Bool

    var body: some View {

        HStack(spacing: 10) {

            Image(systemName: icon)
                .font(.headline)

            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Capsule()
                .fill(backgroundColor)
        }
        .shadow(radius: 8)
    }

    private var icon: String {

        if isOffline {
            return "wifi.slash"
        }

        switch quality {

        case .good:
            return "wifi"

        case .slow:
            return "wifi.exclamationmark"

        case .bad:
            return "wifi.slash"
        }
    }

    private var message: String {

        if isOffline {
            return "Keine Verbindung"
        }

        switch quality {

        case .good:
            return "Gute Verbindung"

        case .slow:
            return "Langsame Verbindung"

        case .bad:
            return "Sehr schlechte Verbindung"
        }
    }

    private var backgroundColor: Color {

        if isOffline {
            return .red
        }

        switch quality {

        case .good:
            return .green

        case .slow:
            return .orange

        case .bad:
            return .red
        }
    }
}
