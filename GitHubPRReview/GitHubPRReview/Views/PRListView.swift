//
//  PRListView.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import SwiftUI

struct PRListView: View {
    @ObservedObject var viewModel: PRReviewViewModel
    @State private var filterMode: PRFilterMode = .all
    @State private var showingStatusFilter = false
    @State private var selectedStatusFilter: Set<ReviewStatus> = Set(ReviewStatus.allCases)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Filter", selection: $filterMode) {
                    ForEach(PRFilterMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // PR List
                if viewModel.isLoading {
                    loadingView
                } else if filteredPRs.isEmpty {
                    emptyStateView
                } else {
                    prListContent
                }
            }
            .navigationTitle("Pull Requests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filter") {
                        showingStatusFilter = true
                    }
                }
            }
            .refreshable {
                viewModel.refreshData()
            }
            .sheet(isPresented: $showingStatusFilter) {
                StatusFilterView(selectedStatuses: $selectedStatusFilter)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    private var filteredPRs: [PullRequest] {
        print("🎯 Computing filteredPRs for \(filterMode.displayName)...")
        
        let baseFilteredPRs: [PullRequest]
        switch filterMode {
        case .all:
            baseFilteredPRs = viewModel.allPRs
        case .assigned:
            baseFilteredPRs = viewModel.assignedPRs
        case .pending:
            baseFilteredPRs = viewModel.pendingPRs
        }
        
        print("   - Base filtered PRs: \(baseFilteredPRs.count)")
        print("   - Selected status filters: \(selectedStatusFilter.map { $0.displayName })")
        
        // Apply status filter
        let result = baseFilteredPRs.filter { selectedStatusFilter.contains($0.status) }
        
        print("   - Final filtered PRs: \(result.count)")
        
        if result.isEmpty {
            print("⚠️ No PRs after filtering!")
            print("   - Base PRs: \(baseFilteredPRs.count)")
            print("   - Status filters: \(selectedStatusFilter.count)/\(ReviewStatus.allCases.count)")
            print("   - ViewModel PRs: \(viewModel.pullRequests.count)")
            print("   - Is loading: \(viewModel.isLoading)")
            print("   - Error message: \(viewModel.errorMessage ?? "none")")
        }
        
        return result
    }
    
    private var prListContent: some View {
        List(filteredPRs, id: \.id) { pr in
            NavigationLink(destination: PRDetailView(viewModel: viewModel, pr: pr)) {
                PRRowView(pr: pr)
            }
        }
        .listStyle(.plain)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading Pull Requests...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateIcon: String {
        switch filterMode {
        case .all:
            return "doc.text"
        case .assigned:
            return "person.crop.circle"
        case .pending:
            return "clock"
        }
    }
    
    private var emptyStateTitle: String {
        switch filterMode {
        case .all:
            return "📂 No Pull Requests"
        case .assigned:
            return "👤 No Created PRs"
        case .pending:
            return "⏰ No Reviews Needed"
        }
    }
    
    private var emptyStateMessage: String {
        switch filterMode {
        case .all:
            return "No pull requests found in \(viewModel.selectedRepository.owner)/\(viewModel.selectedRepository.name).\n\nThis tab shows ALL pull requests in the repository with all status types:\n• ⏳ Pending\n• ✅ Approved\n• ❌ Rejected\n• 🔄 Changes Requested\n• 🎉 Merged\n• 🔒 Closed"
        case .assigned:
            return "You haven't created any pull requests in \(viewModel.selectedRepository.owner)/\(viewModel.selectedRepository.name).\n\nThis tab shows only PRs that you have authored/created."
        case .pending:
            return "No pull requests need your review in \(viewModel.selectedRepository.owner)/\(viewModel.selectedRepository.name).\n\nThis tab shows PRs where you're assigned as a reviewer but haven't submitted a review yet."
        }
    }
}

struct PRRowView: View {
    let pr: PullRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with PR number and status
            HStack {
                Text("#\(pr.number)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: pr.statusIcon)
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
                    
                    Text(pr.status.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: pr.status.gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: pr.statusColor.opacity(0.3), radius: 2, x: 0, y: 1)
                
                if pr.isLocked {
                    HStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("🔒")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
                }
            }
            
            // Title
            Text(pr.title)
                .font(.headline)
                .lineLimit(2)
            
            // Author and metadata
            HStack {
                Label(pr.author.name, systemImage: "person.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    if !pr.comments.isEmpty {
                        Label("\(pr.comments.count)", systemImage: "bubble.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !pr.reviews.isEmpty {
                        Label("\(pr.reviews.count)", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !pr.assignedReviewers.isEmpty {
                        Label("\(pr.assignedReviewers.count)", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Reviewers section
            if !pr.assignedReviewers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("👥 Reviewers:")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(pr.assignedReviewers, id: \.id) { reviewer in
                                ReviewerBadgeView(reviewer: reviewer, pr: pr)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            
            // Branch info
            HStack {
                Label("\(pr.branchName) → \(pr.targetBranch)", systemImage: "arrow.branch")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(pr.lastActivity, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusFilterView: View {
    @Binding var selectedStatuses: Set<ReviewStatus>
    @Environment(\.dismiss) private var dismiss
    
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
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Filter by Status")) {
                    ForEach(ReviewStatus.allCases, id: \.self) { status in
                        HStack {
                            Button(action: {
                                if selectedStatuses.contains(status) {
                                    selectedStatuses.remove(status)
                                } else {
                                    selectedStatuses.insert(status)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedStatuses.contains(status) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedStatuses.contains(status) ? .blue : .secondary)
                                    
                                    HStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            Image(systemName: statusIcon(for: status))
                                                .foregroundColor(.white)
                                                .font(.system(size: 12, weight: .bold))
                                            
                                            Text(status.displayNameWithEmoji)
                                                .foregroundColor(.white)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            LinearGradient(
                                                colors: status.gradientColors,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(8)
                                        .shadow(color: status.swiftUIColor.opacity(0.3), radius: 1, x: 0, y: 1)
                                        
                                        Spacer()
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section {
                    Button("Select All") {
                        selectedStatuses = Set(ReviewStatus.allCases)
                    }
                    
                    Button("Clear All") {
                        selectedStatuses.removeAll()
                    }
                }
            }
            .navigationTitle("Filter PRs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReviewerBadgeView: View {
    let reviewer: User
    let pr: PullRequest
    
    private var reviewStatus: ReviewStatus? {
        return pr.reviews.first { $0.reviewer.githubId == reviewer.githubId }?.status
    }
    
    private var hasReviewed: Bool {
        return pr.reviews.contains { $0.reviewer.githubId == reviewer.githubId }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Reviewer avatar/initial
            Circle()
                .fill(hasReviewed ? (reviewStatus?.swiftUIColor ?? .gray) : Color(.systemGray4))
                .frame(width: 20, height: 20)
                .overlay(
                    Text(reviewer.name.prefix(1).uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            Text(reviewer.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // Review status indicator
            if hasReviewed, let status = reviewStatus {
                Image(systemName: statusIcon(for: status))
                    .font(.caption2)
                    .foregroundColor(status.swiftUIColor)
            } else {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
    PRListView(viewModel: PRReviewViewModel())
}
