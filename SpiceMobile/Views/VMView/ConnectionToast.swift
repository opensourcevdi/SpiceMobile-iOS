//
//  ConnectionToast.swift
//  SpiceMobile
//
//  Created by Lennard Siegel on 18.09.26.
//

import SwiftUI

struct ConnectionToast: View {

    let isOffline: Bool

    var body: some View {
        
        if isOffline {
            
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
    }

    private var icon: String {
        return "wifi.slash"
    }

    private var message: String {
        return "No Connection"
    }

    private var backgroundColor: Color {
        return .red
    }
}
