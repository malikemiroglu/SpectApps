//
//  ContentView.swift
//  SpectApps
//
//  Created by Malik on 18.07.2025.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var prompt: String = ""

    var body: some View {
        VStack(spacing: 24) {

            // MARK: Image Picker Area
            ZStack {
                GeometryReader { geo in
                    if let uiImage = selectedImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Görsel seçmek için dokun")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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

            // MARK: Prompt Editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .frame(minHeight: 140, maxHeight: 200)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.gray.opacity(0.4))
                    )

                if prompt.isTrimmedEmpty {
                    Text("Prompt giriniz...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                }
            }
            .padding(.horizontal)

            // MARK: Generate Button
            Button {
                generate()
            } label: {
                Text("GENERATE")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImage == nil || prompt.isTrimmedEmpty)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 32)
    }

    // MARK: - Actions
    private func generate() {
        print("Generate tapped with prompt: \(prompt)")
        print("Image selected? \(selectedImage != nil)")
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
