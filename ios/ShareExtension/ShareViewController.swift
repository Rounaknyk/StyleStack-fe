import receive_sharing_intent

final class ShareViewController: RSIShareViewController {
  override func shouldAutoRedirect() -> Bool {
    true
  }

  override var sendButtonTitle: String { "Add to StyleStack" }
  override var placeholder: String { "Add these pieces to your wardrobe" }
}
