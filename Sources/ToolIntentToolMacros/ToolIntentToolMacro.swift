import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct ToolIntentToolPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AddDebugMacro.self,
        ToolToIntentMacro.self,
        GenerableToGenerableMacro.self,
        EnumToAppEnumMacro.self,
    ]
}
