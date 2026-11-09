import AppIntents
import FoundationModels
import ToolIntentTool

//print(String(describing: Prompt { "test" }))

//print(
//    String(
//        describing: Arguments().promptRepresentation
//    )
//)

@Debug
struct Test {
    typealias Output = GreetingTool.Output

    var test: String {
        get async {
            return ""
        }
    }

//    @EnumToAppEnum
    enum GenerableEnum: Int {
        case hello
        case hey
    }

    //    @GenerableToGenerable
    struct Arguments {
        @Guide(description: "The name to greet")
        var name: String

        var nameGet: String {
            return name
        }

        //        @DeferredProperty
        var nameGetAsync: String {
            get async throws {
                name
            }
        }

    }
}

@Debug
@Generable
@GenerableToGenerable
struct Arguments {
    @Guide(description: "The name to greet")
    var name: String

    var nameGet: String {
        return name
    }

    var nameGetAsync: String {
        get async throws {
            name
        }
    }
    
//    init(name: String) {
//        self.name = name
//    }
//    
//    init() {
//        self.name = ""
//    }
}


@Debug
@Generable
//@EnumToAppEnum
enum GenerableEnum: Int {
    case hello
    case hey
}


@Debug
@ToolToIntent
struct GreetingTool: Tool {

    let name = "greet"
    let description = "grett me!s"

    @Generable
    @GenerableToGenerable
    struct Arguments {
        @Guide(description: "The name to greet")
        var name: String
    }

    //    @Parameter(
    //        title: .init(
    //            stringLiteral: "\(Arguments.typeDisplayRepresentation.name) input"
    //        )
    //    )
    //    var input: Arguments

    @GenerableToGenerable
    struct Output: PromptRepresentable {
        @Guide(description: "The result")
        var result: String
        
        var promptRepresentation: Prompt {
            Prompt { result }
        }
    }

    func call(arguments: Arguments) async throws -> Output {
        print("Tool[\(name)] called with arguments: \(arguments)")
//        return "Hello \(arguments.name)"
        //        return .init(kind: .string("Hello, \(arguments.name)"))
        return Output(result: "Hello \(arguments.name)")
    }
}

//print("" is (any _IntentValue))
//print(["": "Test"] is (any _IntentValue))
//print(GreetingTool.Arguments(name: "test") is (any _IntentValue))
let out = 123

@Debug
struct DeclTest {
    let name = "123" + "\(out)"
    var getName: String {
        "123" + "456"
    }
    var getName2: String {
        return "123"
    }
    var getName3: String {
        get {
            return "123"
        }
    }
    let int = 123
    let vari = out
}

print(GreetingTool.groupDeclarationDescription)
