//
//  PromptManager.swift
//  SpectApps
//
//  Created by Malik on 27.07.2025.
//

import Foundation

@MainActor
class SimplePromptManager: ObservableObject {
    
    func improvePrompt(_ prompt: String) -> String {
        var improved = prompt
        
        if !improved.contains("high quality") {
            improved += ", high quality"
        }
        
        if !improved.contains("smooth") {
            improved += ", smooth motion"
        }
        
        if !improved.contains("professional") {
            improved += ", professional"
        }
        
        improved += ", 9:16 aspect ratio"
        
        return improved
    }
    
    func checkPromptQuality(_ prompt: String) -> (score: Int, message: String) {
        let wordCount = prompt.split(separator: " ").count
        
        if wordCount < 3 {
            return (30, "Çok kısa - daha detay ekleyin")
        } else if wordCount < 6 {
            return (60, "Orta - biraz daha detay ekleyin")
        } else if wordCount > 20 {
            return (70, "Çok uzun - kısaltmayı deneyin")
        } else {
            return (90, "İyi prompt!")
        }
    }
    
    func getQuickTemplate(_ type: String, subject: String) -> String {
        switch type {
        case "cinematic":
            return "Cinematic shot of \(subject), professional lighting, 4K quality"
        case "anime":
            return "Anime style \(subject), vibrant colors, smooth animation"
        case "realistic":
            return "Realistic video of \(subject), natural lighting, high detail"
        default:
            return subject
        }
    }
}
