//
//  AIService.swift
//  legal_doc
//
//  AI Service for answering legal queries
//

import Foundation

class AIService {
    // CONFIGURATION INSTRUCTIONS:
    // To enable AI-powered responses:
    // 1. Get your OpenAI API key from https://platform.openai.com/api-keys
    // 2. Replace "YOUR_OPENAI_API_KEY_HERE" below with your actual API key
    // 3. For production apps, consider storing the key securely (e.g., in Keychain or environment variables)
    // 4. The app will work without an API key but will provide basic template responses
    
    let apiKey: String = "YOUR_OPENAI_API_KEY_HERE"
    let apiURL = "https://api.openai.com/v1/chat/completions"
    
    func generateLegalResponse(query: String, category: String) async throws -> String {
        // If no API key is set, return a helpful response
        guard apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            return generateLocalResponse(query: query, category: category)
        }
        
        let prompt = """
        You are a helpful legal assistant. Provide clear, informative, and professional legal guidance.
        The user has a question in the category: \(category)
        
        Question: \(query)
        
        Please provide:
        1. A clear explanation of the legal issue
        2. General guidance (note: this is not legal advice)
        3. Suggestions for next steps
        4. When to consult a licensed attorney
        
        Keep the response concise but comprehensive. Use plain language.
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful legal assistant providing general legal information. Always remind users that this is not legal advice and they should consult a licensed attorney for specific legal matters."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
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
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Fallback local response when API key is not configured
    private func generateLocalResponse(query: String, category: String) -> String {
        return """
        Thank you for your query in the \(category) category.
        
        **Understanding Your Query:**
        \(query)
        
        **General Information:**
        Based on your question, this appears to be a matter related to \(category). While I can provide general information, please note that this is not legal advice.
        
        **Next Steps:**
        1. Document all relevant details and dates
        2. Gather any related documents or evidence
        3. Consult with a licensed attorney who specializes in \(category)
        4. Consider your options carefully before taking action
        
        **Important Disclaimer:**
        This response is for informational purposes only and does not constitute legal advice. Laws vary by jurisdiction, and your specific situation may require professional legal counsel. Please consult with a qualified attorney for advice tailored to your circumstances.
        
        Your query has been saved and will be reviewed by our team.
        """
    }
}

enum AIError: LocalizedError {
    case invalidURL
    case apiError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}
