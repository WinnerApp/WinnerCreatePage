//
//  ApiCommand.swift
//  
//
//  Created by admin on 2022/3/16.
//

import Foundation
import ArgumentParser

/// 创建接口
struct ApiCommand: ParsableCommand {
    
    static var configuration: CommandConfiguration {
        .init(commandName:"api", abstract: "创建接口代码")
    }
    
    @Argument(help:"接口的名字 比如 user_login 会创建 user_login_api.dart")
    var name:String
    
    @Flag(name: .short, help: "是否重写?")
    var force: Bool = false
    
    func run() throws {
        let pwd = try getEnvironment(name: "PWD")
        print(pwd)
        try checkIsFlutterDir()
        print("请输入接口路径:")
        guard let path = readLine() else {
            throw ExitCode.failure
        }
        let apiPath = "\(pwd)/lib/api"
        if checkDirExit(dir: apiPath) {
            /// 获取目前所有的接口文件
            let contents = try FileManager.default.contentsOfDirectory(atPath: apiPath)
            for content in contents {
                guard content != ".DS_Store"  else {
                    continue
                }
                let filePath = "\(apiPath)/\(content)"
                /// 获取文件内容
                let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
                let pathContent = """
                "\(path)"
                """
                /// 查询当前的接口路径是否存在
                guard !fileContent.contains(pathContent) else {
                    print("\(path) 已经存在于\(filePath)中")
                    throw ExitCode.failure
                }
            }
        } else {
            var context = createContext()
            context.currentdirectory = "\(pwd)/lib"
            try context.runAndPrint("mkdir", "api")
        }
        let methods = ["GET","POST"]
        let methodIndex = try getReadLine(from: methods, tip: "请输入请求方式:")
        let responseTypes = [
            "void","int","double","String","num","bool","JSON"
        ]
        let responseTypeIndex = try getReadLine(from: responseTypes, tip: "请选择返回类型:")
        let responseType = responseTypes[responseTypeIndex]
        let converter:String
        let modelName:String
        let className = getCreateName(name: createName)
        if responseType == "JSON" {
            converter = className + "Response"
            ModelCommand.main(["\(createName)_response", "-f"])
            modelName = converter
        } else {
            converter = "DefaultJsonConverter<\(responseType)>"
            modelName = responseType
        }
        let apiContent = """
        import 'package:flutter_winner_app/flutter_winner_app.dart';
        
        \(classHeader(name: className, converter: converter, model: modelName))
        
        \(classConverter(converter: converter))
        
        \(classModel(model: modelName))
        
        \(classPath(path: path))
        
        \(classMethod(method: methods[methodIndex]))
        
        }
        """
        let libPath = pwd + "/lib"
        guard checkDirExit(dir: libPath) else {
            print(libPath + "不存在")
            throw ExitCode.failure
        }
        var context = createContext()
        if !checkDirExit(dir: apiPath) {
            context.currentdirectory = libPath
            try context.runAndPrint("mkdir", "api")
        }
        let apiFile = apiPath + "/\(createName)_api.dart"
        if FileManager.default.fileExists(atPath: apiFile), !force {
            print("\(apiFile) 已经存在，如果想重写请带上 -f 参数")
            return
        }
        try apiContent.write(toFile: apiFile,
                             atomically: true,
                             encoding: .utf8)
    }
    
    func classHeader(name:String, converter:String, model:String) -> String {
        return """
        
        typedef \(name)Api = _Api;
        typedef _Response = \(model);
        typedef _Converter = \(converter);
        typedef _Model = AppModel<_Response>;
        
        class _Api extends Api<_Converter, _Model> {
        """
    }
    
    func classConverter(converter:String) -> String {
        return """
          @override
          _Converter get converter => _Converter();
        """
    }
    
    func classPath(path:String) -> String {
        return """
          @override
          String get path => "\(path)";
        """
    }
    
    func classMethod(method:String) -> String {
        return """
          @override
          String get method => '\(method)';
        """
    }
    
    func classModel(model:String) -> String {
        return """
          @override
          _Model get model => _Model();
        """
    }
    
    var createName: String { humpTurnedUnderline(name: name) }
}


