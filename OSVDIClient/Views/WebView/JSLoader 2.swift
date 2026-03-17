import Foundation

/// Loads a JavaScript file from the main bundle and exposes its source as a String.
struct JSLoader {
    let source: String

    /// Initialize with the base file name (without extension) of a .js resource in the main bundle.
    /// If the file cannot be found or read, `source` will be an empty string.
    init(fileName: String) {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "js") {
            self.source = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        } else {
            self.source = ""
        }
    }
}
