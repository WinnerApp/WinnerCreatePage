
import ArgumentParser
import Foundation
import SwiftShell
struct WinnerCreatePage: ParsableCommand {
    
    static var configuration: CommandConfiguration {
        return CommandConfiguration(subcommands:[
            PageCommand.self,
            ApiCommand.self,
            ModelCommand.self,
        ],
                                    defaultSubcommand: PageCommand.self)
    }

    
    func run() throws {
        PageCommand.main()
    }

}

//print(ProcessInfo.processInfo.environment)
WinnerCreatePage.main()
