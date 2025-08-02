//
//  PRRepository.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import Foundation
import Combine

class PRRepository: ObservableObject {
    @Published var pullRequests: [PullRequest] = []
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let gitHubService = GitHubService()
    private var cancellables = Set<AnyCancellable>()
    
    // Repository configuration - loaded from UserDefaults only
    private var currentOwner: String {
        return UserDefaults.standard.string(forKey: "github_owner") ?? ""
    }
    
    private var currentRepo: String {
        return UserDefaults.standard.string(forKey: "github_repo") ?? ""
    }
    
    private var currentToken: String {
        return UserDefaults.standard.string(forKey: "github_token") ?? ""
    }
    
    private var hasValidConfiguration: Bool {
        return !currentOwner.isEmpty && !currentRepo.isEmpty && !currentToken.isEmpty && currentToken.hasPrefix("ghp_")
    }
    
    init() {
        updateGitHubServiceToken()
        loadCurrentUser()
    }
    
    // MARK: - Configuration Management
    
    func updateConfiguration(owner: String, repo: String, token: String) {
        print("🔧 Updating repository configuration:")
        print("   - Owner: \(owner)")
        print("   - Repo: \(repo)")
        print("   - Token: \(token.prefix(7))***")
        
        // Save to UserDefaults
        UserDefaults.standard.set(owner, forKey: "github_owner")
        UserDefaults.standard.set(repo, forKey: "github_repo")
        UserDefaults.standard.set(token, forKey: "github_token")
        
        // Update GitHub service with new token
        updateGitHubServiceToken()
        
        // Reload data with new configuration
        loadCurrentUser()
    }
    
    private func updateGitHubServiceToken() {
        gitHubService.updateToken(currentToken)
    }
    
    // MARK: - User Management
    
    func loadCurrentUser() {
        print("🔍 Loading current user...")
        print("   - Owner: '\(currentOwner)'")
        print("   - Repo: '\(currentRepo)'")
        print("   - Using token: \(gitHubService.getTokenPreview())")
        
        guard hasValidConfiguration else {
            print("⚠️ No valid configuration found. User needs to set owner, repo, and token in Settings.")
            isLoading = false
            errorMessage = "Configuration required. Please set repository owner, name, and GitHub token in Settings."
            return
        }
        
        isLoading = true
        
        gitHubService.testConnection()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    print("🏁 User loading completion called")
                    if case .failure(let error) = completion {
                        print("❌ Failed to load current user: \(error)")
                        print("   Error type: \(type(of: error))")
                        print("   Error description: \(error.localizedDescription)")
                        self?.isLoading = false
                        self?.errorMessage = error.localizedDescription
                        
                        // Don't load PRs if user auth failed
                        return
                    } else {
                        print("✅ User loading completed successfully")
                    }
                },
                receiveValue: { [weak self] githubUser in
                    print("✅ Loaded current user: \(githubUser.login) (ID: \(githubUser.id))")
                    // Determine user role based on repository context
                    let userRole: UserRole = .reviewer // Default to reviewer for now
                    self?.currentUser = githubUser.toAppUser(role: userRole)
                    
                    // Now load PRs after user is set
                    print("👤 Current user set, now loading PRs...")
                    self?.loadPullRequests()
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Pull Request Management
    
    func loadPullRequests(owner: String? = nil, repo: String? = nil) {
        let repoOwner = owner ?? currentOwner
        let repoName = repo ?? currentRepo
        
        print("🔄 Loading PRs from \(repoOwner)/\(repoName)...")
        print("   - Current PR count: \(pullRequests.count)")
        print("   - Current user: \(currentUser?.name ?? "nil")")
        print("   - Is loading: \(isLoading)")
        
        guard !repoOwner.isEmpty && !repoName.isEmpty else {
            print("⚠️ Cannot load PRs: Owner or repo is empty")
            isLoading = false
            errorMessage = "Configuration required. Please set repository owner and name in Settings."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        gitHubService.fetchPullRequests(owner: repoOwner, repo: repoName)
            .flatMap { [weak self] githubPRs -> AnyPublisher<[PullRequest], GitHubError> in
                guard let self = self else {
                    print("❌ Repository deallocated during PR fetch")
                    return Fail(error: GitHubError.networkError("Repository deallocated")).eraseToAnyPublisher()
                }
                
                print("📋 Processing \(githubPRs.count) PRs from GitHub API...")
                
                if githubPRs.isEmpty {
                    print("⚠️ No PRs returned from GitHub API")
                    return Just([]).setFailureType(to: GitHubError.self).eraseToAnyPublisher()
                }
                
                // Log first few PRs for debugging
                for (index, pr) in githubPRs.prefix(3).enumerated() {
                    print("  \(index + 1). PR #\(pr.number): \(pr.title)")
                    print("     State: \(pr.state), Merged: \(pr.merged ?? false)")
                    print("     Author: \(pr.user.login)")
                    print("     Requested Reviewers: \(pr.requestedReviewers?.count ?? 0)")
                }
                
                // Fetch details for each PR
                let prPublishers = githubPRs.map { githubPR in
                    self.fetchPRDetails(owner: repoOwner, repo: repoName, githubPR: githubPR)
                }
                
                return Publishers.MergeMany(prPublishers)
                    .collect()
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    print("🏁 PR loading completion called")
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ Failed to load PRs: \(error)")
                        print("   Error type: \(type(of: error))")
                        print("   Error description: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    } else {
                        print("✅ PR loading completed successfully")
                    }
                },
                receiveValue: { [weak self] prs in
                    print("📥 Received \(prs.count) processed PRs")
                    for (index, pr) in prs.prefix(3).enumerated() {
                        print("  \(index + 1). \(pr.title) - Status: \(pr.status.displayName)")
                    }
                    
                    self?.pullRequests = prs
                    print("📊 Set pullRequests array to \(prs.count) items")
                    print("📊 Current pullRequests count: \(self?.pullRequests.count ?? -1)")
                    
                    self?.adjustUserRoles()
                    print("🔧 User roles adjusted")
                }
            )
            .store(in: &cancellables)
    }
    
    private func fetchPRDetails(owner: String, repo: String, githubPR: GitHubPullRequest) -> AnyPublisher<PullRequest, GitHubError> {
        let reviewsPublisher = gitHubService.fetchPullRequestReviews(owner: owner, repo: repo, pullNumber: githubPR.number)
        let commentsPublisher = gitHubService.fetchIssueComments(owner: owner, repo: repo, issueNumber: githubPR.number)
        
        return Publishers.Zip(reviewsPublisher, commentsPublisher)
            .map { (reviews, comments) -> PullRequest in
                let appComments = comments.map { $0.toAppComment() }
                let reviewComments = reviews.compactMap { $0.toAppComment() }
                let allComments = appComments + reviewComments
                
                return githubPR.toAppPullRequest(reviews: reviews, comments: allComments)
            }
            .catch { error -> AnyPublisher<PullRequest, GitHubError> in
                print("⚠️ Using fallback for PR #\(githubPR.number) due to error: \(error)")
                let basicPR = githubPR.toAppPullRequest(reviews: [], comments: [])
                return Just(basicPR).setFailureType(to: GitHubError.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    private func adjustUserRoles() {
        guard let currentUser = currentUser else { return }
        
        // Update user roles based on PR authorship
        for i in 0..<pullRequests.count {
            // Adjust author role
            if pullRequests[i].author.githubId == currentUser.githubId {
                pullRequests[i] = PullRequest(
                    id: pullRequests[i].id,
                    number: pullRequests[i].number,
                    title: pullRequests[i].title,
                    description: pullRequests[i].description,
                    author: User(
                        id: pullRequests[i].author.id,
                        name: pullRequests[i].author.name,
                        avatarURL: pullRequests[i].author.avatarURL,
                        role: .prRaiser,
                        githubId: pullRequests[i].author.githubId
                    ),
                    assignedReviewers: pullRequests[i].assignedReviewers,
                    createdAt: pullRequests[i].createdAt,
                    updatedAt: pullRequests[i].updatedAt,
                    status: pullRequests[i].status,
                    reviews: pullRequests[i].reviews,
                    comments: pullRequests[i].comments,
                    branchName: pullRequests[i].branchName,
                    targetBranch: pullRequests[i].targetBranch,
                    isLocked: pullRequests[i].isLocked
                )
            }
        }
    }
    
    // MARK: - Comment Management
    
    func addComment(to pullRequest: PullRequest, content: String, author: User) {
        // Check if PR is locked
        if pullRequest.isLocked {
            print("❌ Cannot comment on locked PR (approved/rejected)")
            errorMessage = "Cannot comment on this PR - it has been approved or rejected"
            return
        }
        
        print("💬 Adding comment to PR #\(pullRequest.number)")
        
        // Add comment locally first for immediate UI update
        let comment = Comment(
            content: content,
            author: author,
            createdAt: Date()
        )
        
        if let index = pullRequests.firstIndex(where: { $0.id == pullRequest.id }) {
            pullRequests[index].comments.append(comment)
        }
        
        // Call GitHub API
        gitHubService.createComment(
            owner: currentOwner,
            repo: currentRepo,
            issueNumber: pullRequest.number,
            body: content
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to create comment: \(error)")
                    // TODO: Remove optimistic comment update on failure
                }
            },
            receiveValue: { _ in
                print("✅ Comment created successfully")
            }
        )
        .store(in: &cancellables)
    }
    
    func submitReview(for pullRequest: PullRequest, action: ReviewAction, author: User) {
        print("📝 Submitting review for PR #\(pullRequest.number): \(action)")
        
        guard let index = pullRequests.firstIndex(where: { $0.id == pullRequest.id }) else {
            print("❌ Could not find PR")
            return
        }
        
        // Determine GitHub review event
        let (event, body): (String, String?) = {
            switch action {
            case .approve:
                return ("APPROVE", nil)
            case .reject:
                return ("REQUEST_CHANGES", "This PR has been rejected.")
            case .requestChanges:
                return ("REQUEST_CHANGES", nil)
            case .comment(let text):
                return ("COMMENT", text)
            }
        }()
        
        // Update local state immediately
        let review = Review(
            reviewer: author,
            status: {
                switch action {
                case .approve: return .approved
                case .reject: return .rejected
                case .requestChanges: return .changesRequested
                case .comment: return .pending
                }
            }(),
            body: body,
            submittedAt: Date()
        )
        
        pullRequests[index].reviews.append(review)
        
        // Update PR status and lock state for approve/reject
        switch action {
        case .approve:
            pullRequests[index].status = .approved
            pullRequests[index] = PullRequest(
                id: pullRequests[index].id,
                number: pullRequests[index].number,
                title: pullRequests[index].title,
                description: pullRequests[index].description,
                author: pullRequests[index].author,
                assignedReviewers: pullRequests[index].assignedReviewers,
                createdAt: pullRequests[index].createdAt,
                updatedAt: pullRequests[index].updatedAt,
                status: .approved,
                reviews: pullRequests[index].reviews,
                comments: pullRequests[index].comments,
                branchName: pullRequests[index].branchName,
                targetBranch: pullRequests[index].targetBranch,
                isLocked: true // Lock after approval
            )
        case .reject:
            pullRequests[index].status = .rejected
            pullRequests[index] = PullRequest(
                id: pullRequests[index].id,
                number: pullRequests[index].number,
                title: pullRequests[index].title,
                description: pullRequests[index].description,
                author: pullRequests[index].author,
                assignedReviewers: pullRequests[index].assignedReviewers,
                createdAt: pullRequests[index].createdAt,
                updatedAt: pullRequests[index].updatedAt,
                status: .rejected,
                reviews: pullRequests[index].reviews,
                comments: pullRequests[index].comments,
                branchName: pullRequests[index].branchName,
                targetBranch: pullRequests[index].targetBranch,
                isLocked: true // Lock after rejection
            )
        case .requestChanges:
            pullRequests[index].status = .changesRequested
        case .comment:
            // Comments don't change status
            break
        }
        
        // Call GitHub API
        gitHubService.createReview(
            owner: currentOwner,
            repo: currentRepo,
            pullNumber: pullRequest.number,
            event: event,
            body: body
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to submit review: \(error)")
                    // TODO: Revert optimistic update on failure
                }
            },
            receiveValue: { _ in
                print("✅ Review submitted successfully")
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - Repository Management
    
    func setRepository(owner: String, name: String) {
        let currentToken = UserDefaults.standard.string(forKey: "github_token") ?? ""
        updateConfiguration(owner: owner, repo: name, token: currentToken)
    }
    
    func refreshData() {
        loadPullRequests()
    }
    
    func clearError() {
        errorMessage = nil
    }
}