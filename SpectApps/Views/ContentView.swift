//
//  ContentView.swift
//  SpectApps
//
//  Created by Malik on 18.07.2025.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    
    @StateObject private var replicateManager = ReplicateManager(apiKey: Globals.ReplicateAPIKey)
    @StateObject private var firebaseManager = SimpleFirebaseManager()
    @StateObject private var promptManager = SimplePromptManager()
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var prompt: String = ""
    @State private var navigateToVideo = false
    @State private var videoURL: String = ""
    @State private var generatedPrompt: String = ""
    @State private var showingHistory = false
    @State private var selectedTemplate = "basic"
    
    @FocusState private var isPromptFocused: Bool
    
    private let templates = ["basic", "cinematic", "anime", "realistic"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                // MARK: Image Picker
                ZStack {
                    GeometryReader { geo in
                        if let uiImage = selectedImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.width, height: geo.size.height)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("Görsel seçmek için dokun (Opsiyonel)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                            .contentShape(Rectangle())
                        }
                    }
                    PhotosPicker(selection: $selectedItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Color.clear
                    }
                                 .task(id: selectedItem) {
                                     guard let item = selectedItem else { return }
                                     do {
                                         if let data = try await item.loadTransferable(type: Data.self),
                                            let uiImage = UIImage(data: data) {
                                             selectedImage = uiImage
                                         }
                                     } catch {
                                         print("Görsel yüklenemedi:", error.localizedDescription)
                                     }
                                 }
                    
                    if selectedImage != nil {
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    selectedImage = nil
                                    selectedItem = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(.gray.opacity(0.5))
                )
                .padding(.horizontal)
                
                // MARK: Şablon Seçimi
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hızlı Şablon:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        ForEach(templates, id: \.self) { template in
                            Button {
                                selectedTemplate = template
                                if template != "basic" && !prompt.isEmpty {
                                    prompt = promptManager.getQuickTemplate(template, subject: prompt)
                                }
                            } label: {
                                Text(template.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTemplate == template ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedTemplate == template ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // MARK: Prompt Editor + Kalite Kontrolü
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Video Prompt'u:")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Geliştir") {
                            prompt = promptManager.improvePrompt(prompt)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .disabled(prompt.isEmpty)
                    }
                    .padding(.horizontal)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $prompt)
                            .focused($isPromptFocused)
                            .frame(minHeight: 100, maxHeight: 150)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.gray.opacity(0.4))
                            )
                        
                        if prompt.isTrimmedEmpty {
                            Text("Video için prompt giriniz...")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal)
                    
                    if !prompt.isTrimmedEmpty {
                        let quality = promptManager.checkPromptQuality(prompt)
                        HStack {
                            Circle()
                                .fill(quality.score > 70 ? Color.green : quality.score > 50 ? Color.orange : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(quality.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Geçmiş") {
                                showingHistory = true
                                Task {
                                    await firebaseManager.loadVideoHistory()
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // MARK: Status and Progress
                if replicateManager.status.isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text(replicateManager.progress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("İptal Et") {
                            replicateManager.cancelGeneration()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // MARK: Error Message
                if case .failed(let errorMessage) = replicateManager.status {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("Hata Oluştu")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Tekrar Dene") {
                            generate()
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // MARK: Generate Button
                Button {
                    generate()
                } label: {
                    HStack {
                        if replicateManager.status.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        Text(replicateManager.status.isProcessing ? "ÜRETİLİYOR..." : "GENERATE")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(height: 40)
                .disabled(prompt.isTrimmedEmpty || replicateManager.status.isProcessing)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("AI Video Generator")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToVideo) {
                VideoPlayerView(videoURL: videoURL, prompt: generatedPrompt)
            }
            .onChange(of: replicateManager.status, initial: false) { _, newStatus in
                if case .completed(let url) = newStatus {
                    videoURL = url
                    generatedPrompt = prompt
                    navigateToVideo = true
                    
                    Task {
                        await firebaseManager.saveVideo(prompt: prompt, videoURL: url)
                    }
                }
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView(firebaseManager: firebaseManager)
            }
        }
    }
    
    // MARK: - Actions
    private func generate() {
        isPromptFocused = false
        
        let improvedPrompt = promptManager.improvePrompt(prompt)
        
        let config = VideoGenerationConfig(prompt: improvedPrompt, image: selectedImage)
        replicateManager.generateVideo(config: config)
        
        print("---> Generate tapped with improved prompt: \(improvedPrompt)")
    }
}

private extension String {
    var isTrimmedEmpty: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    ContentView()
}
