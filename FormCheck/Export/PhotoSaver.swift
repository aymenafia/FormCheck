import Photos

enum PhotoSaver {
    enum SaveError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "FormCheck needs permission to add videos to your Photos. Enable it in Settings → FormCheck → Photos."
            }
        }
    }

    /// Saves a video file to the user's photo library, requesting add-only
    /// permission if needed. The add-only level keeps our privacy footprint
    /// minimal — we can add, but never read the library.
    static func saveVideo(at url: URL) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let granted: Bool
        switch status {
        case .authorized, .limited:
            granted = true
        case .notDetermined:
            granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
        default:
            granted = false
        }
        guard granted else { throw SaveError.permissionDenied }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
