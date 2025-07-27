//
//  ReplicateManager.swift
//  SpectApps
//
//  Created by Malik on 25.07.2025.
//

import Combine
import Foundation
import Replicate
import UIKit

// MARK: - Enums and Models
enum VideoGenerationStatus: Equatable {
    case idle
    case starting
    case processing
    case completed(String) // Video URL
    case failed(String) // Error message
    
    var isProcessing: Bool {
        switch self {
        case .starting, .processing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Configuration
struct VideoGenerationConfig {
    let prompt: String
    let image: UIImage?
    
    init(prompt: String, image: UIImage? = nil) {
        self.prompt = prompt
        self.image = image
    }
}

// MARK: - Replicate Manager
@MainActor
class ReplicateManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var status: VideoGenerationStatus = .idle
    @Published var progress: String = ""
    
    // MARK: - Private Properties
    private let apiKey: String
    private let modelName = "kwaivgi/kling-v2.1-master" //"minimax/video-01"
    private var taskId: String?
    private var statusTimer: Timer?
    
    // MARK: - Initialization
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    deinit {
        statusTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    func generateVideo(config: VideoGenerationConfig) {
        guard !status.isProcessing else { return }
        
        reset()
        status = .starting
        progress = "Video üretimi başlatılıyor..."
        
        Task {
            do {
                let client = Replicate.Client(token: apiKey)
                let model: Model = try await client.getModel(modelName)
                
                guard let versionId = model.latestVersion?.id else {
                    await handleCustomError("Model versiyonu bulunamadı")
                    return
                }
                
                let enhancedPrompt = config.prompt + ". Generate the video in 9:16 aspect ratio."
                var inputConfig: [String: Value] = [
                    "prompt": Value(stringLiteral: enhancedPrompt),
                    "aspect_ratio": Value(stringLiteral: "9:16")
                ]
                
                if let image = config.image {
                    print("---> Görsel bulundu, base64'e çevriliyor...")
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        let base64String = "data:image/jpeg;base64," + imageData.base64EncodedString()
                        inputConfig["start_image"] = Value(stringLiteral: base64String)
                        print("---> Görsel start_image olarak eklendi. Size: \(imageData.count) bytes")
                    } else {
                        print("---> Görsel JPEG formatına çevrilemedi")
                    }
                } else {
                    print("---> Görsel bulunamadı, sadece prompt kullanılacak")
                }
                
                print("---> Gönderilen input config: \(inputConfig.keys)")
                
                progress = "Model çalıştırılıyor..."
                let prediction = try await client.createPrediction(
                    version: versionId,
                    input: inputConfig
                )
                
                if prediction.status == .starting || prediction.status == .processing {
                    self.taskId = prediction.id
                    self.status = .processing
                    self.progress = "Video işleniyor..."
                    self.startStatusPolling()
                } else {
                    await handleCustomError("Video üretimi başlatılamadı")
                }
                
            } catch {
                await handleError(error as! Error)
            }
        }
    }
    
    func cancelGeneration() {
        stopStatusPolling()
        reset()
    }
    
    // MARK: - Private Methods
    private func reset() {
        stopStatusPolling()
        taskId = nil
        progress = ""
        if case .processing = status { } else {
            status = .idle
        }
    }
    
    private func startStatusPolling() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.checkStatus()
            }
        }
    }
    
    private func stopStatusPolling() {
        statusTimer?.invalidate()
        statusTimer = nil
    }
    
    private func checkStatus() async {
        guard let taskId = taskId else {
            await handleCustomError("Task ID bulunamadı")
            return
        }
        
        do {
            let client = Replicate.Client(token: apiKey)
            let prediction = try await client.getPrediction(id: taskId)
            
            switch prediction.status {
            case .starting:
                progress = "Video üretimi başlıyor..."
                
            case .processing:
                progress = "Video işleniyor..."
                
            case .succeeded:
                stopStatusPolling()
                
                if let output = prediction.output {
                    do {
                        let videoURL = try extractVideoURL(from: output)
                        status = .completed(videoURL)
                        progress = "Video hazır!"
                        print("---> Video URL: \(videoURL)")
                    } catch {
                        await handleCustomError("Geçersiz çıktı formatı")
                    }
                } else {
                    await handleCustomError("Geçersiz çıktı formatı")
                }
                
            case .failed:
                stopStatusPolling()
                let errorMsg = prediction.error?.localizedDescription ?? "Bilinmeyen hata"
                await handleCustomError("Video üretimi başarısız: \(errorMsg)")
                
            case .canceled:
                stopStatusPolling()
                await handleCustomError("Video üretimi iptal edildi")
            }
            
        } catch {
            await handleCustomError("Ağ hatası: \(error.localizedDescription)")
        }
    }
    
    private func extractVideoURL(from output: Value) throws -> String {
        print("---> Video URL çıkarılıyor: \(output)")
        
        switch output {
        case .array(let array):
            let strings = array.compactMap { $0.stringValue }
            guard let videoURL = strings.first else {
                throw NSError(domain: "VideoError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video URL found"])
            }
            return videoURL
            
        case .string(let urlString):
            return urlString
            
        case .object(let dict):
            let possibleKeys = ["url", "video_url", "output_url", "file_url", "result", "output", "video", "mp4"]
            
            for key in possibleKeys {
                if let urlString = dict[key]?.stringValue {
                    return urlString
                }
            }
            
            for (_, value) in dict {
                if let subDict = value.objectValue {
                    for subKey in possibleKeys {
                        if let urlString = subDict[subKey]?.stringValue {
                            return urlString
                        }
                    }
                }
            }
            
            throw NSError(domain: "VideoError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No video URL found in output"])
            
        default:
            throw NSError(domain: "VideoError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid output format"])
        }
    }
    
    private func handleError(_ error: Error) async {
        stopStatusPolling()
        
        let errorMessage = error.localizedDescription
        status = .failed(errorMessage)
        progress = "Hata oluştu"
        print("---> Hata: \(errorMessage)")
    }
    
    private func handleCustomError(_ message: String) async {
        stopStatusPolling()
        
        status = .failed(message)
        progress = "Hata oluştu"
        print("---> Hata: \(message)")
    }
}
