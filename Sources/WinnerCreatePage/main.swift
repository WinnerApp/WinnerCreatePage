
import ArgumentParser
import Foundation
import SwiftShell
struct WinnerCreatePage: ParsableCommand {
    
    static var configuration: CommandConfiguration {
        return CommandConfiguration(subcommands:[PageCommand.self],
                                    defaultSubcommand: PageCommand.self)
    }

    
    func run() throws {
        
        PageCommand.main()
    }

}

WinnerCreatePage.main()
