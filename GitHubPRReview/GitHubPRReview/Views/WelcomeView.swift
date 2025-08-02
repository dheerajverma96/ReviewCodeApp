//
//  WelcomeView.swift
//  GitHubPRReview
//
//  Created by Dheeraj Verma on 02/08/25.
//

import SwiftUI
import UIKit

// GitHub Color Palette
extension Color {
    static let gitHubBlue = Color(red: 0.04, green: 0.42, blue: 0.85)
    static let gitHubDark = Color(red: 0.14, green: 0.16, blue: 0.18)
    static let gitHubDarker = Color(red: 0.09, green: 0.11, blue: 0.13)
    static let gitHubPurple = Color(red: 0.51, green: 0.31, blue: 0.87)
}

struct WelcomeView: View {
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showFeatures = false
    @State private var showButton = false
    @State private var logoRotation = 0.0
    @State private var backgroundGradient = false
    @State private var autoAdvanceProgress: CGFloat = 0.0
    
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            // GitHub-themed Background Gradient
            LinearGradient(
                colors: backgroundGradient ? 
                    [Color.gitHubDark, Color.gitHubBlue, Color.gitHubPurple] :
                    [Color.gitHubDarker, Color.gitHubBlue.opacity(0.8), Color.gitHubPurple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: backgroundGradient)
            
            // Floating particles background
            ParticleField()
            
            VStack(spacing: 30) {
                Spacer()
                
                // App Logo with Animation
                VStack(spacing: 20) {
                    ZStack {
                        // Pulsing circle background
                        Circle()
                            .fill(Color.gitHubBlue.opacity(0.3))
                            .frame(width: showLogo ? 140 : 0, height: showLogo ? 140 : 0)
                            .scaleEffect(showLogo ? 1.0 : 0.1)
                            .animation(.spring(response: 1.0, dampingFraction: 0.6, blendDuration: 0), value: showLogo)
                        
                        // GitHub-style logo icon
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: showLogo ? 60 : 0, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(logoRotation))
                            .scaleEffect(showLogo ? 1.0 : 0.1)
                            .animation(.spring(response: 1.2, dampingFraction: 0.5, blendDuration: 0), value: showLogo)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                                    logoRotation = 360
                                }
                            }
                    }
                    
                    // App Title
                    VStack(spacing: 8) {
                        Text("GitHub PR Review")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 50)
                            .animation(.easeOut(duration: 0.8).delay(0.5), value: showTitle)
                        
                        Text("Streamlined Code Review Experience")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                            .opacity(showSubtitle ? 1 : 0)
                            .offset(y: showSubtitle ? 0 : 30)
                            .animation(.easeOut(duration: 0.8).delay(1.0), value: showSubtitle)
                    }
                }
                
                Spacer()
                
                // Feature highlights with staggered animation
                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "list.bullet",
                        title: "Smart Filtering",
                        description: "All PRs, My PRs, Need Review",
                        delay: 0.0,
                        show: showFeatures
                    )
                    
                    FeatureRow(
                        icon: "bubble.left.and.bubble.right",
                        title: "Threaded Comments",
                        description: "Organized discussions",
                        delay: 0.2,
                        show: showFeatures
                    )
                    
                    FeatureRow(
                        icon: "checkmark.seal",
                        title: "Review Actions",
                        description: "Approve, Reject, Request Changes",
                        delay: 0.4,
                        show: showFeatures
                    )
                    
                    FeatureRow(
                        icon: "lock.shield",
                        title: "Smart Locking",
                        description: "Secure after approval/rejection",
                        delay: 0.6,
                        show: showFeatures
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Continue Button with Animation
                Button(action: {
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        onContinue()
                    }
                }) {
                    HStack(spacing: 12) {
                        Text("Start Reviewing")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.gitHubBlue)
                            .shadow(color: Color.gitHubBlue.opacity(0.4), radius: 10, x: 0, y: 4)
                    )
                }
                .scaleEffect(showButton ? 1.0 : 0.1)
                .opacity(showButton ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(2.0), value: showButton)
                .onTapGesture {
                    // Additional button press animation
                    withAnimation(.easeInOut(duration: 0.1)) {
                        // Scale down briefly on tap
                    }
                }
                
                Spacer()
                
                // Auto-advance progress indicator
                VStack(spacing: 8) {
                    if showButton {
                        Text("Auto-advancing in...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gitHubBlue)
                                    .frame(width: geometry.size.width * autoAdvanceProgress, height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 60)
                    }
                }
                .opacity(showButton ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showButton)
                
                Spacer(minLength: 30)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Start background animation
        backgroundGradient = true
        
        // Trigger animations in sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showLogo = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showTitle = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showSubtitle = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showFeatures = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showButton = true
            
            // Start progress bar animation after button appears
            withAnimation(.linear(duration: 0.5)) {
                autoAdvanceProgress = 1.0
            }
        }
        
        // Auto-advance after 3 seconds total
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if showButton {
                onContinue()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let delay: Double
    let show: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon container with GitHub colors
            ZStack {
                Circle()
                    .fill(Color.gitHubBlue.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.gitHubBlue)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.85))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .blur(radius: 0.5)
        )
        .opacity(show ? 1 : 0)
        .offset(x: show ? 0 : -100)
        .animation(.easeOut(duration: 0.6).delay(delay), value: show)
    }
}

struct ParticleField: View {
    @State private var animate = false
    @State private var particlePositions: [(x: CGFloat, y: CGFloat)] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<15, id: \.self) { index in
                    Circle()
                        .fill(Color.gitHubBlue.opacity(Double.random(in: 0.1...0.3)))
                        .frame(width: CGFloat.random(in: 4...12))
                        .position(
                            x: animate ? 
                                CGFloat.random(in: 0...geometry.size.width) : 
                                CGFloat.random(in: 0...geometry.size.width),
                            y: animate ? 
                                CGFloat.random(in: 0...geometry.size.height) : 
                                CGFloat.random(in: 0...geometry.size.height)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 5...12))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...2)),
                            value: animate
                        )
                        .blur(radius: CGFloat.random(in: 0...1))
                }
                
                // Add GitHub-style code symbols
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: ["chevron.left.forwardslash.chevron.right", "curlybraces", "angle.left.angle.right"].randomElement() ?? "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: CGFloat.random(in: 12...20), weight: .light))
                        .foregroundColor(Color.gitHubBlue.opacity(Double.random(in: 0.15...0.35)))
                        .position(
                            x: animate ? 
                                CGFloat.random(in: 50...geometry.size.width-50) : 
                                CGFloat.random(in: 50...geometry.size.width-50),
                            y: animate ? 
                                CGFloat.random(in: 100...geometry.size.height-100) : 
                                CGFloat.random(in: 100...geometry.size.height-100)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 8...15))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...3)),
                            value: animate
                        )
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animate = true
            }
        }
    }
}

#Preview {
    WelcomeView {
        print("Continue tapped")
    }
}