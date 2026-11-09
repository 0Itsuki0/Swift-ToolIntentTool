//
//  AddDebugDeclarationGroupMacro.swift
//  CodableX
//
//  Created by Itsuki on 2026/06/03.
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AddDebugMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [
            """
            static var groupDeclarationDescription: String {
                \(literal: declaration.debugDescription)
            }
            """,

            """
            static var nodeDescription: String {
                \(literal: node.debugDescription)
            }
            """,
            """
            static var contextDescription: String {
                \(literal: context.lexicalContext.isEmpty ? "(No Context Available)" : context.lexicalContext.map(\.debugDescription).joined(separator: "\n-------------\n"))
            }
            """,
        ]
    }

}
