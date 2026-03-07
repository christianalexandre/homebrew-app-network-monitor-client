//
//  MockRulesView.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 06/03/26.
//

import SwiftUI

struct MockRulesView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let onDismiss: () -> Void
    
    @State private var showAddRuleSheet = false
    @State private var editingRule: MockRule?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close")
                
                Text("Mock Rules")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showAddRuleSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add mock rule")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if viewModel.mockRules.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No mock rules")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Add rules to intercept and mock network responses")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(viewModel.mockRules) { rule in
                        MockRuleRow(
                            rule: rule,
                            onToggle: { viewModel.toggleMockRule(rule) },
                            onEdit: { editingRule = rule },
                            onDelete: { viewModel.deleteMockRule(rule) }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            if !viewModel.mockRules.isEmpty {
                Divider()
                HStack {
                    Text("\(viewModel.mockRules.filter { $0.isEnabled }.count) active")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear All") {
                        viewModel.clearAllMockRules()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(minHeight: 200)
        .sheet(isPresented: $showAddRuleSheet) {
            MockRuleEditorView(
                rule: nil,
                onSave: { rule in
                    viewModel.addMockRule(rule)
                    showAddRuleSheet = false
                },
                onCancel: { showAddRuleSheet = false }
            )
        }
        .sheet(item: $editingRule) { rule in
            MockRuleEditorView(
                rule: rule,
                onSave: { updatedRule in
                    viewModel.updateMockRule(updatedRule)
                    editingRule = nil
                },
                onCancel: { editingRule = nil }
            )
        }
    }
}

// MARK: - Mock Rule Row

struct MockRuleRow: View {
    let rule: MockRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var statusColor: Color {
        if rule.statusCode >= 200 && rule.statusCode < 300 { return .green }
        if rule.statusCode >= 400 { return .red }
        return .yellow
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let method = rule.method {
                        Text(method)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    Text(rule.path)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                HStack(spacing: 4) {
                    Text("\(rule.statusCode)")
                        .font(.caption2)
                        .foregroundColor(statusColor)
                    
                    if rule.delayMs > 0 {
                        Text("• \(rule.delayMs)ms delay")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Mock Rule Editor

struct MockRuleEditorView: View {
    let rule: MockRule?
    let onSave: (MockRule) -> Void
    let onCancel: () -> Void
    
    @State private var path: String = ""
    @State private var method: String = ""
    @State private var statusCode: String = "200"
    @State private var responseBody: String = ""
    @State private var delayMs: String = "0"
    @State private var isEnabled: Bool = true
    
    private let httpMethods = ["", "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
    
    private var normalizedResponseBody: String {
        responseBody
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
    }
    
    private var jsonValidationError: String? {
        guard !responseBody.isEmpty else { return nil }
        
        guard let data = normalizedResponseBody.data(using: .utf8) else {
            return "Invalid UTF-8 encoding"
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return nil
        } catch let error as NSError {
            return error.localizedDescription
        }
    }
    
    private var isJsonValid: Bool {
        responseBody.isEmpty || jsonValidationError == nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(rule == nil ? "Add Mock Rule" : "Edit Mock Rule")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Path Pattern")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("/api/users/*", text: $path)
                            .textFieldStyle(.roundedBorder)
                        Text("Use * as wildcard. Example: /api/users/* matches /api/users/123")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HTTP Method")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Picker("", selection: $method) {
                                ForEach(httpMethods, id: \.self) { m in
                                    Text(m.isEmpty ? "Any" : m).tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status Code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("200", text: $statusCode)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delay (ms)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0", text: $delayMs)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Response Body (JSON)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if !responseBody.isEmpty {
                                if isJsonValid {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Valid JSON")
                                            .foregroundColor(.green)
                                    }
                                    .font(.caption2)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                        Text("Invalid JSON")
                                            .foregroundColor(.red)
                                    }
                                    .font(.caption2)
                                }
                            }
                            
                            Button("Format") {
                                formatJson()
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .disabled(!isJsonValid || responseBody.isEmpty)
                            
                            if responseBody != normalizedResponseBody && !responseBody.isEmpty {
                                Button("Fix Quotes") {
                                    responseBody = normalizedResponseBody
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                                .foregroundColor(.orange)
                            }
                        }
                        
                        TextEditor(text: $responseBody)
                            .font(.system(.body, design: .monospaced))
                            .disableAutocorrection(true)
                            .textContentType(.none)
                            .frame(minHeight: 150)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isJsonValid ? Color.secondary.opacity(0.3) : Color.red, lineWidth: isJsonValid ? 1 : 2)
                            )
                        
                        if let error = jsonValidationError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                                .lineLimit(2)
                        }
                    }
                    
                    Toggle("Enabled", isOn: $isEnabled)
                }
            }
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    saveRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(path.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 500)
        .onAppear {
            if let rule = rule {
                path = rule.path
                method = rule.method ?? ""
                statusCode = String(rule.statusCode)
                responseBody = rule.responseBody ?? ""
                delayMs = String(rule.delayMs)
                isEnabled = rule.isEnabled
            }
        }
    }
    
    private func saveRule() {
        let headers = rule?.responseHeaders ?? ["Content-Type": "application/json"]
        let newRule = MockRule(
            id: rule?.id ?? UUID(),
            path: path,
            method: method.isEmpty ? nil : method,
            statusCode: Int(statusCode) ?? 200,
            responseHeaders: headers,
            responseBody: normalizedResponseBody.isEmpty ? nil : normalizedResponseBody,
            delayMs: Int(delayMs) ?? 0,
            isEnabled: isEnabled
        )
        onSave(newRule)
    }
    
    private func formatJson() {
        guard let data = normalizedResponseBody.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return
        }
        responseBody = prettyString
    }
}
