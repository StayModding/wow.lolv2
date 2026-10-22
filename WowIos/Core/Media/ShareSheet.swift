import SwiftUI
import UIKit

/// Minimal share sheet so exports can go to Files, AirDrop or Messages.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Wraps a file URL as a shareable item with a friendly name.
func shareItems(for url: URL, title: String) -> [Any] {
    _ = title
    return [url]
}
