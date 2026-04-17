struct CurlGenerator {
    static func generate(from log: LogModel) -> String {
        var components = ["curl -v"]
        components.append("-X \(log.method)")
        
        if let headers = log.requestHeaders {
            for (key, value) in headers {
                if key.lowercased() != "content-length" {
                    components.append("-H \"\(key): \(value)\"")
                }
            }
        }
        
        if let body = log.requestBody, !body.isEmpty {
            let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escapedBody)\"")
        }
        
        components.append("\"\(log.url)\"")
        return components.joined(separator: " \\\n\t")
    }
}
