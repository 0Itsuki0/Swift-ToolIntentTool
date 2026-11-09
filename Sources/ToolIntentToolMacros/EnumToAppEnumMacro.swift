//
//  EnumToAppEnumMacro.swift
//  ToolIntentTool
//
//  Created by Itsuki on 2026/11/08.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct EnumToAppEnumMacro: ExtensionMacro {
    static let identifier = "EnumToAppEnum"

    // MARK: - Extension Macro
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.kind == .enumDecl else {
            throw MacroExpansionErrorMessage(
                "\(identifier) is only allowed on enums."
            )
        }

        let ids = protocols.map({ $0.as(IdentifierTypeSyntax.self) }).map(
            \.?.name.identifier
        ).filter({ $0 != nil }).map({ $0! })

        guard !ids.isEmpty else {
            return []
        }

        guard
            let enumDecl = Syntax(declaration).as(
                EnumDeclSyntax.self
            )
        else {
            return []
        }

        var caseDisplayRepresentations: [TokenSyntax: String] = [:]

        for member in enumDecl.memberBlock.members {
            switch member.decl.kind {
            case .enumCaseDecl:
                guard
                    let enumSyntax = Syntax(member.decl).as(
                        EnumCaseDeclSyntax.self
                    )
                else {
                    continue
                }

                let elementNames = enumSyntax.elements.map({
                    $0.name
                })

                elementNames.forEach { name in
                    caseDisplayRepresentations[name] = "\"\(name)\""

                }
            default:
                continue
            }
        }

        var caseDisplay = caseDisplayRepresentations.map {
            ".\($0.key): \($0.value)"
        }.joined(separator: ",\n")

        if caseDisplay.isEmpty {
            caseDisplay = ":"
        }

        return [
            try ExtensionDeclSyntax(
                """
                extension \(type): \(raw: ids.joined(separator: ",")) {
                    static let typeDisplayRepresentation: TypeDisplayRepresentation = "\(enumDecl.name.trimmed)"
                    static let caseDisplayRepresentations: [\(type): DisplayRepresentation] = [\(raw: caseDisplay)]
                }
                """
            )
        ]
    }
}
