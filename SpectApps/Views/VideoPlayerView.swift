//
//  VideoPlayerView.swift
//  SpectApps
//
//  Created by Malik on 25.07.2025.
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let videoURL: String
    let prompt: String
    
    @State private var player: AVPlayer? = nil
    @State private var isLoading: Bool = true
    @State private var hasError: Bool = false
    @State private var showingShareSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if let player = player, !hasError {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .cornerRadius(12)
                        .onAppear {
                            configureAudioSession()
                            player.play()
                        }
                        .onDisappear {
                            player.pause()
                        }
                } else if hasError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Video yüklenemedi")
                            .font(.headline)
                        
                        Text("Video URL'si geçersiz veya video henüz hazır değil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Tekrar Dene") {
                            loadVideo()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(height: 300)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Video yükleniyor...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 300)
                }
            }
            .background(Color.black.opacity(0.1))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Kullanılan Prompt:")
                    .font(.headline)
                
                Text(prompt)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 12) {
                Button {
                    showingShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Video Paylaş")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    UIPasteboard.general.string = videoURL
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("URL Kopyala")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Üretilen Video")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadVideo()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [videoURL])
        }
    }
    
    private func loadVideo() {
        isLoading = true
        hasError = false
        
        guard let url = URL(string: videoURL) else {
            hasError = true
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Video URL kontrolü başarısız: \(error.localizedDescription)")
                    hasError = true
                } else if let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 {
                    player = AVPlayer(url: url)
                    
                    player?.isMuted = false
                    player?.volume = 1.0
                    
                    hasError = false
                } else {
                    hasError = true
                }
                isLoading = false
            }
        }.resume()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session ayarlanamadı: \(error.localizedDescription)")
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
