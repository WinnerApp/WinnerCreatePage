//
//  PageCommand.swift
//  
//
//  Created by admin on 2022/3/9.
//

import Foundation
import ArgumentParser
import SwiftShell

struct PageCommand: ParsableCommand {
    
    static var configuration: CommandConfiguration {
        .init(commandName:"page")
    }
    
    @Argument(help:"页面文件夹名称,小些下划线拼接，比如my_order")
    var name:String
    func run() throws {
        /// 获取当前运行的路径
        guard let pwd = ProcessInfo.processInfo.environment["PWD"] else {
            print("获取不到当前路径PWD的值")
            throw ExitCode.failure
        }
        print(pwd)
        let dartToolPath = "\(pwd)/.dart_tool"
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: dartToolPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            print("当前不是一个Flutter项目或者不在主目录")
            throw ExitCode.failure
        }
        var currentdirectory = "\(pwd)/lib/page"
        SwiftShell.main.currentdirectory = currentdirectory
        /// 创建对应目录
        try runAndPrint("mkdir", name)
        currentdirectory += "/\(name)"
        SwiftShell.main.currentdirectory = currentdirectory
        let names = name.components(separatedBy: "_")
        let crateName = names.map({$0.capitalized}).joined(separator: "")
        let pageContent = pageContent(name: crateName, pathName: name)
        /// 创建Page文件
        FileManager.default.createFile(atPath: "\(currentdirectory)/\(name)_page.dart",
                                           contents: pageContent.data(using: .utf8),
                                           attributes: nil)
        /// 创建 ViewModel
        try runAndPrint("mkdir", "view_model")
        currentdirectory += "/view_model"
        
        let viewModelContent = """
        import 'package:flutter_winner_app/flutter_winner_app.dart';

        class \(crateName)PageViewModel extends BaseViewModel {}
        """
        FileManager.default.createFile(atPath: "\(currentdirectory)/\(name)_page_view_model.dart",
                                       contents: viewModelContent.data(using: .utf8),
                                       attributes: nil)
    }
    
    func pageContent(name:String, pathName:String) -> String {
        return """
        import 'package:flutter/material.dart';
        import 'package:flutter_winner_app/flutter_winner_app.dart';
        import 'package:flutter_winner_pda/page/\(pathName)/view_model/\(pathName)_page_view_model.dart';

        class \(name)Page extends StatefulWidget {
          const \(name)Page({Key? key}) : super(key: key);

          @override
          State<\(name)Page> createState() => _\(name)PageState();
        }

        class _\(name)PageState extends BasePage<\(name)Page, \(name)PageViewModel> {
          @override
          Widget buildPage(BuildContext context) {
            return Container();
          }

          @override
          \(name)PageViewModel create() {
            return \(name)PageViewModel();
          }
        }
        """
    }
}
