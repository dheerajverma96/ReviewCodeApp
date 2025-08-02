//
//  PRDetailView.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import SwiftUI

struct PRDetailView: View {
    @ObservedObject var viewModel: PRReviewViewModel
    let pr: PullRequest
    @State private var showingReviewSheet = false
    @State private var replyingTo: Comment?
    @State private var replyText = ""
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // PR Header
                PRHeaderView(pr: pr)
                
                Divider()
                
                // Reviews Summary Section
                if !pr.reviews.isEmpty {
                    reviewsSummarySection
                    Divider()
                }
                
                // Comments Section
                commentsSection
                
                // Comment Input (if allowed)
                if viewModel.canComment {
                    commentInputSection
                }
                
                // Lock Message (if locked)
                if pr.isLocked {
                    lockMessageView
                }
                
                // Review Actions (for reviewers only)
                if viewModel.canReviewPR {
                    reviewActionsSection
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("PR #\(pr.number)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectPR(pr)
        }
        .sheet(isPresented: $showingReviewSheet) {
            ReviewActionSheet(viewModel: viewModel)
        }
    }
    
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discussion")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(pr.comments.count) comments")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if pr.comments.isEmpty {
                emptyCommentsView
            } else {
                let threadedComments = buildCommentTree(from: pr.comments)
                ForEach(threadedComments, id: \.id) { comment in
                    CommentThreadView(
                        comment: comment,
                        allComments: pr.comments,
                        viewModel: viewModel,
                        replyingTo: $replyingTo,
                        replyText: $replyText
                    )
                }
            }
        }
    }
    
    private var emptyCommentsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No comments yet")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text("Be the first to leave a comment!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var commentInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let replyingComment = replyingTo {
                HStack {
                    Text("Replying to \(replyingComment.author.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        replyingTo = nil
                        replyText = ""
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            VStack(spacing: 8) {
                TextEditor(text: replyingTo != nil ? $replyText : $viewModel.newCommentText)
                    .frame(minHeight: 80)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                HStack {
                    Spacer()
                    
                    Button(replyingTo != nil ? "Reply" : "Comment") {
                        if let parentComment = replyingTo {
                            viewModel.addReply(to: parentComment, content: replyText)
                            replyingTo = nil
                            replyText = ""
                        } else {
                            viewModel.addComment()
                        }
                    }
                    .disabled((replyingTo != nil ? replyText : viewModel.newCommentText).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    private var lockMessageView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: pr.statusIcon)
                    .foregroundColor(pr.statusColor)
                    .font(.system(size: 20, weight: .medium))
                
                Text(lockMessageText)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text("No further comments are allowed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var lockMessageText: String {
        switch pr.status {
        case .merged:
            return "This PR has been merged"
        case .closed:
            return "This PR has been closed"
        case .approved:
            return "This PR has been approved"
        case .rejected:
            return "This PR has been rejected"
        default:
            return "This PR is locked"
        }
    }
    
    private var reviewActionsSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            Text("Review Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button("Submit Review") {
                showingReviewSheet = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
    }
    
    private var reviewsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📋 Reviews")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(pr.reviews.count) review\(pr.reviews.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140), spacing: 12)
            ], spacing: 12) {
                ForEach(pr.reviews, id: \.id) { review in
                    ReviewSummaryCardView(review: review)
                }
            }
        }
    }
    
    private func buildCommentTree(from comments: [Comment]) -> [Comment] {
        return comments.filter { $0.parentId == nil }
    }
}

struct PRHeaderView: View {
    let pr: PullRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status and PR number
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: pr.statusIcon)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(pr.status.displayName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: pr.status.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: pr.statusColor.opacity(0.4), radius: 4, x: 0, y: 2)
                
                Spacer()
                
                if pr.isLocked {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text("Locked")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
            }
            
            // Title
            Text(pr.title)
                .font(.title2)
                .fontWeight(.bold)
            
            // Description
            if !pr.description.isEmpty {
                Text(pr.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Metadata
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Author", systemImage: "person.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(pr.author.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(pr.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Branch", systemImage: "arrow.branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(pr.branchName) → \(pr.targetBranch)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                if !pr.assignedReviewers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Reviewers", systemImage: "person.2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("(\(pr.assignedReviewers.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 120), spacing: 8)
                        ], spacing: 8) {
                            ForEach(pr.assignedReviewers, id: \.id) { reviewer in
                                ReviewerDetailView(reviewer: reviewer, pr: pr)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ReviewActionSheet: View {
    @ObservedObject var viewModel: PRReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var reviewComment = ""
    @State private var selectedAction: ReviewAction?
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Submit Review")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comment (Optional)")
                        .font(.headline)
                    
                    TextEditor(text: $reviewComment)
                        .frame(minHeight: 100)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Review Decision")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ReviewActionButton(
                            title: "Approve",
                            subtitle: "Approve this pull request",
                            color: .green,
                            systemImage: "checkmark.circle"
                        ) {
                            selectedAction = .approve
                        }
                        
                        ReviewActionButton(
                            title: "Request Changes",
                            subtitle: "Submit feedback that must be addressed",
                            color: .orange,
                            systemImage: "exclamationmark.triangle"
                        ) {
                            selectedAction = .requestChanges
                        }
                        
                        ReviewActionButton(
                            title: "Reject",
                            subtitle: "Reject this pull request",
                            color: .red,
                            systemImage: "xmark.circle"
                        ) {
                            selectedAction = .reject
                        }
                    }
                }
                
                Spacer()
                
                Button("Submit Review") {
                    if let action = selectedAction {
                        if !reviewComment.isEmpty {
                            viewModel.newCommentText = reviewComment
                            viewModel.addComment()
                        }
                        viewModel.performReviewAction(action)
                        dismiss()
                    }
                }
                .disabled(selectedAction == nil)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReviewActionButton: View {
    let title: String
    let subtitle: String
    let color: Color
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct ReviewSummaryCardView: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Reviewer avatar
                Circle()
                    .fill(review.status.swiftUIColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(review.reviewer.name.prefix(1).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.reviewer.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon(for: review.status))
                            .font(.caption2)
                            .foregroundColor(review.status.swiftUIColor)
                        
                        Text(review.status.displayName)
                            .font(.caption)
                            .foregroundColor(review.status.swiftUIColor)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            
            // Review body if available
            if let body = review.body, !body.isEmpty {
                Text(body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Review submission date
            HStack {
                Text(review.submittedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(review.status.swiftUIColor.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
    
    private func statusIcon(for status: ReviewStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .changesRequested: return "exclamationmark.triangle.fill"
        case .merged: return "arrow.triangle.merge"
        case .closed: return "xmark.circle"
        }
    }
}

struct ReviewerDetailView: View {
    let reviewer: User
    let pr: PullRequest
    
    private var reviewStatus: ReviewStatus? {
        return pr.reviews.first { $0.reviewer.githubId == reviewer.githubId }?.status
    }
    
    private var hasReviewed: Bool {
        return pr.reviews.contains { $0.reviewer.githubId == reviewer.githubId }
    }
    
    private var review: Review? {
        return pr.reviews.first { $0.reviewer.githubId == reviewer.githubId }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Reviewer avatar
                Circle()
                    .fill(hasReviewed ? (reviewStatus?.swiftUIColor ?? .gray) : Color(.systemGray4))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(reviewer.name.prefix(1).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(reviewer.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if hasReviewed, let status = reviewStatus {
                        HStack(spacing: 4) {
                            Image(systemName: statusIcon(for: status))
                                .font(.caption2)
                                .foregroundColor(status.swiftUIColor)
                            
                            Text(status.displayName)
                                .font(.caption2)
                                .foregroundColor(status.swiftUIColor)
                                .fontWeight(.medium)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            
                            Text("Pending")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Review submission date
            if let review = review {
                HStack {
                    Text("Reviewed \(review.submittedAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hasReviewed ? (reviewStatus?.swiftUIColor.opacity(0.3) ?? Color.clear) : Color.clear, lineWidth: 1)
                )
        )
    }
    
    private func statusIcon(for status: ReviewStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .changesRequested: return "exclamationmark.triangle.fill"
        case .merged: return "arrow.triangle.merge"
        case .closed: return "xmark.circle"
        }
    }
}

#Preview {
    NavigationView {
        PRDetailView(
            viewModel: PRReviewViewModel(),
            pr: PullRequest(
                number: 123,
                title: "Sample PR",
                description: "This is a sample PR description",
                author: User(name: "Author", role: .prRaiser, githubId: 1),
                assignedReviewers: [
                    User(name: "John Doe", role: .reviewer, githubId: 2),
                    User(name: "Jane Smith", role: .reviewer, githubId: 3)
                ],
                createdAt: Date(),
                updatedAt: Date(),
                status: .pending,
                branchName: "feature-branch",
                targetBranch: "main"
            )
        )
    }
}
