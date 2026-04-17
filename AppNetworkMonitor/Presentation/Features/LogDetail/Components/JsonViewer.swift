import SwiftUI

struct JsonViewer: View {
    let title: String
    let content: String?
    
    @State private var searchText: String = ""
    
    private var prettyContent: String {
        content?.prettyPrintedJSON ?? content ?? ""
    }
    
    private var matchCount: Int {
        guard !searchText.isEmpty else { return 0 }
        return prettyContent.ranges(of: searchText, options: .caseInsensitive).count
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let content = content, !content.isEmpty {
                    Button(action: {
                        let pretty = content.prettyPrintedJSON ?? content
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(pretty, forType: .string)
                    }) {
                        Label("Copy JSON", systemImage: "doc.on.doc")
                    }
                    .font(.caption)
                }
            }
            
            if let content = content, !content.isEmpty {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search in JSON...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    
                    if !searchText.isEmpty {
                        if matchCount > 0 {
                            Text("\(matchCount) found")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                
                // JSON content
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    if searchText.isEmpty {
                        Text(prettyContent)
                            .font(.system(size: 12, design: .monospaced))
                            .padding()
                            .foregroundColor(Color(nsColor: .textColor))
                            .textSelection(.enabled)
                    } else {
                        highlightedText
                            .font(.system(size: 12, design: .monospaced))
                            .padding()
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            } else {
                Text("Empty Body")
                    .italic()
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
    
    private var highlightedText: Text {
        let text = prettyContent
        guard !searchText.isEmpty else {
            return Text(text)
        }
        
        var result = Text("")
        var currentIndex = text.startIndex
        
        let ranges = text.ranges(of: searchText, options: .caseInsensitive)
        
        for range in ranges {
            // Text before match
            if currentIndex < range.lowerBound {
                result = result + Text(text[currentIndex..<range.lowerBound])
            }
            // Highlighted match
            result = result + Text(text[range])
                .foregroundColor(.yellow)
            currentIndex = range.upperBound
        }
        
        // Remaining text
        if currentIndex < text.endIndex {
            result = result + Text(text[currentIndex..<text.endIndex])
        }
        
        return result
    }
}

// MARK: - String Extension

extension String {
    func ranges(of searchString: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = self.startIndex
        
        while searchStartIndex < self.endIndex,
              let range = self.range(of: searchString, options: options, range: searchStartIndex..<self.endIndex) {
            ranges.append(range)
            searchStartIndex = range.upperBound
        }
        
        return ranges
    }
}
