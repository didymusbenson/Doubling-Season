#!/usr/bin/env swift

import Foundation

// MARK: - Token Definition Model (Mirror of Swift implementation)
struct TokenDefinition: Codable {
    let name: String
    let abilities: String
    let pt: String
    let colors: String
    let type: String
}

// MARK: - Validation Results
struct ValidationResult {
    var totalTokens: Int = 0
    var validTokens: Int = 0
    var invalidTokens: [String] = []
    var warnings: [String] = []
    var errors: [String] = []
    
    var isValid: Bool {
        return errors.isEmpty && invalidTokens.isEmpty
    }
    
    func printReport() {
        print("\n" + String(repeating: "=", count: 60))
        print("TOKEN DATABASE VALIDATION REPORT")
        print(String(repeating: "=", count: 60))
        
        print("\n📊 STATISTICS:")
        print("  • Total tokens: \(totalTokens)")
        print("  • Valid tokens: \(validTokens)")
        print("  • Invalid tokens: \(invalidTokens.count)")
        
        if !errors.isEmpty {
            print("\n❌ ERRORS:")
            for error in errors {
                print("  • \(error)")
            }
        }
        
        if !invalidTokens.isEmpty {
            print("\n⚠️ INVALID TOKENS:")
            for token in invalidTokens.prefix(10) {
                print("  • \(token)")
            }
            if invalidTokens.count > 10 {
                print("  ... and \(invalidTokens.count - 10) more")
            }
        }
        
        if !warnings.isEmpty {
            print("\n⚠️ WARNINGS:")
            for warning in warnings.prefix(10) {
                print("  • \(warning)")
            }
            if warnings.count > 10 {
                print("  ... and \(warnings.count - 10) more")
            }
        }
        
        print("\n" + String(repeating: "=", count: 60))
        if isValid {
            print("✅ VALIDATION PASSED: Token database is valid!")
        } else {
            print("❌ VALIDATION FAILED: Please fix the issues above.")
        }
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Validation Functions
func validateTokenDatabase() -> ValidationResult {
    var result = ValidationResult()
    
    // 1. Check if file exists
    let fileURL = URL(fileURLWithPath: "Doubling Season/TokenDatabase.json")
    
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        result.errors.append("TokenDatabase.json not found at expected path")
        return result
    }
    
    // 2. Load and parse JSON
    do {
        let data = try Data(contentsOf: fileURL)
        
        // Check file size
        let fileSize = data.count
        print("📁 File size: \(fileSize / 1024) KB")
        
        // Decode tokens
        let decoder = JSONDecoder()
        let tokens = try decoder.decode([TokenDefinition].self, from: data)
        
        result.totalTokens = tokens.count
        
        // 3. Validate each token
        var tokenNames = Set<String>()
        var duplicates = [String]()
        
        for token in tokens {
            var isValid = true
            
            // Check for required fields
            if token.name.isEmpty {
                result.invalidTokens.append("Token with empty name")
                isValid = false
            }
            
            // Check for duplicates
            if tokenNames.contains(token.name) {
                duplicates.append(token.name)
                result.warnings.append("Duplicate token: \(token.name)")
            } else {
                tokenNames.insert(token.name)
            }
            
            // Validate colors format
            let validColors = Set(["W", "U", "B", "R", "G"])
            for char in token.colors {
                if !validColors.contains(String(char)) && !token.colors.isEmpty {
                    result.warnings.append("Invalid color '\(char)' in token: \(token.name)")
                }
            }
            
            // Validate P/T format for creatures
            if !token.pt.isEmpty {
                let ptPattern = #"^\*?/\*?$|^\d+/\d+$|^[*\d]+/[*\d]+$"#
                let ptRegex = try? NSRegularExpression(pattern: ptPattern)
                let ptRange = NSRange(location: 0, length: token.pt.utf16.count)
                if ptRegex?.firstMatch(in: token.pt, options: [], range: ptRange) == nil {
                    result.warnings.append("Unusual P/T format '\(token.pt)' for token: \(token.name)")
                }
            }
            
            // Check type consistency
            if token.type.isEmpty {
                result.warnings.append("Empty type for token: \(token.name)")
            }
            
            if isValid {
                result.validTokens += 1
            }
        }
        
        // 4. Additional statistics
        let creatures = tokens.filter { !$0.pt.isEmpty }
        let nonCreatures = tokens.filter { $0.pt.isEmpty }
        let colorless = tokens.filter { $0.colors.isEmpty }
        let multicolor = tokens.filter { $0.colors.count > 1 }
        
        print("\n📈 TOKEN CATEGORIES:")
        print("  • Creatures: \(creatures.count)")
        print("  • Non-creatures: \(nonCreatures.count)")
        print("  • Colorless: \(colorless.count)")
        print("  • Multicolor: \(multicolor.count)")
        print("  • Unique names: \(tokenNames.count)")
        
        if !duplicates.isEmpty {
            print("\n⚠️ Found \(duplicates.count) duplicate token names")
        }
        
    } catch let error as DecodingError {
        switch error {
        case .dataCorrupted(let context):
            result.errors.append("Data corrupted: \(context.debugDescription)")
        case .keyNotFound(let key, let context):
            result.errors.append("Missing key '\(key.stringValue)': \(context.debugDescription)")
        case .typeMismatch(let type, let context):
            result.errors.append("Type mismatch for \(type): \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            result.errors.append("Value not found for \(type): \(context.debugDescription)")
        @unknown default:
            result.errors.append("Unknown decoding error: \(error)")
        }
    } catch {
        result.errors.append("Failed to load or parse JSON: \(error.localizedDescription)")
    }
    
    return result
}

// MARK: - Bundle Validation
func validateBundleInclusion() {
    print("\n🔍 CHECKING XCODE PROJECT CONFIGURATION:")
    
    let pbxprojPath = "Doubling Season.xcodeproj/project.pbxproj"
    
    do {
        let content = try String(contentsOfFile: pbxprojPath, encoding: .utf8)
        
        // Check for new Swift files
        let requiredFiles = [
            "TokenDefinition.swift",
            "TokenDatabase.swift",
            "TokenSearchView.swift",
            "TokenSearchRow.swift",
            "TokenDatabase.json"
        ]
        
        var missingFiles = [String]()
        
        for file in requiredFiles {
            if !content.contains(file) {
                missingFiles.append(file)
            }
        }
        
        if missingFiles.isEmpty {
            print("  ✅ All required files are included in the Xcode project")
        } else {
            print("  ❌ Missing files in Xcode project:")
            for file in missingFiles {
                print("    • \(file)")
            }
            print("\n  ⚠️ IMPORTANT: You need to manually add these files to the Xcode project:")
            print("    1. Open the project in Xcode")
            print("    2. Right-click on 'Doubling Season' folder")
            print("    3. Select 'Add Files to \"Doubling Season\"'")
            print("    4. Select the missing files and ensure 'Copy items if needed' is unchecked")
            print("    5. Make sure the target membership is checked")
        }
        
    } catch {
        print("  ❌ Could not read project.pbxproj: \(error.localizedDescription)")
    }
}

// MARK: - Main Execution
print("🚀 Starting Token Implementation Validation...")
print(String(repeating: "=", count: 60))

// Run validations
validateBundleInclusion()
let result = validateTokenDatabase()
result.printReport()

// Exit with appropriate code
exit(result.isValid ? 0 : 1)