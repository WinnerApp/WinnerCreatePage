//
//  ModelCommand.swift
//  
//
//  Created by admin on 2022/3/16.
//

import Foundation
import ArgumentParser

class ModelCode: Decodable {
    var modelClassCodes:[String] = []
    var modelGCode:[String] = []
}

private var codes:ModelCode = ModelCode()

/// 生成模型
struct ModelCommand: ParsableCommand {
    
    static var configuration: CommandConfiguration {
        .init(commandName:"model", abstract: "快速生成模型")
    }
    
    @Argument(help:"模型名称 比如 user_login_response")
    var name:String
    
    @Flag(name: .short, help:"是否强制重写")
    var force:Bool = false
        
    func run() throws {
        /// 读取模型的JSON内容
        let jsonText = getPasteText()
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw ExitCode.failure
        }
        guard let json = try? JSONSerialization.jsonObject(with: jsonData,
                                                           options: .fragmentsAllowed) else {
            print("剪贴板内容:\n" + jsonText + "\n不能被JSON解析")
            throw ExitCode.failure
        }
        try parseRoot(json: json)
    }
    
    func parseRoot(json:Any) throws {
        if let jsonObject = json as? [String:Any] {
            /// 检测是否是最外层的模型
            if jsonObject.keys.contains("code"),
               jsonObject.keys.contains("message"),
               jsonObject.keys.contains("data") {
                guard let data = jsonObject["data"] else {
                    throw ExitCode.failure
                }
                try parseRoot(json: data)
            } else {
                try generateCode(rootObject: jsonObject)
            }
        } else if let jsonList = json as? [Any],
                  let first = jsonList.first as? [String:Any]{
            try generateCode(rootObject: first)
        } else {
            print("\(json)不是一个 JSON 字符串")
            throw ExitCode.failure
        }
    }
    
    func generateCode(rootObject:[String:Any]) throws  {
        var modelCode = """
        import 'package:json_annotation/json_annotation.dart';

        part '\(name).g.dart';
        """
        let modelName = getCreateName(name: name)
        
        let contentCode = try generateModelCode(root: true,
                                            name: modelName,
                                            object: rootObject)
        codes.modelClassCodes.append(contentCode)
        let classCodes = codes.modelClassCodes.reversed()
        for classCode in classCodes {
            modelCode += """
            \n\(classCode)\n
            """
        }
    
//        print(modelCode)
        
        let _gCode = generageGCode(name: getCreateName(name: name))
        codes.modelGCode.append(_gCode)
        
        var gCode = """
        part of '\(name).dart';\n
        """
        let gCodes = codes.modelGCode.reversed()
        for code in gCodes {
            gCode += """
            \(code)
            """
        }
//        print(gCode)
        let pwd = try getEnvironment(name: "PWD")
        let lib = pwd + "/lib"
        guard checkDirExit(dir: lib) else {
            print("\(lib)不存在")
            throw ExitCode.failure
        }
        let model = lib + "/model"
        var context = createContext()
        if !(checkDirExit(dir: model)) {
            context.currentdirectory = lib
            try context.runAndPrint("mkdir", "model")
        }
        context.currentdirectory = model
        let modelFile = model + "/\(name).dart"
        if checkDirExit(dir: modelFile, isDir: false), !force {
            print("\(modelFile)已经存在 可以使用 -f 参数强制重写")
            throw ExitCode.failure
        } else {
            try modelCode.write(toFile: modelFile,
                                atomically: true,
                                encoding: .utf8)
        }
        let modelGFile = model + "/\(name).g.dart"
        if checkDirExit(dir: modelGFile, isDir: false), !force {
            print("\(modelGFile)已经存在 可以使用-f重写")
            throw ExitCode.failure
        } else {
            try gCode.write(toFile: modelGFile,
                            atomically: true,
                            encoding: .utf8)
        }
        context.currentdirectory = pwd
        try context.runAndPrint("flutter","pub","run","build_runner","build","--delete-conflicting-outputs")
        print("\(name)模型代码生成成功")
    }
    
    func generateModelCode(root:Bool,
                           name:String,
                           object:[String:Any]) throws -> String {
        var code = """
        """
        code += """
        @JsonSerializable(explicitToJson: true)\n
        """
        if root {
            code += """
            class \(name) extends JsonConverter<\(name), Map<String, dynamic>> {
            """
        } else {
            code += """
            class \(name) {
            """
        }
        let keys = object.keys
        for key in keys {
            let keyName = getKeyName(name: key)
            guard let value = object[key] else {
                throw ExitCode.failure
            }
            if value is NSNull {
                continue
            }
            let typeName:String
            let defaultValue:String
            if let value = value as? [String:Any] {
                /// 如果是一个字段
                let childrenName = name + getCreateName(name: key)
                let content = try generateModelCode(root: false,
                                                    name: childrenName,
                                                    object: value)
                codes.modelClassCodes.append(content)
                codes.modelGCode.append(generageGCode(name: childrenName))
                defaultValue = "\(childrenName)()"
                typeName = "\(childrenName)"
                
            } else if let value = value as? [[String:Any]] {
                
                guard let first = value.first else {
                    continue
                }
                /// 如果是一个字段
                let childrenName = name + getCreateName(name: key)
                let content = try generateModelCode(root: false,
                                                    name: childrenName,
                                                    object: first)
                codes.modelClassCodes.append(content)
                codes.modelGCode.append(generageGCode(name: childrenName))
                defaultValue = "[]"
                typeName = "List<\(childrenName)>"
            } else {
                typeName = try getTypeName(from: value)
                defaultValue = try getTypeDefault(from: typeName)
            }
            let defaultValueCode:String = value is [String:Any] ? "" : "defaultValue: \(defaultValue)"
            let jsonKeyName:String = keyName == key ? "" : "name: '\(key)'"
            if defaultValueCode.isEmpty, jsonKeyName.isEmpty {
                code += """
                  \n
                  \(typeName)? \(keyName);
                """
            } else {
                var jsonKeyCodes:[String] = []
                if !jsonKeyName.isEmpty {
                    jsonKeyCodes.append(jsonKeyName)
                }
                if !defaultValueCode.isEmpty {
                    jsonKeyCodes.append(defaultValueCode)
                }
                code += """
                  \n
                  @JsonKey(\(jsonKeyCodes.joined(separator: ",")))
                  late \(typeName) \(keyName);
                """
            }
        }
        code += """
        \n
          \(name)();
        """
        if root {
            code += """
              \n
              @override
              \(name) fromJson(Map<String, dynamic> json) {
                  return _$\(name)FromJson(json);
              }
            """
        } else {
            code += """
              \n
              factory \(name).fromJson(Map<String, dynamic> json) => _$\(name)FromJson(json);
            """
        }
        var override = ""
        if (root) {
            override = "@override"
        }
        code += """
          \n
          \(override)
          Map<String, dynamic> toJson() {
              return _$\(name)ToJson(this);
          }
        
        }
        """
        return code
    }
    
    func generageGCode(name:String) -> String {
        return """
        \(name) _$\(name)FromJson(Map<String, dynamic> json) => \(name)();
        Map<String, dynamic> _$\(name)ToJson(\(name) instance) => {};\n
        """
    }
}
