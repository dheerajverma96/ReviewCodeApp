//
//  GitHubModels.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import Foundation

// MARK: - GitHub API Models

struct GitHubUser: Codable {
    let id: Int
    let login: String
    let avatarUrl: String?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case id, login, type
        case avatarUrl = "avatar_url"
    }
    
    func toAppUser(role: UserRole) -> User {
        return User(
            name: login,
            avatarURL: avatarUrl,
            role: role,
            githubId: id
        )
    }
}

struct GitHubRepository: Codable {
    let id: Int
    let name: String
    let fullName: String
    let `private`: Bool?
    let owner: GitHubUser
    let defaultBranch: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case fullName = "full_name"
        case `private` = "private"
        case defaultBranch = "default_branch"
    }
}

struct GitHubBranch: Codable {
    let label: String
    let ref: String
    let sha: String
    let user: GitHubUser?
    let repo: GitHubRepository?
}

struct GitHubPullRequest: Codable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let user: GitHubUser
    let state: String // "open", "closed"
    let createdAt: Date
    let updatedAt: Date
    let assignees: [GitHubUser]?
    let requestedReviewers: [GitHubUser]?
    let head: GitHubBranch
    let base: GitHubBranch
    let merged: Bool?
    let mergeable: Bool?
    let mergedAt: Date?
    let closedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, number, title, body, user, state, assignees, head, base, merged, mergeable
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case requestedReviewers = "requested_reviewers"
        case mergedAt = "merged_at"
        case closedAt = "closed_at"
    }
    
    var branchName: String {
        return head.ref
    }
    
    var targetBranch: String {
        return base.ref
    }
    
    var description: String {
        return body ?? ""
    }
    
    func determineStatus(from reviews: [GitHubReview]) -> ReviewStatus {
        // If PR is closed and merged, it's merged
        if state.lowercased() == "closed" && merged == true {
            return .merged
        }
        
        // If PR is closed but not merged, it's closed (could be rejected)
        if state.lowercased() == "closed" && merged != true {
            return .closed
        }
        
        // For open PRs, check review status
        if reviews.isEmpty {
            return .pending
        }
        
        let latestReviews = Dictionary(grouping: reviews) { $0.user.id }
            .compactMapValues { $0.max(by: { $0.submittedAt ?? Date.distantPast < $1.submittedAt ?? Date.distantPast }) }
            .values
        
        let hasApproval = latestReviews.contains { $0.state.lowercased() == "approved" }
        let hasRejection = latestReviews.contains { $0.state.lowercased() == "rejected" || $0.state.lowercased() == "dismissed" }
        let hasChangesRequested = latestReviews.contains { $0.state.lowercased() == "changes_requested" }
        
        if hasRejection {
            return .rejected
        } else if hasChangesRequested {
            return .changesRequested
        } else if hasApproval {
            return .approved
        } else {
            return .pending
        }
    }
    
    func toAppPullRequest(reviews: [GitHubReview] = [], comments: [Comment] = []) -> PullRequest {
        let status = determineStatus(from: reviews)
        
        // Use requested reviewers for assigned reviewers
        let reviewers = requestedReviewers ?? []
        
        // Convert GitHub reviews to app reviews
        let appReviews = reviews.compactMap { githubReview -> Review? in
            guard let submittedAt = githubReview.submittedAt else { return nil }
            return Review(
                reviewer: githubReview.user.toAppUser(role: .reviewer),
                status: githubReview.reviewStatus,
                body: githubReview.body,
                submittedAt: submittedAt
            )
        }
        
        // Determine if PR should be locked (closed PRs, merged PRs, or approved/rejected open PRs)
        let isLocked = state.lowercased() == "closed" || status == .merged || status == .closed || status == .approved || status == .rejected
        
        return PullRequest(
            number: number,
            title: title,
            description: description,
            author: user.toAppUser(role: .prRaiser),
            assignedReviewers: reviewers.map { $0.toAppUser(role: .reviewer) },
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status,
            reviews: appReviews,
            comments: comments,
            branchName: branchName,
            targetBranch: targetBranch,
            isLocked: isLocked
        )
    }
}

struct GitHubReview: Codable {
    let id: Int
    let user: GitHubUser
    let body: String?
    let state: String
    let submittedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, user, body, state
        case submittedAt = "submitted_at"
    }
    
    var reviewStatus: ReviewStatus {
        switch state.lowercased() {
        case "approved":
            return .approved
        case "rejected", "dismissed":
            return .rejected
        case "changes_requested":
            return .changesRequested
        default:
            return .pending
        }
    }
    
    func toAppComment() -> Comment? {
        guard let body = body, !body.isEmpty,
              let submittedAt = submittedAt else { return nil }
        
        return Comment(
            content: body,
            author: user.toAppUser(role: .reviewer),
            createdAt: submittedAt
        )
    }
}

struct GitHubComment: Codable {
    let id: Int
    let body: String
    let user: GitHubUser
    let createdAt: Date
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, body, user
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    func toAppComment() -> Comment {
        return Comment(
            content: body,
            author: user.toAppUser(role: .reviewer), // Default to reviewer, will be adjusted by context
            createdAt: createdAt
        )
    }
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    static let githubDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let isoFormatterWithoutFractions = ISO8601DateFormatter()
        isoFormatterWithoutFractions.formatOptions = [.withInternetDateTime]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            if let date = isoFormatterWithoutFractions.date(from: dateString) {
                return date
            }
            
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        
        return decoder
    }()
}
