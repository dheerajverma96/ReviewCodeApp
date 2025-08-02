//
//  Models.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import Foundation
import SwiftUI

// MARK: - User Management
enum UserRole: String, Codable {
    case reviewer = "reviewer"
    case prRaiser = "pr_raiser"
}

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let avatarURL: String?
    let role: UserRole
    let githubId: Int
    
    init(id: UUID = UUID(), name: String, avatarURL: String? = nil, role: UserRole, githubId: Int) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.role = role
        self.githubId = githubId
    }
}

// MARK: - Review Status
enum ReviewStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case changesRequested = "changes_requested"
    case merged = "merged"
    case closed = "closed"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .changesRequested: return "Changes Requested"
        case .merged: return "Merged"
        case .closed: return "Closed"
        }
    }
    
    var displayNameWithEmoji: String {
        switch self {
        case .pending: return "⏳ Pending"
        case .approved: return "✅ Approved"
        case .rejected: return "❌ Rejected"
        case .changesRequested: return "🔄 Changes Requested"
        case .merged: return "🎉 Merged"
        case .closed: return "🔒 Closed"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "systemOrange"
        case .approved: return "systemGreen"
        case .rejected: return "systemRed"
        case .changesRequested: return "systemYellow"
        case .merged: return "systemPurple"
        case .closed: return "systemGray"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .changesRequested: return .yellow
        case .merged: return .purple
        case .closed: return .gray
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .pending: return [.orange, .orange.opacity(0.7)]
        case .approved: return [.green, .mint]
        case .rejected: return [.red, .pink.opacity(0.8)]
        case .changesRequested: return [.yellow, .orange.opacity(0.6)]
        case .merged: return [.purple, .indigo.opacity(0.8)]
        case .closed: return [.gray, .secondary.opacity(0.6)]
        }
    }
}

// MARK: - Review Model
struct Review: Identifiable, Codable {
    let id: UUID
    let reviewer: User
    let status: ReviewStatus
    let body: String?
    let submittedAt: Date
    
    init(id: UUID = UUID(), reviewer: User, status: ReviewStatus, body: String? = nil, submittedAt: Date) {
        self.id = id
        self.reviewer = reviewer
        self.status = status
        self.body = body
        self.submittedAt = submittedAt
    }
}

// MARK: - Comment Model
struct Comment: Identifiable, Codable {
    let id: UUID
    let content: String
    let author: User
    let createdAt: Date
    let parentId: UUID?
    var replies: [Comment]
    
    init(id: UUID = UUID(), content: String, author: User, createdAt: Date, parentId: UUID? = nil, replies: [Comment] = []) {
        self.id = id
        self.content = content
        self.author = author
        self.createdAt = createdAt
        self.parentId = parentId
        self.replies = replies
    }
}

// MARK: - Pull Request Model
struct PullRequest: Identifiable, Codable {
    let id: UUID
    let number: Int
    let title: String
    let description: String
    let author: User
    let assignedReviewers: [User]
    let createdAt: Date
    let updatedAt: Date
    var status: ReviewStatus
    var reviews: [Review]
    var comments: [Comment]
    let branchName: String
    let targetBranch: String
    let isLocked: Bool // True if approved/rejected and comments are blocked
    
    init(id: UUID = UUID(),
         number: Int,
         title: String,
         description: String,
         author: User,
         assignedReviewers: [User],
         createdAt: Date,
         updatedAt: Date,
         status: ReviewStatus,
         reviews: [Review] = [],
         comments: [Comment] = [],
         branchName: String,
         targetBranch: String,
         isLocked: Bool = false) {
        self.id = id
        self.number = number
        self.title = title
        self.description = description
        self.author = author
        self.assignedReviewers = assignedReviewers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.reviews = reviews
        self.comments = comments
        self.branchName = branchName
        self.targetBranch = targetBranch
        self.isLocked = isLocked
    }
    
    var lastActivity: Date {
        let lastCommentDate = comments.map(\.createdAt).max()
        let lastReviewDate = reviews.map(\.submittedAt).max()
        return [updatedAt, lastCommentDate, lastReviewDate].compactMap { $0 }.max() ?? updatedAt
    }
    
    var hasUserReviewed: Bool {
        return !reviews.isEmpty
    }
}

// MARK: - Review Action
enum ReviewAction {
    case approve
    case reject
    case requestChanges
    case comment(String)
}

// MARK: - Tab Filter Mode
enum PRFilterMode: String, CaseIterable {
    case all = "all"
    case assigned = "assigned" 
    case pending = "pending"
    
    var displayName: String {
        switch self {
        case .all: return "All PRs"
        case .assigned: return "My PRs"
        case .pending: return "Need Review"
        }
    }
}