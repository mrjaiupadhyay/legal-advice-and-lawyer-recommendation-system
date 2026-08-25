//
//  QueryListView.swift
//  legal_doc
//
//  View to display all legal queries and their AI responses
//

import SwiftUI
import CoreData

struct QueryListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authManager = ClientAuthManager()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LegalQuery.dateCreated, ascending: false)],
        animation: .default)
    private var allQueries: FetchedResults<LegalQuery>
    
    private var queriesArray: [LegalQuery] {
        guard let userID = authManager.currentUserID else { return [] }
        return Array(allQueries.filter { query in
            guard let queryUserID = query.user?.userID else { return false }
            return queryUserID == userID
        })
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(queriesArray, id: \.objectID) { query in
                    NavigationLink(destination: QueryDetailView(query: query)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(query.title ?? "Untitled Query")
                                .font(.headline)
                            
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
                                Spacer()
                                
                                if let responses = query.responses, responses.count > 0 {
                                    Label("\(responses.count) Response(s)", systemImage: "message.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteQueries)
            }
            .navigationTitle("My Queries")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteQueries(offsets: IndexSet) {
        withAnimation {
            offsets.map { queriesArray[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct QueryDetailView: View {
    @ObservedObject var query: LegalQuery
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Query Information
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
                    
                    if let dateCreated = query.dateCreated {
                        InfoRow(label: "Submitted", value: formatDate(dateCreated))
                    }
                }
                .padding()
                
                Divider()
                
                // Case Status
                if let caseStatus = query.caseStatus {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Case Status")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        InfoRow(label: "Status", value: caseStatus.status ?? "Unknown")
                        
                        if let notes = caseStatus.notes {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.headline)
                                Text(notes)
                                    .font(.body)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // AI Responses
                if let responses = query.responses as? Set<LawyerResponse>, !responses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Responses")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(Array(responses.sorted(by: { ($0.dateCreated ?? Date()) > ($1.dateCreated ?? Date()) })), id: \.responseID) { response in
                            ResponseCard(response: response)
                        }
                    }
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Responses")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("No responses yet. AI is processing your query...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Query Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.headline)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.body)
            Spacer()
        }
    }
}

struct ResponseCard: View {
    @ObservedObject var response: LawyerResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text(response.lawyer?.name ?? "AI Assistant")
                    .font(.headline)
                Spacer()
                if let date = response.dateCreated {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let content = response.content {
                Text(content)
                    .font(.body)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack {
                if response.isAccepted {
                    Label("Accepted", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
