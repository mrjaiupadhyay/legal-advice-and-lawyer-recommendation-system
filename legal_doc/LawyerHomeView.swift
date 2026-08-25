//
//  LawyerHomeView.swift
//  legal_doc
//
//  Home screen for lawyers to view and respond to queries
//

import SwiftUI
import CoreData

struct LawyerHomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authManager = LawyerAuthManager()
    @State private var selectedTab = 0
    @State private var showRegistration = false
    
    var body: some View {
        Group {
            if authManager.currentLawyerID != nil {
                // Lawyer is logged in
                TabView(selection: $selectedTab) {
                    // Pending Queries Tab
                    PendingQueriesView()
                        .environmentObject(authManager)
                        .tabItem {
                            Label("Pending", systemImage: "clock.fill")
                        }
                        .tag(0)
                    
                    // All Queries Tab
                    AllQueriesView()
                        .environmentObject(authManager)
                        .tabItem {
                            Label("All Queries", systemImage: "list.bullet")
                        }
                        .tag(1)
                    
                    // My Profile Tab
                    LawyerProfileView()
                        .environmentObject(authManager)
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                        .tag(2)
                }
                .navigationBarTitleDisplayMode(.inline)
            } else {
                // Show registration/login screen
                LawyerLoginView()
                    .environmentObject(authManager)
                    .sheet(isPresented: $showRegistration) {
                        LawyerRegistrationView()
                            .environmentObject(authManager)
                    }
            }
        }
    }
}

struct LawyerLoginView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: LawyerAuthManager
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var showRegistration = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                VStack(spacing: 10) {
                    LogoView(size: 100)
                    Text("Lawyer Portal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Sign in to access your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 50)
                
                // Login Form
                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal)
                    
                    Button(action: login) {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(email.isEmpty ? Color.gray : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(email.isEmpty)
                    .padding(.horizontal)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    Button(action: { showRegistration = true }) {
                        Text("Create New Account")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Lawyer Login")
            .sheet(isPresented: $showRegistration) {
                LawyerRegistrationView()
                    .environmentObject(authManager)
            }
        }
    }
    
    private func login() {
        guard !email.isEmpty else { return }
        
        let emailFetch: NSFetchRequest<Lawyer> = Lawyer.fetchRequest()
        emailFetch.predicate = NSPredicate(format: "email == %@", email)
        
        if let lawyer = try? viewContext.fetch(emailFetch).first {
            authManager.setCurrentLawyer(lawyer.lawyerID!)
            errorMessage = ""
        } else {
            errorMessage = "No account found with this email. Please create an account."
        }
    }
}

struct PendingQueriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: LawyerAuthManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LegalQuery.dateCreated, ascending: false)],
        predicate: NSPredicate(format: "caseStatus.status == %@ OR caseStatus.status == %@", "Submitted", "AI Response Received"),
        animation: .default)
    private var pendingQueries: FetchedResults<LegalQuery>
    
    private var queriesArray: [LegalQuery] {
        Array(pendingQueries)
    }
    
    var body: some View {
        NavigationView {
            List {
                if queriesArray.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("No Pending Queries")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("All queries have been responded to")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ForEach(queriesArray, id: \.objectID) { query in
                        NavigationLink(destination: QueryResponseView(query: query).environmentObject(authManager)) {
                            QueryRowView(query: query)
                        }
                    }
                }
            }
            .navigationTitle("Pending Queries")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(queriesArray.count) pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct AllQueriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: LawyerAuthManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LegalQuery.dateCreated, ascending: false)],
        animation: .default)
    private var allQueries: FetchedResults<LegalQuery>
    
    private var queriesArray: [LegalQuery] {
        Array(allQueries)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(queriesArray, id: \.objectID) { query in
                    NavigationLink(destination: QueryResponseView(query: query).environmentObject(authManager)) {
                        QueryRowView(query: query)
                    }
                }
            }
            .navigationTitle("All Queries")
        }
    }
}

struct QueryRowView: View {
    @ObservedObject var query: LegalQuery
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(query.title ?? "Untitled Query")
                    .font(.headline)
                Spacer()
                if let status = query.caseStatus?.status {
                    StatusBadge(status: status)
                }
            }
            
            Text(query.category?.name ?? "Unknown Category")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let description = query.queryDescription {
                Text(description)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if let user = query.user {
                    Label(user.name ?? "Unknown User", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let responses = query.responses, responses.count > 0 {
                    Label("\(responses.count) Response(s)", systemImage: "message.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if let dateCreated = query.dateCreated {
                    Text(formatDate(dateCreated))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case "Submitted":
            return .orange
        case "AI Response Received":
            return .blue
        case "Lawyer Responded":
            return .green
        case "Resolved":
            return .purple
        default:
            return .gray
        }
    }
}

struct QueryResponseView: View {
    @ObservedObject var query: LegalQuery
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: LawyerAuthManager
    @State private var responseText = ""
    @State private var showResponseForm = false
    @State private var isSubmitting = false
    @State private var successMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Query Details
                QueryDetailCard(query: query)
                
                Divider()
                
                // Existing Responses
                if let responses = query.responses as? Set<LawyerResponse>, !responses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Responses")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ForEach(Array(responses.sorted(by: { ($0.dateCreated ?? Date()) > ($1.dateCreated ?? Date()) })), id: \.responseID) { response in
                            ResponseCard(response: response)
                                .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
                
                // Response Form
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Response")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    TextEditor(text: $responseText)
                        .frame(height: 200)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    
                    Button(action: submitResponse) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Submit Response")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(responseText.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(responseText.isEmpty || isSubmitting)
                    .padding(.horizontal)
                    
                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Query Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func submitResponse() {
        guard !responseText.isEmpty,
              let lawyerID = authManager.currentLawyerID else {
            successMessage = "Please log in to submit a response"
            return
        }
        
        isSubmitting = true
        successMessage = ""
        
        // Get current logged-in lawyer
        let lawyerFetch: NSFetchRequest<Lawyer> = Lawyer.fetchRequest()
        lawyerFetch.predicate = NSPredicate(format: "lawyerID == %@", lawyerID as CVarArg)
        
        guard let lawyer = try? viewContext.fetch(lawyerFetch).first else {
            successMessage = "Error: Lawyer not found"
            isSubmitting = false
            return
        }
        
        // Create response
        let response = LawyerResponse(context: viewContext)
        response.responseID = UUID()
        response.content = responseText
        response.dateCreated = Date()
        response.isAccepted = false
        response.lawyer = lawyer
        response.query = query
        
        // Update case status
        if let caseStatus = query.caseStatus {
            caseStatus.status = "Lawyer Responded"
            caseStatus.notes = "Professional lawyer has provided a response"
            caseStatus.dateUpdated = Date()
        }
        
        // Save
        do {
            try viewContext.save()
            responseText = ""
            successMessage = "Response submitted successfully!"
            isSubmitting = false
        } catch {
            successMessage = "Error: \(error.localizedDescription)"
            isSubmitting = false
        }
    }
}

struct QueryDetailCard: View {
    @ObservedObject var query: LegalQuery
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Query Details")
                .font(.title2)
                .fontWeight(.bold)
            
            InfoRow(label: "Title", value: query.title ?? "Untitled")
            InfoRow(label: "Category", value: query.category?.name ?? "Unknown")
            
            if let description = query.queryDescription {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.headline)
                    Text(description)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if let user = query.user {
                InfoRow(label: "Client", value: user.name ?? "Unknown")
                InfoRow(label: "Email", value: user.email ?? "N/A")
                InfoRow(label: "Phone", value: user.phone ?? "N/A")
            }
            
            if let dateCreated = query.dateCreated {
                InfoRow(label: "Submitted", value: formatDate(dateCreated))
            }
            
            if let caseStatus = query.caseStatus {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.headline)
                    Text(caseStatus.status ?? "Unknown")
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct LawyerProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: LawyerAuthManager
    @FetchRequest(
        sortDescriptors: [],
        animation: .default)
    private var responses: FetchedResults<LawyerResponse>
    
    private var currentLawyer: Lawyer? {
        guard let lawyerID = authManager.currentLawyerID else { return nil }
        let fetch: NSFetchRequest<Lawyer> = Lawyer.fetchRequest()
        fetch.predicate = NSPredicate(format: "lawyerID == %@", lawyerID as CVarArg)
        return try? viewContext.fetch(fetch).first
    }
    
    private var myResponses: [LawyerResponse] {
        guard let lawyerID = authManager.currentLawyerID else { return [] }
        return Array(responses.filter { $0.lawyer?.lawyerID == lawyerID })
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let lawyer = currentLawyer {
                    Section(header: Text("Profile Information")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text(lawyer.name ?? "Lawyer")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(lawyer.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        InfoRow(label: "Phone", value: lawyer.phone ?? "N/A")
                        InfoRow(label: "Bar Number", value: lawyer.barNumber ?? "N/A")
                        InfoRow(label: "Experience", value: "\(lawyer.experience) years")
                        InfoRow(label: "Hourly Rate", value: String(format: "$%.2f", lawyer.hourlyRate))
                        InfoRow(label: "Rating", value: String(format: "%.1f ⭐", lawyer.rating))
                        
                        if let bio = lawyer.bio, !bio.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bio")
                                    .font(.headline)
                                Text(bio)
                                    .font(.body)
                            }
                        }
                        
                        if let specializations = lawyer.specializations as? Set<LegalCategory>, !specializations.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Specializations")
                                    .font(.headline)
                                Text(specializations.map { $0.name ?? "" }.joined(separator: ", "))
                                    .font(.body)
                            }
                        }
                    }
                    
                    Section(header: Text("Statistics")) {
                        HStack {
                            Text("Total Responses")
                            Spacer()
                            Text("\(myResponses.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        authManager.logout()
                    }) {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("My Profile")
        }
    }
}
