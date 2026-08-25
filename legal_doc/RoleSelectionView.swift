//
//  RoleSelectionView.swift
//  legal_doc
//
//  Role selection screen for choosing between Client and Lawyer
//

import SwiftUI

enum UserRole: String {
    case client = "Client"
    case lawyer = "Lawyer"
}

struct RoleSelectionView: View {
    @State private var selectedRole: UserRole?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // App Logo/Title
                VStack(spacing: 10) {
                    LogoView(size: 120)
                    Text("Pocket Lawyer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Choose your role to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 50)
                
                // Role Selection Cards
                VStack(spacing: 20) {
                    RoleCard(
                        title: "Client",
                        icon: "person.fill",
                        description: "Submit legal queries and get AI-powered responses",
                        color: .blue
                    ) {
                        selectedRole = .client
                    }
                    
                    RoleCard(
                        title: "Lawyer",
                        icon: "briefcase.fill",
                        description: "Review queries and provide professional responses",
                        color: .purple
                    ) {
                        selectedRole = .lawyer
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .background(
                NavigationLink(
                    destination: destinationView,
                    isActive: Binding(
                        get: { selectedRole != nil },
                        set: { if !$0 { selectedRole = nil } }
                    )
                ) {
                    EmptyView()
                }
            )
        }
    }
    
    @ViewBuilder
    private var destinationView: some View {
        if selectedRole == .client {
            ClientHomeView()
        } else if selectedRole == .lawyer {
            LawyerHomeView()
        } else {
            EmptyView()
        }
    }
}

struct RoleCard: View {
    let title: String
    let icon: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(color)
                    .cornerRadius(15)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
