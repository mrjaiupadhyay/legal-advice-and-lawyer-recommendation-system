//
//  LawyerMatchingService.swift
//  legal_doc
//
//  AI-powered service to suggest lawyers to clients based on their queries
//

import Foundation
import CoreData

class LawyerMatchingService {
    private let aiService = AIService()
    
    func findMatchingLawyers(for query: LegalQuery, in context: NSManagedObjectContext) async -> [Lawyer] {
        guard let category = query.category else {
            return []
        }
        
        // First, find lawyers with matching specializations
        var matchingLawyers: [Lawyer] = []
        
        if let categoryName = category.name {
            let lawyerFetch: NSFetchRequest<Lawyer> = Lawyer.fetchRequest()
            lawyerFetch.predicate = NSPredicate(format: "ANY specializations.name == %@", categoryName)
            
            if let lawyers = try? context.fetch(lawyerFetch) {
                matchingLawyers = Array(lawyers)
            }
        }
        
        // Filter out AI lawyer
        matchingLawyers = matchingLawyers.filter { 
            guard let email = $0.email else { return false }
            return email != "ai@pocketlawyer.com"
        }
        
        // If we have matching lawyers, use AI to rank them
        if !matchingLawyers.isEmpty {
            return await rankLawyers(matchingLawyers, for: query)
        }
        
        // If no exact match, get all lawyers and let AI suggest
        let allLawyersFetch: NSFetchRequest<Lawyer> = Lawyer.fetchRequest()
        if let allLawyers = try? context.fetch(allLawyersFetch) {
            let filteredLawyers = Array(allLawyers).filter { $0.email != "ai@pocketlawyer.com" }
            return await rankLawyers(filteredLawyers, for: query)
        }
        
        return []
    }
    
    private func rankLawyers(_ lawyers: [Lawyer], for query: LegalQuery) async -> [Lawyer] {
        guard !lawyers.isEmpty else { return [] }
        
        // Create lawyer summaries for AI
        let lawyerSummaries = lawyers.map { lawyer in
            let specializations = (lawyer.specializations as? Set<LegalCategory>)?.map { $0.name ?? "" }.joined(separator: ", ") ?? "General"
            return """
            Name: \(lawyer.name ?? "Unknown")
            Specializations: \(specializations)
            Experience: \(lawyer.experience) years
            Rating: \(lawyer.rating)
            Hourly Rate: $\(lawyer.hourlyRate)
            Bio: \(lawyer.bio ?? "")
            """
        }.joined(separator: "\n\n")
        
        let queryDescription = query.queryDescription ?? ""
        let category = query.category?.name ?? "General"
        
        // Use AI to rank lawyers
        do {
            let ranking = try await aiService.rankLawyers(
                query: queryDescription,
                category: category,
                lawyers: lawyerSummaries
            )
            
            // Parse AI response and sort lawyers
            return sortLawyersByRanking(lawyers, ranking: ranking)
        } catch {
            // Fallback to simple ranking by rating and experience
            return lawyers.sorted { lawyer1, lawyer2 in
                if lawyer1.rating != lawyer2.rating {
                    return lawyer1.rating > lawyer2.rating
                }
                return lawyer1.experience > lawyer2.experience
            }
        }
    }
    
    private func sortLawyersByRanking(_ lawyers: [Lawyer], ranking: String) -> [Lawyer] {
        // Simple parsing - look for lawyer names in the ranking
        // In a production app, you'd want more sophisticated parsing
        var rankedLawyers: [Lawyer] = []
        var remainingLawyers = lawyers
        
        for lawyer in lawyers {
            if ranking.localizedCaseInsensitiveContains(lawyer.name ?? "") {
                rankedLawyers.append(lawyer)
                remainingLawyers.removeAll { $0.lawyerID == lawyer.lawyerID }
            }
        }
        
        // Add remaining lawyers at the end
        rankedLawyers.append(contentsOf: remainingLawyers)
        
        return rankedLawyers
    }
}

extension AIService {
    func rankLawyers(query: String, category: String, lawyers: String) async throws -> String {
        // If no API key, return a simple ranking
        guard apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            return "Based on the query, all listed lawyers are suitable. Consider rating and experience."
        }
        
        let prompt = """
        You are a legal matching assistant. A client has submitted a query in the \(category) category.
        
        Client Query: \(query)
        
        Available Lawyers:
        \(lawyers)
        
        Please analyze the query and rank the lawyers from most suitable to least suitable. 
        Consider their specializations, experience, and how well they match the client's needs.
        Return a brief explanation of why each lawyer is recommended, focusing on the top 3-5 matches.
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a legal matching assistant that helps clients find the right lawyer based on their specific needs."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 400,
            "temperature": 0.7
        ]
        
        guard let url = URL(string: apiURL) else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.apiError("Failed to get response from AI service")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
