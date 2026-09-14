import SwiftUI
import UIKit
import ImageIO
import QuickLook

// Images are copied into Application Support; never retain a Photos temporary URL.
final class LocalMediaFiles: @unchecked Sendable {
    let directory: URL
    private let cache = NSCache<NSString, UIImage>()
    private let aspectCache = NSCache<NSString, NSNumber>()
    private let readableCache = NSCache<NSString, NSNumber>()
    init(directory: URL) {
        self.directory = directory
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func url(_ key: String) -> URL? {
        if key.hasPrefix("local:") {
            let name = String(key.dropFirst(6))
            guard !name.isEmpty, name == (name as NSString).lastPathComponent else { return nil }
            return directory.appendingPathComponent(name)
        }
        return Bundle.main.url(forResource: key, withExtension: "jpg")
            ?? Bundle.main.url(forResource: key, withExtension: "png")
            ?? Bundle.main.url(forResource: key, withExtension: "jpg", subdirectory: "Resources")
            ?? Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "Resources")
    }

    func isReadable(_ key: String) -> Bool {
        if let result = readableCache.object(forKey: key as NSString) { return result.boolValue }
        // Check once at thumbnail size; corrupt files never become giant empty bubbles.
        let result = image(key, maxPixel: 96) != nil
        readableCache.setObject(NSNumber(value: result), forKey: key as NSString)
        return result
    }

    func image(_ key: String, maxPixel: Int = 800) -> UIImage? {
        let cacheKey = "\(key)@\(maxPixel)" as NSString
        if let image = cache.object(forKey: cacheKey) { return image }
        guard let url = url(key), let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = Self.thumbnail(source, maxPixel: maxPixel) else { return UIImage(named: key) }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: cacheKey, cost: cg.bytesPerRow * cg.height)
        return image
    }

    func aspect(_ key: String) -> CGFloat {
        // Existing resources are 139x139 video-picker crops, not original photos.
        // Only those demo thumbnails need hints; all imported images use their real ratio.
        let hints: [String: CGFloat] = ["photo_7": 0.72, "photo_8": 1.78, "photo_9": 1.78,
            "photo_10": 1.78, "photo_11": 1.78, "photo_12": 1.78, "photo_13": 0.72,
            "photo_14": 0.72, "photo_15": 0.72]
        if !key.hasPrefix("local:"), let hint = hints[key] { return hint }
        if let ratio = aspectCache.object(forKey: key as NSString) { return CGFloat(ratio.doubleValue) }
        // Reading dimensions must not decode every photo again on each drag frame.
        guard let url = url(key), let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let w = properties[kCGImagePropertyPixelWidth] as? NSNumber,
            let h = properties[kCGImagePropertyPixelHeight] as? NSNumber, h.doubleValue > 0 else { return 1 }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let rotated = (5...8).contains(orientation)
        let ratio = rotated ? h.doubleValue / max(1, w.doubleValue) : w.doubleValue / h.doubleValue
        aspectCache.setObject(NSNumber(value: ratio), forKey: key as NSString)
        return CGFloat(ratio)
    }

    func importImage(_ data: Data, maxPixel: Int) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = Self.thumbnail(source, maxPixel: maxPixel) else { throw LocalDataError.invalidImage }
        let image = UIImage(cgImage: cg)
        let alpha = [CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(cg.alphaInfo)
        guard let bytes = alpha ? image.pngData() : image.jpegData(compressionQuality: 0.9) else {
            throw LocalDataError.invalidImage
        }
        let name = UUID().uuidString + (alpha ? ".png" : ".jpg")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try bytes.write(to: directory.appendingPathComponent(name), options: .atomic)
        return "local:" + name
    }

    // Call only for uncommitted imports, never for assets still referenced by an archive.
    func removeUnreferencedImport(_ key: String) {
        guard key.hasPrefix("local:"), let url = url(key) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func thumbnail(_ source: CGImageSource, maxPixel: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary)
    }
}

struct StoredPhoto: View {
    @EnvironmentObject private var store: DemoStore
    let source: String
    var maxPixel = 800
    var body: some View {
        Group {
            if let image = store.media.image(source, maxPixel: maxPixel) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .tertiarySystemFill)
                    Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct PhotoPresentation: Identifiable {
    let id = UUID()
    let keys: [String]
    var index = 0
}

// Public Quick Look supplies native full-screen paging, pinch zoom and sharing.
struct NativePhotoPreview: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DemoStore
    let presentation: PhotoPresentation

    final class Item: NSObject, QLPreviewItem {
        let previewItemURL: URL?
        let previewItemTitle: String?
        init(url: URL, title: String) { previewItemURL = url; previewItemTitle = title }
    }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var items: [Item] = []
        var close: () -> Void = {}
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { items.count }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { items[index] }
        @objc func done() { close() }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UINavigationController {
        context.coordinator.close = { dismiss() }
        context.coordinator.items = presentation.keys.enumerated().compactMap { index, key in
            guard let url = store.media.url(key), FileManager.default.fileExists(atPath: url.path) else { return nil }
            return Item(url: url, title: "照片 \(index + 1)")
        }
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        if !context.coordinator.items.isEmpty {
            preview.currentPreviewItemIndex = min(presentation.index, context.coordinator.items.count - 1)
        }
        preview.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
            target: context.coordinator, action: #selector(Coordinator.done))
        return UINavigationController(rootViewController: preview)
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onPhoto: (UIImage?) -> Void
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPhoto: (UIImage?) -> Void
        init(onPhoto: @escaping (UIImage?) -> Void) { self.onPhoto = onPhoto }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onPhoto(nil) }
        func imagePickerController(_ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPhoto(info[.originalImage] as? UIImage)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(onPhoto: onPhoto) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}
}
