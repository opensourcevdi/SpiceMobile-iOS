import Foundation

/// Utility to load JavaScript resources from the main bundle.
/// Supports an optional subdirectory and simple placeholder replacements.
struct JSLoader {
    /// Loads a JavaScript file as a String from the main bundle.
    /// - Parameters:
    ///   - name: Resource name without extension.
    ///   - directory: Optional subdirectory inside the bundle.
    ///   - replacements: Optional key->value replacements to apply to the loaded content.
    /// - Returns: The loaded (and replaced) JS source, or empty string if not found.
    static func load(name: String, directory: String? = nil, replacements: [String: String] = [:]) -> String {
        let path = Bundle.main.path(forResource: name, ofType: "js", inDirectory: directory)
        guard let path else {
            #if DEBUG
            NSLog("[JSLoader] Resource not found: %@.js in directory %@", name, directory ?? "<nil>")
            #endif
            return ""
        }
        do {
            var source = try String(contentsOfFile: path, encoding: .utf8)
            if !replacements.isEmpty {
                for (key, value) in replacements {
                    source = source.replacingOccurrences(of: key, with: value)
                }
            }
            return source
        } catch {
            #if DEBUG
            NSLog("[JSLoader] Failed to read JS resource %@.js: %@", name, String(describing: error))
            #endif
            return ""
        }
    }
}
