//
//  HistoryView.swift
//  SpectApps
//
//  Created by Malik on 27.07.2025.
//

import SwiftUI

struct HistoryView: View {
    
    @ObservedObject var firebaseManager: SimpleFirebaseManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(firebaseManager.videoHistory, id: \.id) { video in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.prompt)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(video.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        UIPasteboard.general.string = video.videoURL
                    }
                }
            }
            .navigationTitle("Video Geçmişi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }
}
