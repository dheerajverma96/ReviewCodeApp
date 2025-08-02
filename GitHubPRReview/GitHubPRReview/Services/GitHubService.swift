//
//  GitHubService.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import Foundation
import Combine

// MARK: - GitHub Error
enum GitHubError: Error, LocalizedError {
    case invalidURL
    case networkError(String)
    case decodingError
    case unauthorized
    case rateLimited
    case notFound
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .unauthorized:
            return "Unauthorized - check your token"
        case .rateLimited:
            return "Rate limited - try again later"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error"
        }
    }
}

class GitHubService: ObservableObject {
    private let baseURL = "https://api.github.com"
    private let session = URLSession.shared
    private var token: String
    
    private var authHeaders: [String: String] {
        return [
            "Authorization": "token \(token)",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "GitHubPRReview-iOS"
        ]
    }
    
    init() {
        // Load token from UserDefaults - no defaults
        self.token = UserDefaults.standard.string(forKey: "github_token") ?? ""
    }
    
    // MARK: - Authentication
    
    func updateToken(_ newToken: String) {
        self.token = newToken
    }
    
    func getTokenPreview() -> String {
        if token.isEmpty {
            return "EMPTY"
        }
        return "\(token.prefix(7))...***"
    }
    
    func testConnection() -> AnyPublisher<GitHubUser, GitHubError> {
        let url = URL(string: "\(baseURL)/user")!
        
        var request = URLRequest(url: url)
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        return data
                    case 401:
                        throw GitHubError.unauthorized
                    case 403:
                        throw GitHubError.rateLimited
                    case 404:
                        throw GitHubError.notFound
                    default:
                        throw GitHubError.networkError("HTTP \(httpResponse.statusCode)")
                    }
                }
                return data
            }
            .decode(type: GitHubUser.self, decoder: JSONDecoder.githubDecoder)
            .mapError { error in
                if let githubError = error as? GitHubError {
                    return githubError
                } else if error is DecodingError {
                    return GitHubError.decodingError
                } else {
                    return GitHubError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Pull Requests
    
    func fetchPullRequests(owner: String, repo: String, state: String = "all") -> AnyPublisher<[GitHubPullRequest], GitHubError> {
        // Clean repository parameters
        let cleanOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRepo = repo
            .replacingOccurrences(of: "@", with: "")
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "https://github.com", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let urlString = "\(baseURL)/repos/\(cleanOwner)/\(cleanRepo)/pulls?state=\(state)&per_page=100"
        
        print("🔍 Fetching PRs from: \(urlString)")
        print("   - Clean owner: '\(cleanOwner)'")
        print("   - Clean repo: '\(cleanRepo)'")
        print("   - State: '\(state)'")
        print("   - Token: \(token.prefix(7))...***")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return Fail(error: GitHubError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 PR API Response Status: \(httpResponse.statusCode)")
                    switch httpResponse.statusCode {
                    case 200:
                        return data
                    case 401:
                        throw GitHubError.unauthorized
                    case 403:
                        throw GitHubError.rateLimited
                    case 404:
                        throw GitHubError.notFound
                    default:
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("❌ API Error Response: \(responseString)")
                        }
                        throw GitHubError.networkError("HTTP \(httpResponse.statusCode)")
                    }
                }
                return data
            }
            .decode(type: [GitHubPullRequest].self, decoder: JSONDecoder.githubDecoder)
            .handleEvents(receiveOutput: { prs in
                print("✅ Fetched \(prs.count) PRs")
                for pr in prs.prefix(3) {
                    print("  - PR #\(pr.number): \(pr.title) by \(pr.user.login)")
                }
            })
            .mapError { error in
                print("❌ PR fetching error: \(error)")
                if let githubError = error as? GitHubError {
                    return githubError
                } else if error is DecodingError {
                    return GitHubError.decodingError
                } else {
                    return GitHubError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func fetchPullRequestReviews(owner: String, repo: String, pullNumber: Int) -> AnyPublisher<[GitHubReview], GitHubError> {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/pulls/\(pullNumber)/reviews")!
        
        var request = URLRequest(url: url)
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        return data
                    case 401:
                        throw GitHubError.unauthorized
                    case 403:
                        throw GitHubError.rateLimited
                    case 404:
                        throw GitHubError.notFound
                    default:
                        throw GitHubError.networkError("HTTP \(httpResponse.statusCode)")
                    }
                }
                return data
            }
            .decode(type: [GitHubReview].self, decoder: JSONDecoder.githubDecoder)
            .mapError { error in
                if let githubError = error as? GitHubError {
                    return githubError
                } else if error is DecodingError {
                    return GitHubError.decodingError
                } else {
                    return GitHubError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func fetchIssueComments(owner: String, repo: String, issueNumber: Int) -> AnyPublisher<[GitHubComment], GitHubError> {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments")!
        
        var request = URLRequest(url: url)
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200:
                        return data
                    case 401:
                        throw GitHubError.unauthorized
                    case 403:
                        throw GitHubError.rateLimited
                    case 404:
                        throw GitHubError.notFound
                    default:
                        throw GitHubError.networkError("HTTP \(httpResponse.statusCode)")
                    }
                }
                return data
            }
            .decode(type: [GitHubComment].self, decoder: JSONDecoder.githubDecoder)
            .mapError { error in
                if let githubError = error as? GitHubError {
                    return githubError
                } else if error is DecodingError {
                    return GitHubError.decodingError
                } else {
                    return GitHubError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Create Operations
    
    func createComment(owner: String, repo: String, issueNumber: Int, body: String) -> AnyPublisher<GitHubComment, GitHubError> {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments")!
        
        let requestBody = ["body": body]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 201:
                        return data
                    case 401:
                        throw GitHubError.unauthorized
                    case 403:
                        throw GitHubError.rateLimited
                    case 404:
                        throw GitHubError.notFound
                    default:
                        throw GitHubError.networkError("HTTP \(httpResponse.statusCode)")
                    }
                }
                return data
            }
            .decode(type: GitHubComment.self, decoder: JSONDecoder.githubDecoder)
            .mapError { error in
                if let githubError = error as? GitHubError {
                    return githubError
                } else if error is DecodingError {
                    return GitHubError.decodingError
                } else {
                    return GitHubError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func createReview(owner: String, repo: String, pullNumber: Int, event: String, body: String?) -> AnyPublisher<GitHubReview, GitHubError> {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/pulls/\(pullNumber)/reviews")!
        
        var requestBody: [String: Any] = ["event": event]
        if let body = body, !body.isEmpty {
            requestBody["body"] = body
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        authHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200, 201:
                        return data
                    case 401:
                        throw GitHubError.unauthorized
                    case 403:
                        throw GitHubError.rateLimited
                    case 404:
                        throw GitHubError.notFound
                    default:
                        throw GitHubError.networkError("HTTP \(httpResponse.statusCode)")
                    }
                }
                return data
            }
            .decode(type: GitHubReview.self, decoder: JSONDecoder.githubDecoder)
            .mapError { error in
                if let githubError = error as? GitHubError {
                    return githubError
                } else if error is DecodingError {
                    return GitHubError.decodingError
                } else {
                    return GitHubError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
}