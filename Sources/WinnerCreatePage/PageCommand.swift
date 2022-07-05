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
        .init(commandName:"page", abstract: "快速创建页面模版")
    }
    
    @Argument(help:"页面文件夹名称,小些下划线拼接，比如my_order")
    var name:String
    
    @Flag(name: .short, help: "是否重写存在的页面?")
    var force: Bool = false
    
    func run() throws {
        /// 获取当前运行的路径
        let pwd = try getEnvironment(name: "PWD")
        print(pwd)
        try checkIsFlutterDir()
        var currentdirectory = "\(pwd)/lib/page"
        SwiftShell.main.currentdirectory = currentdirectory
        /// 创建对应目录
        try runAndPrint("mkdir", name)
        currentdirectory += "/\(name)"
        SwiftShell.main.currentdirectory = currentdirectory
        let crateName = getCreateName(name: name)
        let pageContent = pageContent(name: crateName, pathName: name)
        let pageFile = "\(currentdirectory)/\(name)_page.dart"
        if FileManager.default.fileExists(atPath: pageFile), !force {
            print("\(pageFile)已经存在，重写请添加 -f 参数")
            return
        }
        /// 创建Page文件
        FileManager.default.createFile(atPath: pageFile,
                                           contents: pageContent.data(using: .utf8),
                                           attributes: nil)
        /// 创建 ViewModel
        try runAndPrint("mkdir", "view_model")
        currentdirectory += "/view_model"
        
        let viewModelContent = """
        import 'package:flutter_winner_app/flutter_winner_app.dart';

        class \(crateName)PageViewModel extends BaseViewModel {}
        """
        let viewModelPath = "\(currentdirectory)/\(name)_page_view_model.dart"
        if FileManager.default.fileExists(atPath: viewModelPath), !force {
            print("\(viewModelPath)已经存在，重写请添加 -f 参数")
            return
        }
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
