//
//  GenerableToGenerableMacro.swift
//  ToolIntentTool
//
//  Created by Itsuki on 2026/11/07.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum IntentPropertyAttribute: CaseIterable {
    case `default`
    case computed
    case deferred

    var identifier: String {
        switch self {
        case .default:
            "Property"
        case .computed:
            "ComputedProperty"
        case .deferred:
            "DeferredProperty"
        }
    }

    static func exist(in syntax: AttributeListSyntax) -> Bool {
        for type in Self.allCases {
            if syntax.addedMacroCount(identifier: type.identifier) > 0 {
                return true
            }
        }
        return false
    }

    static func from(behavior: PropertyBehavior) -> (
        Self?, MacroExpansionWarningMessage?
    ) {
        switch behavior {
        case .stored:
            return (.default, nil)
        case .lazyStored:
            return (nil, nil)
        case .static:
            return (nil, nil)
        case .computed(_, let getEffects):
            if getEffects.contains(.async) {
                return (.deferred, nil)
            }

            if getEffects.contains(.throws) {
                let message = MacroExpansionWarningMessage(
                    """
                    Throwing is not supported for `ComputedProperty`.
                    If throwing is needed, consider change the property getter to `get async throws`.
                    """
                )
                return (nil, message)
            }

            return (.computed, nil)
        }
    }

}

public struct GenerableToGenerableMacro: ExtensionMacro,
    MemberAttributeMacro
{
    static let identifier = "GenerableToGenerable"

    /// common conformances properties of the FoundationModelsFramework
    static let skippedPropertyNames = [
        "promptRepresentation", "generatedContent",
    ]

    // MARK: - Extension Macro
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.kind == .structDecl else {
            throw MacroExpansionErrorMessage(
                "\(identifier) is only allowed on enums, structs, and classes."
            )
        }

        let ids = protocols.map({ $0.as(IdentifierTypeSyntax.self) }).map(
            \.?.name.identifier
        ).filter({ $0 != nil }).map({ $0! })

        guard !ids.isEmpty else {
            return []
        }

        guard
            let structDecl = Syntax(declaration).as(
                StructDeclSyntax.self
            )
        else {
            return []
        }

        var existingInits: [InitializerDeclSyntax] = []
        var initArguments: String = ""
        var initAssignments: String = ""

        for member in structDecl.memberBlock.members {
            switch member.decl.kind {
            case .initializerDecl:
                guard
                    let initDecl = Syntax(member.decl).as(
                        InitializerDeclSyntax.self
                    )
                else {
                    continue
                }
                existingInits.append(initDecl)
                continue
            case .variableDecl:
                guard
                    let variableSyntax = Syntax(member.decl).as(
                        VariableDeclSyntax.self
                    )
                else {
                    continue
                }

                let bindingSpec = variableSyntax.bindings.map({
                    (
                        $0.name,
                        $0.propertyBehavior(
                            modifiers: variableSyntax.modifiers
                        ), $0.propertyType,
                        $0.initializer
                    )
                })

                for (name, behavior, type, initializer) in bindingSpec {
                    if behavior == .static || behavior.isComputed {
                        continue
                    }
                    guard let name else {
                        continue
                    }
                    let type = type ?? bindingSpec.last?.2
                    if let type {
                        self.addInit(
                            currentArguments: &initArguments,
                            currentAssignments: &initAssignments,
                            name: name,
                            propertyType: type,
                            initializer: initializer
                        )
                    }
                }
            default:
                continue
            }
        }

        let initDecl = makeInitializers(
            existingInits: existingInits,
            initArguments: initArguments,
            initAssignments: initAssignments
        )

        return [
            try ExtensionDeclSyntax(
                """
                nonisolated extension \(type): GenerableEntity {
                    \(raw: initDecl)

                    static var typeDisplayRepresentation: TypeDisplayRepresentation {
                        TypeDisplayRepresentation(name: "\(raw: structDecl.name.trimmed)")
                    }

                    var displayRepresentation: DisplayRepresentation {
                        DisplayRepresentation(stringLiteral: "\(raw: structDecl.name.trimmed)")
                    }
                }
                """
            )
        ]
    }

    /// `public init() { }` is not necessary unless there is some existing initializers with non-empty signature outside of the extension
    private static func makeInitializers(
        existingInits: [InitializerDeclSyntax],
        initArguments: String,
        initAssignments: String = ""
    ) -> String {
        if existingInits.contains(where: { !$0.emptySignature }) {
            return "public init() { }"
        }

        /// add a initializer for existing parameters because
        /// wrapping a variable with `Property` will cause it not being able to be initialized like previously.
        if !initArguments.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        {
            return """
                public init(\(initArguments)) {
                    \(initAssignments)
                }
                """
        }

        return ""
    }

    // MARK: - MemberAttributeMacro
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [AttributeSyntax] {

        guard declaration.kind == .structDecl else {
            return []
        }

        switch member.kind {
        case .variableDecl:
            guard let variableSyntax = member.as(VariableDeclSyntax.self) else {
                return []
            }
            guard !IntentPropertyAttribute.exist(in: variableSyntax.attributes)
            else {
                return []
            }

            let bindingSpec = variableSyntax.bindings.map({
                (
                    $0.name,
                    $0.propertyBehavior(
                        modifiers: variableSyntax.modifiers
                    ), $0.propertyType,
                    $0.initializer
                )
            })

            guard let spec = bindingSpec.first else {
                return []
            }
            guard bindingSpec.count == 1 else {
                context.diagnose(
                    .init(
                        node: variableSyntax,
                        message: MacroExpansionWarningMessage(
                            """
                            App intent `@Property` can only apply to a single variable.
                            Without `@Property`, the variable will always be the default value when called by Siri.
                            """
                        )
                    )
                )
                return []
            }

            let (name, behavior, _, initializer) = spec
            
            if let name, self.skippedPropertyNames.contains(name) {
                return []
            }


            guard initializer == nil else {
                context.diagnose(
                    .init(
                        node: variableSyntax,
                        message: MacroExpansionWarningMessage(
                            """
                            App intent `@Property` does not support variables with initializer.
                            Without `@Property`, this variable will always be the default value when called by Siri.
                            """
                        )
                    )
                )
                return []
            }

            let propertyArg = buildPropertyArgument(name)
            let (identifier, message) = IntentPropertyAttribute.from(
                behavior: behavior
            )

            if let message {
                context.diagnose(.init(node: variableSyntax, message: message))
                return []
            }

            if let identifier {
                let syntax = "@\(identifier.identifier)(\(propertyArg))"
                return ["\(raw: syntax)"]
            }

            return []
        default:
            return []
        }

    }

    private static func buildPropertyArgument(_ variableName: String?) -> String
    {
        guard let variableName else { return "" }
        return "title: \"\(variableName)\""
    }

    private static func addInit(
        currentArguments: inout String,
        currentAssignments: inout String,
        name: String,
        propertyType: TypeSyntax,
        initializer: InitializerClauseSyntax?
    ) {
        if let initializer {
            currentArguments =
                """
                \(currentArguments)
                \(name): \(propertyType) \(initializer.trimmed),
                """
        } else {
            currentArguments =
                """
                \(currentArguments)
                \(name): \(propertyType),
                """
        }

        currentAssignments =
            """
            \(currentAssignments)
            self.\(name) = \(name)
            """
    }
}

extension FunctionSignatureSyntax {
    var emptySignature: Bool {
        guard
            let parameterClause = Syntax(self.parameterClause).as(
                FunctionParameterClauseSyntax.self
            )
        else {
            return true
        }
        return Syntax(parameterClause.parameters).as(
            FunctionParameterListSyntax.self
        )?.isEmpty ?? true
    }
}

extension InitializerDeclSyntax {
    var emptySignature: Bool {
        return Syntax(self.signature).as(
            FunctionSignatureSyntax.self
        )?.emptySignature ?? true
    }
}

extension AttributeListSyntax {
    func addedMacroCount(identifier: String) -> Int {
        return self.count(where: {
            $0.as(AttributeSyntax.self)?.attributeName.as(
                IdentifierTypeSyntax.self
            )?.name.identifier == identifier
        })
    }
}
