import UserNotifications
import CryptoKit

/// iOS Notification Service Extension — rich-media push.
///
/// This is a SEPARATE app target (not part of Runner). The push payload MUST
/// carry `mutable-content: 1` plus an `image` URL, and the extension's
/// Info.plist MUST set `NSExtensionPointIdentifier =
/// com.apple.usernotifications.service` with principal class
/// `$(PRODUCT_MODULE_NAME).NotificationService` (see `platform_setup.md`).
///
/// The system gives the extension a hard time budget; ALWAYS call
/// `contentHandler` (in a `defer`) and implement `serviceExtensionTimeWillExpire`
/// so the notification still shows if the download is slow.
class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt = UNMutableNotificationContent()

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttempt = (request.content.mutableCopy() as? UNMutableNotificationContent)
            ?? UNMutableNotificationContent()

        let info = bestAttempt.userInfo
        let imageUrl = (info["image"] as? String)
            ?? ((info["fcm_options"] as? [String: Any])?["image"] as? String)

        guard let urlString = imageUrl, let url = URL(string: urlString) else {
            contentHandler(bestAttempt)
            return
        }
        downloadAndAttach(from: url)
    }

    override func serviceExtensionTimeWillExpire() {
        // Out of time: ship whatever we have.
        contentHandler?(bestAttempt)
    }

    private func downloadAndAttach(from url: URL) {
        URLSession.shared.downloadTask(with: url) { [weak self] tempUrl, response, _ in
            guard let self = self else { return }
            // Always deliver, attachment or not.
            defer { self.contentHandler?(self.bestAttempt) }

            guard let tempUrl = tempUrl else { return }
            let ext = self.fileExtension(for: response, url: url)
            let identifier = self.attachmentIdentifier(ext: ext)

            let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("NotificationAttachments", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let target = dir.appendingPathComponent(identifier)
            try? FileManager.default.moveItem(at: tempUrl, to: target)

            if let attachment = try? UNNotificationAttachment(
                identifier: identifier,
                url: target,
                options: [UNNotificationAttachmentOptionsTypeHintKey: self.typeHint(for: ext)]
            ) {
                self.bestAttempt.attachments = [attachment]
            }
        }.resume()
    }

    private func attachmentIdentifier(ext: String) -> String {
        let stamp = "\(Date().timeIntervalSince1970)"
        let digest = SHA256.hash(data: Data(stamp.utf8))
        let hash = digest.compactMap { String(format: "%02x", $0) }.joined().prefix(8)
        return "\(stamp)_\(hash).\(ext)"
    }

    private func fileExtension(for response: URLResponse?, url: URL) -> String {
        if !url.pathExtension.isEmpty { return url.pathExtension }
        switch response?.mimeType {
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/jpeg": return "jpg"
        default: return "jpg"
        }
    }

    private func typeHint(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "public.png"
        case "gif": return "com.compuserve.gif"
        default: return "public.jpeg"
        }
    }
}
