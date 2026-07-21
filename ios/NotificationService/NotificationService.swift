import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent,
              let imageURL = notificationImageURL(from: request.content.userInfo) else {
            contentHandler(request.content)
            return
        }

        URLSession.shared.downloadTask(with: imageURL) { temporaryURL, _, _ in
            guard let temporaryURL else {
                contentHandler(content)
                return
            }

            let fileExtension = imageURL.pathExtension.isEmpty ? "jpg" : imageURL.pathExtension
            let localURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            do {
                try FileManager.default.moveItem(at: temporaryURL, to: localURL)
                let attachment = try UNNotificationAttachment(
                    identifier: "stylestack-notification-media",
                    url: localURL
                )
                content.attachments = [attachment]
            } catch {
                // The text notification is still delivered when media cannot be downloaded.
            }
            contentHandler(content)
        }.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func notificationImageURL(from userInfo: [AnyHashable: Any]) -> URL? {
        let candidates = [
            userInfo["image_url"] as? String,
            userInfo["gcm.notification.image"] as? String,
            userInfo["fcm_options.image"] as? String,
        ]

        return candidates
            .compactMap { $0 }
            .compactMap(URL.init(string:))
            .first { $0.scheme?.lowercased() == "https" }
    }
}
