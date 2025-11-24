import Foundation

extension Error {
    var isCancelledRequest: Bool {
        if let urlError = self as? URLError {
            return urlError.code == .cancelled
        }
        
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

