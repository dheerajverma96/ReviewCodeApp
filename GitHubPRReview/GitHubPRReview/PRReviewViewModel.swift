//
//  PRReviewViewModel.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import Foundation
import Combine
import SwiftUICore

class PRReviewViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var pullRequests: [PullRequest] = []
    @Published var selectedPR: PullRequest?
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var newCommentText = ""
    @Published var selectedRepository: (owner: String, name: String) = (
        UserDefaults.standard.string(forKey: "github_owner") ?? "",
        UserDefaults.standard.string(forKey: "github_repo") ?? ""
    )
    
    private let repository = PRRepository()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        loadData()
    }
    
    private func setupBindings() {
        // Bind repository data to view model
        repository.$pullRequests
            .assign(to: &$pullRequests)
        
        repository.$isLoading
            .assign(to: &$isLoading)
        
        repository.$errorMessage
            .assign(to: &$errorMessage)
        
        repository.$currentUser
            .assign(to: &$currentUser)
    }
    
    private func loadData() {
        repository.loadCurrentUser()
    }
    
    // MARK: - Configuration Management
    func updateConfiguration(owner: String, repo: String, token: String) {
        selectedRepository = (owner: owner, name: repo)
        repository.updateConfiguration(owner: owner, repo: repo, token: token)
    }
    
    // MARK: - Tab Filtering
    //
    // Tab Structure:
    // - All PRs: Shows ALL PRs in repository (all statuses: pending, approved, rejected, merged, closed)
    // - My PRs: Shows only PRs created/authored by current user
    // - Need Review: Shows PRs where current user is assigned as reviewer but hasn't reviewed yet
    
    /// All PRs - Show all PRs in the repository regardless of user involvement
    var allPRs: [PullRequest] {
        print("🔍 Computing allPRs...")
        print("   - Total pullRequests: \(pullRequests.count)")
        print("   - Showing ALL PRs in repository (no user filtering)")
        
        // Show all PRs with all status types
        let result = pullRequests
        
        // Log status breakdown for visibility
        let statusCounts = Dictionary(grouping: result, by: { $0.status })
            .mapValues { $0.count }
        
        print("   - Status breakdown:")
        for status in ReviewStatus.allCases {
            let count = statusCounts[status] ?? 0
            print("     - \(status.displayNameWithEmoji): \(count)")
        }
        
        print("   - All PRs result: \(result.count)")
        return result
    }
    
    /// Assigned PRs - PRs created by current user
    var assignedPRs: [PullRequest] {
        print("🔍 Computing assignedPRs...")
        print("   - Total pullRequests: \(pullRequests.count)")
        
        guard let user = currentUser else { 
            print("❌ No current user for assignedPRs")
            return [] 
        }
        
        let result = pullRequests.filter { pr in
            pr.author.githubId == user.githubId
        }
        
        print("   - Assigned PRs result: \(result.count)")
        return result
    }
    
    /// Pending Review - PRs that need to be reviewed by current user
    var pendingPRs: [PullRequest] {
        print("🔍 Computing pendingPRs...")
        print("   - Total pullRequests: \(pullRequests.count)")
        
        guard let user = currentUser else { 
            print("❌ No current user for pendingPRs")
            return [] 
        }
        
        let result = pullRequests.filter { pr in
            // Must be assigned as reviewer
            let isAssignedReviewer = pr.assignedReviewers.contains { $0.githubId == user.githubId }
            
            // Must not have submitted a review yet
            let hasSubmittedReview = pr.reviews.contains { review in
                review.reviewer.githubId == user.githubId
            }
            
            return isAssignedReviewer && !hasSubmittedReview
        }
        
        print("   - Pending PRs result: \(result.count)")
        return result
    }
    
    // MARK: - Permission Checking
    
    var canReviewPR: Bool {
        guard let pr = selectedPR, let user = currentUser else { return false }
        
        // Must be assigned as reviewer
        let isAssignedReviewer = pr.assignedReviewers.contains { $0.githubId == user.githubId }
        
        // Must not have already reviewed
        let hasAlreadyReviewed = pr.reviews.contains { $0.reviewer.githubId == user.githubId }
        
        // PR must not be locked
        return isAssignedReviewer && !hasAlreadyReviewed && !pr.isLocked
    }
    
    var canOnlyComment: Bool {
        guard let pr = selectedPR, let user = currentUser else { return false }
        return pr.author.githubId == user.githubId && !pr.isLocked
    }
    
    var canComment: Bool {
        guard let pr = selectedPR, let user = currentUser else { return false }
        
        // Cannot comment if PR is locked (approved/rejected)
        if pr.isLocked {
            return false
        }
        
        // PR authors can comment
        if pr.author.githubId == user.githubId {
            return true
        }
        
        // Assigned reviewers can comment
        if pr.assignedReviewers.contains { $0.githubId == user.githubId } {
            return true
        }
        
        // Anyone who has submitted a review can comment
        if pr.reviews.contains { $0.reviewer.githubId == user.githubId } {
            return true
        }
        
        return false
    }
    
    // MARK: - Actions
    
    func selectPR(_ pr: PullRequest) {
        selectedPR = pr
    }
    
    func addComment() {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let selectedPR = selectedPR,
              let user = currentUser,
              canComment else {
            return
        }
        
        repository.addComment(
            to: selectedPR,
            content: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines),
            author: user
        )
        
        // Update selectedPR with the updated version
        if let updatedPR = pullRequests.first(where: { $0.id == selectedPR.id }) {
            self.selectedPR = updatedPR
        }
        
        newCommentText = ""
    }
    
    func addReply(to parentComment: Comment, content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let selectedPR = selectedPR,
              let user = currentUser,
              canComment else {
            return
        }
        
        // For now, treat replies as regular comments
        repository.addComment(
            to: selectedPR,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            author: user
        )
        
        // Update selectedPR with the updated version
        if let updatedPR = pullRequests.first(where: { $0.id == selectedPR.id }) {
            self.selectedPR = updatedPR
        }
    }
    
    func performReviewAction(_ action: ReviewAction) {
        guard canReviewPR,
              let selectedPR = selectedPR,
              let user = currentUser else {
            return
        }
        
        repository.submitReview(for: selectedPR, action: action, author: user)
        
        // Update selectedPR with the updated version
        if let updatedPR = pullRequests.first(where: { $0.id == selectedPR.id }) {
            self.selectedPR = updatedPR
        }
    }
    
    // MARK: - Repository Management
    
    func setRepository(owner: String, name: String) {
        let currentToken = UserDefaults.standard.string(forKey: "github_token") ?? ""
        updateConfiguration(owner: owner, repo: name, token: currentToken)
    }
    
    func refreshData() {
        repository.refreshData()
    }
    
    func clearError() {
        repository.clearError()
    }
}

// MARK: - Helper Extensions

extension PullRequest {
    var statusColor: Color {
        return status.swiftUIColor
    }
    
    var statusColorString: String {
        return status.color
    }
    
    var statusIcon: String {
        switch status {
        case .pending:
            return "clock"
        case .approved:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        case .changesRequested:
            return "exclamationmark.triangle.fill"
        case .merged:
            return "arrow.triangle.merge"
        case .closed:
            return "xmark.circle"
        }
    }
}
