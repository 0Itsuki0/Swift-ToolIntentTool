//
//  ToolToIntentMacro.swift
//  ToolIntentTool
//
//  Created by Itsuki on 2026/11/07.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ToolToIntentMacro: ExtensionMacro, MemberMacro {
    static let identifier = "EnumToAppEnum"

    static let injectedParameterName = "input_ToolIntentTool"

    // MARK: - MemberMacro
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [
            """
            @Parameter(title: "Tool input")
            var \(raw: injectedParameterName): Arguments
            """
        ]
    }

    // MARK: - Extension Macro
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.kind == .structDecl || declaration.kind == .classDecl
        else {
            throw MacroExpansionErrorMessage(
                "\(identifier) is only allowed on enums, structs, and classes."
            )
        }

        guard !protocols.isEmpty else {
            return []
        }

        let variableMembers = declaration.memberBlock.members.compactMap {
            $0.decl.as(VariableDeclSyntax.self)
        }.flatMap { $0.bindings }

        let name = variableMembers.first(where: {
            $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                .trimmingCharacters(in: .whitespacesAndNewlines) == "name"
        })?.stringValue.map { TokenSyntax(stringLiteral: $0) }

        let description = variableMembers.first(where: {
            $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                == "description"
        })?.stringValue.map { TokenSyntax(stringLiteral: $0) }

        let ids = protocols.map({ $0.as(IdentifierTypeSyntax.self) }).map(
            \.?.name.identifier
        ).filter({ $0 != nil }).map({ $0! })

        return [
            try ExtensionDeclSyntax(
                """
                extension \(type): \(raw: ids.joined(separator: ",")) {
                    static var title: LocalizedStringResource {
                        LocalizedStringResource(
                            stringLiteral: "\(name ?? "\(type)")"
                        )
                    }
                    
                    static var description: IntentDescription? {
                        IntentDescription(
                                stringLiteral: "\(description ?? "\(type)")"
                        )
                    }

                    func perform() async throws -> some IntentResult & ReturnsValue<Output> {
                        let result = try await self.call(arguments: self.\(raw: injectedParameterName))
                        return .result(value: result)
                    }
                }
                """
            )
        ]
    }
}

extension TypeInitializerClauseSyntax {
    ///    var
}

extension VariableDeclSyntax {
    func stringValue(for name: String) -> String? {
        ///        guard let bindings = self.bindings.

        return nil
    }
}

extension TokenSyntax {
    var identifier: String? {
        if case .identifier(let id) = self.tokenKind {
            return id
        }
        return nil
    }

    var keyword: Keyword? {
        if case .keyword(let keyword) = self.tokenKind {
            return keyword
        }
        return nil
    }

    var stringSegments: String? {
        if case .stringSegment(let string) = self.tokenKind {
            return string
        }
        return nil
    }
}

struct VariableProperty {
    var name: String
    var behavior: PropertyBehavior
    var shouldSkip: Bool
    var rename: String?
}

enum PropertyBehavior: Equatable {
    case stored
    case lazyStored
    case `static`
    case computed(settable: Bool, getEffects: Set<GetPropertyEffect>)

    var isComputed: Bool {
        if case .computed(_, _) = self {
            return true
        }
        return false
    }
}

enum GetPropertyEffect: String, Equatable {
    case async
    case `throws`

    static func fromAccessorSpecifier(
        _ effectSpecifiers: AccessorEffectSpecifiersSyntax?
    ) -> Set<Self> {
        var effects: Set<Self> = []
        if effectSpecifiers?.asyncSpecifier != nil {
            effects.insert(.async)
        }
        if effectSpecifiers?.throwsClause != nil {
            effects.insert(.throws)
        }
        return effects
    }
}

extension StringLiteralExprSyntax {
    var stringContent: String {
        let stringSegments = self.segments.map({
            $0.as(StringSegmentSyntax.self)?.content.stringSegments
        })
        return stringSegments.filter({ $0 != nil }).map({ $0! }).joined(
            separator: " "
        )
    }
}

extension PatternBindingSyntax {
    var initialized: Bool {
        self.initializer != nil
    }

    var name: String? {
        guard let identifier = self.pattern.as(IdentifierPatternSyntax.self)
        else {
            return nil
        }
        return identifier.identifier.text
    }

    // TODO: - handle other cases
    /// Best effort base.
    /// Not handling `DeclReferenceExprSyntax` as there is no way to resolve the value assigned to it
    var stringValue: String? {
        /// ```
        /// let name = "123"
        ///
        /// ╰─[0]: PatternBindingSyntax
        ///   ├─pattern: IdentifierPatternSyntax
        ///   │ ╰─identifier: identifier("name")
        ///   ╰─initializer: InitializerClauseSyntax
        ///     ├─equal: equal
        ///     ╰─value: StringLiteralExprSyntax
        ///       ├─openingQuote: stringQuote
        ///       ├─segments: StringLiteralSegmentListSyntax
        ///       │ ╰─[0]: StringSegmentSyntax
        ///       │   ╰─content: stringSegment("123")
        ///       ╰─closingQuote: stringQuote
        /// ```
        if let initializer,
            let stringSyntax = initializer.value.as(
                StringLiteralExprSyntax.self
            )
        {
            return stringSyntax.stringContent
        }

        /// ```
        /// let name = "123" + "456"
        /// ╰─[0]: PatternBindingSyntax
        ///   ├─pattern: IdentifierPatternSyntax
        ///   │ ╰─identifier: identifier("name")
        ///   ╰─initializer: InitializerClauseSyntax
        ///     ├─equal: equal
        ///     ╰─value: SequenceExprSyntax
        ///       ╰─elements: ExprListSyntax
        ///         ├─[0]: StringLiteralExprSyntax
        ///         │ ├─openingQuote: stringQuote
        ///         │ ├─segments: StringLiteralSegmentListSyntax
        ///         │ │ ╰─[0]: StringSegmentSyntax
        ///         │ │   ╰─content: stringSegment("123")
        ///         │ ╰─closingQuote: stringQuote
        ///         ├─[1]: BinaryOperatorExprSyntax
        ///         │ ╰─operator: binaryOperator("+")
        ///         ╰─[2]: StringLiteralExprSyntax
        ///           ├─openingQuote: stringQuote
        ///           ├─segments: StringLiteralSegmentListSyntax
        ///           │ ╰─[0]: StringSegmentSyntax
        ///           │   ╰─content: stringSegment("456")
        ///           ╰─closingQuote: stringQuote
        /// ```
        if let initializer,
            let seqSytax = initializer.value.as(
                SequenceExprSyntax.self
            )
        {
            let stringElements = seqSytax.elements.compactMap {
                $0.as(StringLiteralExprSyntax.self)
            }
            return stringElements.compactMap {
                $0.stringContent
            }.joined()
        }

        //        guard let accessorBlock = self.accessorBlock else {
        //            return nil
        //        }
        //
        //        if let returnSyntaxIndex = accessorBlock.accessors

        /// ```
        /// var getName: String { "123" }
        ///
        /// ╰─accessorBlock: AccessorBlockSyntax
        ///   ├─leftBrace: leftBrace
        ///   ├─accessors: CodeBlockItemListSyntax
        ///   │ ╰─[0]: CodeBlockItemSyntax
        ///   │   ╰─item: StringLiteralExprSyntax
        ///   │     ├─openingQuote: stringQuote
        ///   │     ├─segments: StringLiteralSegmentListSyntax
        ///   │     │ ╰─[0]: StringSegmentSyntax
        ///   │     │   ╰─content: stringSegment("123")
        ///   │     ╰─closingQuote: stringQuote
        ///   ╰─rightBrace: rightBrace
        /// ```

        return nil
    }

    func propertyBehavior(modifiers: DeclModifierListSyntax) -> PropertyBehavior
    {
        if modifiers.contains(where: { $0.name.keyword == .lazy }) {
            return .lazyStored
        }
        if modifiers.contains(where: { $0.name.keyword == .static }) {
            return .static
        }

        guard let accessorBlock = self.accessorBlock else {
            return .stored
        }

        // MARK: - Case 0: Get w/o explicit getter
        /// ```
        ///   var calcNoGetSet: String {
        ///        "name"
        ///   }
        ///
        ///   accessorBlock: AccessorBlockSyntax
        ///   ├─leftBrace: leftBrace
        ///   ├─accessors: CodeBlockItemListSyntax
        ///   │ ╰─[0]: CodeBlockItemSyntax
        ///   │   ╰─item: DeclReferenceExprSyntax
        ///   │     ╰─baseName: identifier("name")
        ///   ╰─rightBrace: rightBrace
        ///   ```
        if accessorBlock.accessors.is(CodeBlockItemListSyntax.self) {
            return .computed(settable: false, getEffects: [])
        }

        guard
            let accessors = accessorBlock.accessors.as(
                AccessorDeclListSyntax.self
            )
        else {
            return .stored
        }

        //MARK: -  Case 1: DidSet
        //
        ///    var calcDidSet: String {
        ///        didSet {
        ///            print("did set")
        ///        }
        ///    }
        /// ```
        ///   accessorBlock: AccessorBlockSyntax
        ///   ├─leftBrace: leftBrace
        ///   ├─accessors: AccessorDeclListSyntax
        ///   │ ╰─[0]: AccessorDeclSyntax
        ///   │   ├─attributes: AttributeListSyntax
        ///   │   ├─accessorSpecifier: keyword(SwiftSyntax.Keyword.didSet)
        ///   │   ╰─body: CodeBlockSyntax
        ///   │     ├─leftBrace: leftBrace
        ///   │     ├─statements: CodeBlockItemListSyntax
        ///   │     │ ╰─[0]: CodeBlockItemSyntax
        ///   │     │   ╰─item: FunctionCallExprSyntax
        ///   │     │     ├─calledExpression: DeclReferenceExprSyntax
        ///   │     │     │ ╰─baseName: identifier("print")
        ///   │     │     ├─leftParen: leftParen
        ///   │     │     ├─arguments: LabeledExprListSyntax
        ///   │     │     │ ╰─[0]: LabeledExprSyntax
        ///   │     │     │   ╰─expression: StringLiteralExprSyntax
        ///   │     │     │     ├─openingQuote: stringQuote
        ///   │     │     │     ├─segments: StringLiteralSegmentListSyntax
        ///   │     │     │     │ ╰─[0]: StringSegmentSyntax
        ///   │     │     │     │   ╰─content: stringSegment("did set")
        ///   │     │     │     ╰─closingQuote: stringQuote
        ///   │     │     ├─rightParen: rightParen
        ///   │     │     ╰─additionalTrailingClosures: MultipleTrailingClosureElementListSyntax
        ///   │     ╰─rightBrace: rightBrace
        ///   ╰─rightBrace: rightBrace
        ///   ```

        // MARK: - Case 2: willSet
        /// ```
        ///    var calcWillSet: String {
        ///        willSet {
        ///            print("will set")
        ///        }
        ///    }
        ///   accessorBlock: AccessorBlockSyntax
        ///   ├─leftBrace: leftBrace
        ///   ├─accessors: AccessorDeclListSyntax
        ///   │ ╰─[0]: AccessorDeclSyntax
        ///   │   ├─attributes: AttributeListSyntax
        ///   │   ├─accessorSpecifier: keyword(SwiftSyntax.Keyword.willSet)
        ///   │   ╰─body: CodeBlockSyntax
        ///   │     ├─leftBrace: leftBrace
        ///   │     ├─statements: CodeBlockItemListSyntax
        ///   │     │ ╰─[0]: CodeBlockItemSyntax
        ///   │     │   ╰─item: FunctionCallExprSyntax
        ///   │     │     ├─calledExpression: DeclReferenceExprSyntax
        ///   │     │     │ ╰─baseName: identifier("print")
        ///   │     │     ├─leftParen: leftParen
        ///   │     │     ├─arguments: LabeledExprListSyntax
        ///   │     │     │ ╰─[0]: LabeledExprSyntax
        ///   │     │     │   ╰─expression: StringLiteralExprSyntax
        ///   │     │     │     ├─openingQuote: stringQuote
        ///   │     │     │     ├─segments: StringLiteralSegmentListSyntax
        ///   │     │     │     │ ╰─[0]: StringSegmentSyntax
        ///   │     │     │     │   ╰─content: stringSegment("will set")
        ///   │     │     │     ╰─closingQuote: stringQuote
        ///   │     │     ├─rightParen: rightParen
        ///   │     │     ╰─additionalTrailingClosures: MultipleTrailingClosureElementListSyntax
        ///   │     ╰─rightBrace: rightBrace
        ///   ╰─rightBrace: rightBrace
        ///   ```

        if accessors.contains(where: {
            $0.accessorSpecifier.keyword == .willSet
                || $0.accessorSpecifier.keyword == .didSet
        }) {
            return .stored
        }

        // MARK: - Case 3: Get
        /// ```
        ///    var calcGet: String {
        ///        get {
        ///            return "name"
        ///        }
        ///    }
        ///
        ///   accessorBlock: AccessorBlockSyntax
        ///   ├─leftBrace: leftBrace
        ///   ├─accessors: AccessorDeclListSyntax
        ///   │ ╰─[0]: AccessorDeclSyntax
        ///   │   ├─attributes: AttributeListSyntax
        ///   │   ├─accessorSpecifier: keyword(SwiftSyntax.Keyword.get)
        ///   │   ╰─body: CodeBlockSyntax
        ///   │     ├─leftBrace: leftBrace
        ///   │     ├─statements: CodeBlockItemListSyntax
        ///   │     │ ╰─[0]: CodeBlockItemSyntax
        ///   │     │   ╰─item: ReturnStmtSyntax
        ///   │     │     ├─returnKeyword: keyword(SwiftSyntax.Keyword.return)
        ///   │     │     ╰─expression: DeclReferenceExprSyntax
        ///   │     │       ╰─baseName: identifier("name")
        ///   │     ╰─rightBrace: rightBrace
        ///   ╰─rightBrace: rightBrace
        /// ```

        // MARK: - Case 4: get set
        ///```
        ///    var calcGetSet: String {
        ///        get {
        ///            return ""
        ///        }
        ///        set {
        ///            print(newValue)
        ///        }
        ///    }
        ///
        ///   accessorBlock: AccessorBlockSyntax
        ///   ├─leftBrace: leftBrace
        ///   ├─accessors: AccessorDeclListSyntax
        ///   │ ├─[0]: AccessorDeclSyntax
        ///   │ │ ├─attributes: AttributeListSyntax
        ///   │ │ ├─accessorSpecifier: keyword(SwiftSyntax.Keyword.get)
        ///   │ │ ╰─body: CodeBlockSyntax
        ///   │ │   ├─leftBrace: leftBrace
        ///   │ │   ├─statements: CodeBlockItemListSyntax
        ///   │ │   │ ╰─[0]: CodeBlockItemSyntax
        ///   │ │   │   ╰─item: DeclReferenceExprSyntax
        ///   │ │   │     ╰─baseName: identifier("name")
        ///   │ │   ╰─rightBrace: rightBrace
        ///   │ ╰─[1]: AccessorDeclSyntax
        ///   │   ├─attributes: AttributeListSyntax
        ///   │   ├─accessorSpecifier: keyword(SwiftSyntax.Keyword.set)
        ///   │   ╰─body: CodeBlockSyntax
        ///   │     ├─leftBrace: leftBrace
        ///   │     ├─statements: CodeBlockItemListSyntax
        ///   │     │ ╰─[0]: CodeBlockItemSyntax
        ///   │     │   ╰─item: SequenceExprSyntax
        ///   │     │     ╰─elements: ExprListSyntax
        ///   │     │       ├─[0]: DeclReferenceExprSyntax
        ///   │     │       │ ╰─baseName: identifier("name")
        ///   │     │       ├─[1]: AssignmentExprSyntax
        ///   │     │       │ ╰─equal: equal
        ///   │     │       ╰─[2]: DeclReferenceExprSyntax
        ///   │     │         ╰─baseName: identifier("newValue")
        ///   │     ╰─rightBrace: rightBrace
        ///   ╰─rightBrace: rightBrace
        ///   ```

        if accessors.contains(where: { $0.accessorSpecifier.keyword == .get }) {
            let get = accessors.first(where: {
                $0.accessorSpecifier.keyword == .get
            })
            let getEffects = GetPropertyEffect.fromAccessorSpecifier(
                get?.effectSpecifiers
            )
            let settable =
                accessors.count(where: { $0.accessorSpecifier.keyword == .set })
                > 0
            return .computed(settable: settable, getEffects: getEffects)
        }

        return .stored
    }

    var propertyType: TypeSyntax? {
        if let type = self.typeAnnotation?.type {
            return type.trimmed
        }
        return self.initializer?.value.propertyType
    }
}

extension SwiftSyntax.ExprSyntax {
    var propertyType: TypeSyntax? {
        switch self.kind {
        case .integerLiteralExpr:
            return "Int"
        case .floatLiteralExpr:
            return "Double"
        case .stringLiteralExpr:
            return "String"
        case .booleanLiteralExpr:
            return "Bool"
        case .arrayExpr:
            return self.as(ArrayExprSyntax.self)?
                .propertyType
        case .dictionaryExpr:
            return self.as(DictionaryExprSyntax.self)?
                .propertyType
        case .nilLiteralExpr:
            return "Any?"
        /// nested structs
        case .functionCallExpr:
            return self.as(FunctionCallExprSyntax.self)?
                .propertyType
        default:
            return nil
        }
    }
}

extension DictionaryExprSyntax {
    /// full expression with type is required when creating initializer
    var propertyType: TypeSyntax {
        let base: TypeSyntax = "Dictionary"
        /// ```
        ///  ├─content: DictionaryElementListSyntax
        ///  │ ╰─[0]: DictionaryElementSyntax
        ///  │   ├─key: IntegerLiteralExprSyntax
        ///  │   │ ╰─literal: integerLiteral("123")
        ///  │   ├─colon: colon
        ///  │   ╰─value: FunctionCallExprSyntax
        ///  │     ├─calledExpression: DeclReferenceExprSyntax
        ///  │     │ ╰─baseName: identifier("SomeNested")
        ///  │     ├─leftParen: leftParen
        ///  │     ├─arguments: LabeledExprListSyntax
        ///  │     │ ╰─[0]: LabeledExprSyntax
        ///  │     │   ├─label: identifier("nested")
        ///  │     │   ├─colon: colon
        ///  │     │   ╰─expression: StringLiteralExprSyntax
        ///  │     │     ├─openingQuote: stringQuote
        ///  │     │     ├─segments: StringLiteralSegmentListSyntax
        ///  │     │     │ ╰─[0]: StringSegmentSyntax
        ///  │     │     │   ╰─content: stringSegment("nest")
        ///  │     │     ╰─closingQuote: stringQuote
        ///  │     ├─rightParen: rightParen
        ///  ```
        guard let content = self.content.as(DictionaryElementListSyntax.self),
            let first = content.first
        else {
            return base
        }
        guard let keyType = first.key.propertyType,
            let valueType = first.value.propertyType
        else {
            return base
        }
        return "\(base)<\(keyType), \(valueType)>"
    }
}

extension FunctionCallExprSyntax {
    var propertyType: TypeSyntax? {
        guard
            let id = self.calledExpression.as(DeclReferenceExprSyntax.self)?
                .baseName.identifier
        else {
            return nil
        }
        return .init(stringLiteral: id)
    }
}

extension ArrayExprSyntax {
    var propertyType: TypeSyntax? {
        let base: TypeSyntax = "Array"
        guard let firstElement = elements.first else {
            return base
        }

        guard let type = firstElement.expression.propertyType else {
            return base
        }
        return "\(base)<\(type)>"
    }
}
