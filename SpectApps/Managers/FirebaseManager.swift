//
//  FirebaseManager.swift
//  SpectApps
//
//  Created by Malik on 27.07.2025.
//

import Firebase
import FirebaseFirestore
import Combine

@MainActor
class SimpleFirebaseManager: ObservableObject {
    
    @Published var videoHistory: [VideoItem] = []
    
    private let db = Firestore.firestore()
    
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
    
    func saveVideo(prompt: String, videoURL: String) async {
        let videoData: [String: Any] = [
            "prompt": prompt,
            "videoURL": videoURL,
            "createdAt": Timestamp()
        ]
        
        do {
            try await db.collection("videos").addDocument(data: videoData)
            print("Video kaydedildi")
        } catch {
            print("Kaydetme hatası: \(error)")
        }
    }
    
    func loadVideoHistory() async {
        do {
            let snapshot = try await db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            videoHistory = snapshot.documents.compactMap { doc in
                let data = doc.data()
                return VideoItem(
                    id: doc.documentID,
                    prompt: data["prompt"] as? String ?? "",
                    videoURL: data["videoURL"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
        } catch {
            print("Yükleme hatası: \(error)")
        }
    }
}
