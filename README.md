# Swift: ToolIntentTool

A macro package providing macros for generating boilerplate code on AppIntent Tool/Generable conformance, 
targeting FoundationModels tools and Generable, but can be used for any structs.

Specifically, this package two macros. 
- `GenerableToGenerable`: generate expansions for App Intent Generable conformance
- `ToolToIntent`: generate expansions for App Intent ToolIntent

## Installation

In Xcode, Choose File → Add Package Dependencies… and 
Enter the following for input package URL:

```
https://github.com/0Itsuki0/Swift-ToolIntentTool.git
```

Choose the `ToolIntentTool` package and add it to all targets that you want to use the macro.

If Xcode add dependency UI loading never finishes (a bug in 27.3), add the following to `project.xcproj` directly.

```json
{
  "default-configuration": "Release",
  "configurations": [...],
  "localizations": {...},
  "packages": [
    {
      "kind": "remote",
      "repository": "https://github.com/0Itsuki0/Swift-ToolIntentTool",
      "version": {
        "branch": "main",
      },
    },
  ]
  ...
}
```


Or, for SPM-based projects, add it to your package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/0Itsuki0/Swift-ToolIntentTool.git", branch: "main")
]
```

And then add the product to all targets that use CodableX.

```swift
.product(name: "ToolIntentTool", package: "swift-toolintenttool"),
```



## Usage

```swift
import AppIntents
import FoundationModels
import ToolIntentTool

@ToolToIntent
struct GreetingTool: Tool {
    let name = "greet"
    let description = "greet a name."

    @Generable
    @GenerableToGenerable
    struct Arguments {
        @Guide(description: "The name to greet")
        /// Expansion from `GenerableToGenerable`
        /// `@Property(title: "name")`
        var name: String
    }

    @Generable
    @GenerableToGenerable
    struct Output {
        @Guide(description: "The result")
        /// Expansion from `GenerableToGenerable`
        /// `@Property(title: "result")`
        var result: String
    }

    func call(arguments: Arguments) async throws -> Output {
        print("Tool[\(name)] called with arguments: \(arguments)")
        return Output(result: "Hello \(arguments.name)")
    }
    
    /// Expansion from `ToolToIntent`
    /// ```
    /// @Parameter(title: "Tool input")
    /// var input_ToolIntentTool: Arguments
    /// ```
}

/// Expansion from `ToolToIntent`
/// ```
/// extension GreetingTool: ToolIntent {
///     static var title: LocalizedStringResource {
///          LocalizedStringResource(
///              stringLiteral: "greet"
///          )
///     }
///
///     static var description: IntentDescription? {
///          IntentDescription(
///              stringLiteral: "greet a name."
///          )
///     }
///
///     func perform() async throws -> some IntentResult & ReturnsValue<Output> {
///          let result = try await self.call(arguments: self.input_ToolIntentTool)
///          return .result(value: result)
///     }
/// }
/// ```


/// Expansion from `GenerableToGenerable`
/// ```
/// nonisolated extension GreetingTool.Output: GenerableEntity {
///     public init(
///         result: String,) {
///
///             self.result = result
///         }
///
///     static var typeDisplayRepresentation: TypeDisplayRepresentation {
///         TypeDisplayRepresentation(name: "Output")
///     }
///
///     var displayRepresentation: DisplayRepresentation {
///         DisplayRepresentation(stringLiteral: "Output")
///     }
/// }
/// ```


/// Expansion from `GenerableToGenerable`
/// ```
/// nonisolated extension GreetingTool.Arguments: GenerableEntity {
///     public init(
///         name: String,) {
///
///             self.name = name
///         }
///
///     static var typeDisplayRepresentation: TypeDisplayRepresentation {
///         TypeDisplayRepresentation(name: "Arguments")
///     }
///
///     var displayRepresentation: DisplayRepresentation {
///         DisplayRepresentation(stringLiteral: "Arguments")
///     }
/// }
/// ```
```
