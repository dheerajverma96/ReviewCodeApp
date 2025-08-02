//
//  ContentView.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import SwiftUI
import UIKit

// GitHub Color Palette
extension Color {
   /// static let gitHubBlue = Color(red: 0.04, green: 0.42, blue: 0.85)
}

struct ContentView: View {
    @StateObject private var viewModel = PRReviewViewModel()
    @State private var showWelcome = true
    @State private var isAnimatingOut = false
    
    var body: some View {
        ZStack {
            // Main App Content
            TabView {
                // Main PR List View
                PRListView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Pull Requests")
                    }
                
                // Settings/Repository View
                RepositorySettingsView(viewModel: viewModel)
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
            }
            .opacity(showWelcome ? 0 : 1)
            .scaleEffect(showWelcome ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.8), value: showWelcome)
            
            // Welcome Screen Overlay
            if showWelcome {
                WelcomeView {
                    dismissWelcomeScreen()
                }
                .opacity(isAnimatingOut ? 0 : 1)
                .scaleEffect(isAnimatingOut ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8), value: isAnimatingOut)
            }
        }
    }
    
    private func dismissWelcomeScreen() {
        withAnimation(.easeInOut(duration: 0.8)) {
            isAnimatingOut = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showWelcome = false
            isAnimatingOut = false
        }
    }
}

struct RepositorySettingsView: View {
    @ObservedObject var viewModel: PRReviewViewModel
    @State private var owner = ""
    @State private var repo = ""
    @State private var token = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Repository Configuration")) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Owner field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Repository Owner")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                if !owner.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            TextField("e.g., microsoft", text: $owner)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        // Repository field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Repository Name")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                if !repo.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            TextField("e.g., vscode", text: $repo)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        // GitHub Token field
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("GitHub Personal Access Token")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                if isValidToken {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                } else if !token.isEmpty {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                            }
                            SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $token)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            HStack {
                                Text("Requires 'repo' and 'user:read' permissions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !token.isEmpty && !isValidToken {
                                    Text("Must start with 'ghp_'")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Quick Setup Examples")) {
                    Button(action: {
                        owner = "microsoft"
                        repo = "vscode"
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("🔍 Example: Microsoft VSCode")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("microsoft/vscode (Token required)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        owner = "facebook"
                        repo = "react"
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("⚛️ Example: Facebook React")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("facebook/react (Token required)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        owner = "apple"
                        repo = "swift"
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("🍎 Example: Apple Swift")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("apple/swift (Token required)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button(action: {
                        saveAndConnect()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 8)
                            }
                            Text(isLoading ? "Connecting..." : "Save & Connect")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isValidConfiguration ? Color.gitHubBlue : Color.gray)
                        )
                    }
                    .disabled(!isValidConfiguration || isLoading)
                    
                    HStack {
                        Button("Clear All") {
                            owner = ""
                            repo = ""
                            token = ""
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Refresh Data") {
                            viewModel.refreshData()
                        }
                        .disabled(!isValidConfiguration)
                    }
                }
                
                Section(header: Text("Current Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(configurationStatus)
                                .foregroundColor(isValidConfiguration ? .green : .orange)
                                .fontWeight(.medium)
                        }
                        
                        if owner.isEmpty && repo.isEmpty && token.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("⚠️ No configuration set")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                                
                                Text("Please enter your repository owner, name, and GitHub token above to get started.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            if !owner.isEmpty || !repo.isEmpty {
                                HStack {
                                    Text("Repository:")
                                    Spacer()
                                    Text("\(owner)/\(repo)")
                                        .foregroundColor(.secondary)
                                        .font(.system(.subheadline, design: .monospaced))
                                }
                            }
                            
                            if !token.isEmpty {
                                HStack {
                                    Text("Token:")
                                    Spacer()
                                    if token.count >= 7 {
                                        Text("\(token.prefix(7))***\(token.suffix(4))")
                                            .foregroundColor(.secondary)
                                            .font(.system(.caption, design: .monospaced))
                                    } else {
                                        Text("Invalid format")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("User Information")) {
                    if let user = viewModel.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                Text("Connected as \(user.name)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("GitHub ID:")
                                    Spacer()
                                    Text("\(user.githubId)")
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("Role:")
                                    Spacer()
                                    Text(user.role.rawValue.capitalized)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.subheadline)
                        }
                    } else {
                        HStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 12, height: 12)
                            Text("Not connected - Check your configuration")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("How to Get GitHub Token")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Steps to create a Personal Access Token:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. 🌐 Go to GitHub.com → Settings → Developer settings")
                            Text("2. 🔑 Click 'Personal access tokens' → 'Tokens (classic)'")
                            Text("3. ➕ Click 'Generate new token (classic)'")
                            Text("4. ✅ Select scopes: 'repo' and 'user:read'")
                            Text("5. 📋 Copy the generated token (starts with 'ghp_')")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Text("⚠️ Keep your token secure and never share it publicly!")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            loadCurrentConfiguration()
        }
        .alert("Configuration Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isValidToken: Bool {
        !token.isEmpty && token.hasPrefix("ghp_") && token.count > 10
    }
    
    private var isValidConfiguration: Bool {
        !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidToken
    }
    
    private var configurationStatus: String {
        if owner.isEmpty || repo.isEmpty || token.isEmpty {
            return "Incomplete"
        } else if !isValidToken {
            return "Invalid Token"
        } else {
            return "Ready"
        }
    }
    
    private func loadCurrentConfiguration() {
        // Load from UserDefaults only - no defaults
        owner = UserDefaults.standard.string(forKey: "github_owner") ?? ""
        repo = UserDefaults.standard.string(forKey: "github_repo") ?? ""
        token = UserDefaults.standard.string(forKey: "github_token") ?? ""
    }
    
    private func saveAndConnect() {
        guard isValidConfiguration else {
            alertMessage = "Please fill in all fields with valid values. Token must start with 'ghp_' and be properly formatted."
            showingAlert = true
            return
        }
        
        isLoading = true
        
        let cleanOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRepo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save to UserDefaults
        UserDefaults.standard.set(cleanOwner, forKey: "github_owner")
        UserDefaults.standard.set(cleanRepo, forKey: "github_repo")
        UserDefaults.standard.set(cleanToken, forKey: "github_token")
        
        // Update the repository configuration
        viewModel.updateConfiguration(
            owner: cleanOwner,
            repo: cleanRepo,
            token: cleanToken
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            alertMessage = "✅ Configuration saved successfully!\n\nThe app will now fetch data from \(cleanOwner)/\(cleanRepo) using your GitHub token."
            showingAlert = true
        }
    }
}

#Preview {
    ContentView()
}
