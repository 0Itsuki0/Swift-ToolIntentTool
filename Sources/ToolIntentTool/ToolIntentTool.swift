import AppIntents

@attached(
    member,
    names: named(groupDeclarationDescription),
    named(contextDescription),
    named(nodeDescription)
)
public macro Debug() =
    #externalMacro(module: "ToolIntentToolMacros", type: "AddDebugMacro")

/// `ToolToIntent`
/// Generate necessary conformance and parameters for an AppIntent ToolIntent
@attached(
    extension,
    conformances: ToolIntent,
    names: named(perform()),
    named(title),
    named(description)
)
@attached(
    member,
    names: named(input_ToolIntentTool)
)
public macro ToolToIntent() =
    #externalMacro(module: "ToolIntentToolMacros", type: "ToolToIntentMacro")

/// `GenerableToGenerable`
/// Generate necessary conformance and parameters for an AppIntent GenerableEntity.
@attached(memberAttribute)
@attached(
    extension,
    conformances: GenerableEntity,
    names: named(displayRepresentation),
    named(typeDisplayRepresentation),
    named(init()),
    arbitrary
)
public macro GenerableToGenerable() =
    #externalMacro(
        module: "ToolIntentToolMacros",
        type: "GenerableToGenerableMacro"
    )

// MARK: - Enum
// Disabled for now because AppEnum refuses (compiler error) typeDisplayRepresentation or caseDisplayRepresentations when they are from macro expansion.
// Only happens when import the Macro Package from other apps.
// No error when build in the client because the client never runs the ExtractAppIntentsMetadata step
//
//@attached(
//    extension,
//    conformances: AppEnum,
//    names: named(caseDisplayRepresentations),
//    named(typeDisplayRepresentation)
//)
//public macro EnumToAppEnum() =
//    #externalMacro(
//        module: "ToolIntentToolMacros",
//        type: "EnumToAppEnumMacro"
//    )
