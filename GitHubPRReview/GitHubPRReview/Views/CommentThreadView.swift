//
//  CommentThreadView.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import SwiftUI

struct CommentThreadView: View {
    let comment: Comment
    let allComments: [Comment]
    @ObservedObject var viewModel: PRReviewViewModel
    @Binding var replyingTo: Comment?
    @Binding var replyText: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main comment
            CommentView(
                comment: comment,
                viewModel: viewModel,
                replyingTo: $replyingTo,
                replyText: $replyText,
                depth: 0
            )
            
            // Replies
            let replies = getReplies(for: comment)
            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(replies, id: \.id) { reply in
                        CommentThreadView(
                            comment: reply,
                            allComments: allComments,
                            viewModel: viewModel,
                            replyingTo: $replyingTo,
                            replyText: $replyText
                        )
                        .padding(.leading, 20) // Indent replies
                    }
                }
            }
        }
    }
    
    private func getReplies(for comment: Comment) -> [Comment] {
        return allComments.filter { $0.parentId == comment.id }
    }
}

struct CommentView: View {
    let comment: Comment
    @ObservedObject var viewModel: PRReviewViewModel
    @Binding var replyingTo: Comment?
    @Binding var replyText: String
    let depth: Int
    
    private var canReply: Bool {
        guard let selectedPR = viewModel.selectedPR else { return false }
        return viewModel.canComment && !selectedPR.isLocked
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Comment content
            VStack(alignment: .leading, spacing: 8) {
                // Author and timestamp
                HStack {
                    // Author avatar placeholder
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(comment.author.name.prefix(1).uppercased())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        )
                    
                    Text(comment.author.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Role indicator
                    if comment.author.role == .prRaiser {
                        Text("Author")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    } else if comment.author.role == .reviewer {
                        Text("Reviewer")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(comment.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Comment text
                Text(comment.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Action buttons
                if canReply {
                    HStack {
                        Button("Reply") {
                            replyingTo = comment
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(depth > 0 ? Color(.systemGray4) : Color.clear, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleComments = [
        Comment(
            content: "This looks great! Just a few minor suggestions.",
            author: User(name: "Reviewer1", role: .reviewer, githubId: 1),
            createdAt: Date().addingTimeInterval(-3600)
        ),
        Comment(
            content: "Thanks for the feedback! I'll address those points.",
            author: User(name: "Author", role: .prRaiser, githubId: 2),
            createdAt: Date().addingTimeInterval(-1800),
            parentId: UUID() // Would be the first comment's ID
        )
    ]
    
    VStack {
        CommentThreadView(
            comment: sampleComments[0],
            allComments: sampleComments,
            viewModel: PRReviewViewModel(),
            replyingTo: .constant(nil),
            replyText: .constant("")
        )
        .padding()
        
        Spacer()
    }
}