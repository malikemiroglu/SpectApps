//
//  VideoModels.swift
//  SpectApps
//
//  Created by Malik on 27.07.2025.
//

import Foundation

struct VideoItem: Identifiable {
    let id: String
    let prompt: String
    let videoURL: String
    let createdAt: Date
}
