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
    
    @Option(help: "从对应语言类型解析")
    var code: FromCodeLanguage?
        
    func run() throws {
        
        /// 读取模型的JSON内容
        let jsonText = getPasteText()
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw ExitCode.failure
        }
        if let code = code {
            if code == .kotlin {
                try parseFromKotlin(text: jsonText)
                return;
            }
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
              factory \(name).fromJson(Map<String, dynamic> json) {
                  return _$\(name)FromJson(json);
              }
            """
        }
        var override = ""
        if (root) {
            override = "@override"
        }
        if root {
            code += """
              \n
              \(override)
              Map<String, dynamic> toJson(\(name) object) {
                  return _$\(name)ToJson(object);
              }
            
            }
            """
        } else {
            code += """
              \n
              \(override)
              Map<String, dynamic> toJson() {
                  return _$\(name)ToJson(this);
              }
            
            }
            """
        }
        return code
    }
    
    func generageGCode(name:String) -> String {
        return """
        \(name) _$\(name)FromJson(Map<String, dynamic> json) => \(name)();
        Map<String, dynamic> _$\(name)ToJson(\(name) instance) => {};\n
        """
    }
    
    func parseFromKotlin(text: String) throws {
        let propertyTexts = text.components(separatedBy: "\n").map({$0.replacingOccurrences(of: "var", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "?", with: "")})
        var map:[String:Any] = [:]
        for var propertyText in propertyTexts {
            let splits = propertyText.components(separatedBy: "/")
            guard splits.count > 0 else {
                throw ExitCode.failure
            }
            propertyText = splits[0]
            if propertyText.isEmpty {
                continue
            }
            let splits2 = propertyText.components(separatedBy: ":")
            guard splits2.count == 2 else {
                continue
            }
            let name = splits2[0]
            let type = splits2[1]
            
//            print("\(splits2[0]) \(splits2[1])")

            if type == "String" {
                map[name] = ""
            } else if type == "Int" || type == "Long" {
                map[name] = 0
            } else if type == "Boolean" {
                map[name] = true
            } else if type == "Array<Long>" {
                map["name"] = [2]
            } else {
                print("未识别类型 \(type)")
                throw ExitCode.failure
            }
        }
        try parseRoot(json: map)
    }
}

enum FromCodeLanguage: String, ExpressibleByArgument {
    case kotlin
}

let kotlin = """
    var agingDate: String,
    var assignedUser: String,
    var attributeEight: String,
    var attributeFive: String,
    var attributeFour: String,
    var attributeId: String,
    var attributeOne: String,
    var attributeSeven: String,
    var attributeSix: String,
    var attributeThree: String,
    var attributeTwo: String,
    var showAttributeOne:String,
    var showAttributeTwo:String,
    var batch: String,
    var commodityCode: String,
    var commodityName: String,
    var conversionQty: String, //箱含量
    var companyCode: String,
    var confirmedAt: String,
    var confirmedBy: String,
    var convertedQty: String,//单位数量
    var convertedQtyUm: String,//单位
    var createBy: String,
    var createTime: String,
    var csQty: String,
    var currentLoc: String,
    var currentLpn: String,
    var expirationDate: String,
    var finishRebatch: String,
    var fromInventoryId: Int,
    var fromLoc: String,
    var fromLpn: String,
//    var fromQty: Double,
    var fromQty: Int,
    var fromZone: String,
    var groupIndex: Int,
    var groupNum: Int,
    var id: Long,// 主键id
    var inTransitLocked: Int,
    var internalTaskType: String,//任务类型
    var inventorySts: String,
    var lot: String,
    var manufactureDate: String,
    var packingCode: String,
    var pickDropLoc: String,
    var pickingCartCode: String,
    var pickingCartPos: String,//拣选车位置号
    var plQty: String,
    var rebinShortQty: String,
    var referenceCode: String,
    var referenceContCode: String,//参考箱号
    var referenceContId: String,// 参考箱内部号
    var referenceId: String,
    var referenceLineId: String,
    var referenceReqId: Int,
    var shelfLifeSts: String,
    var showCompanyCode: String,
    var showConvertedQtyUm: String,
    var status: Int,
    var taskCode: String,//任务号
    var taskId: Int,//头部ID
    var taskType: String,// 任务类型
    var toInventoryId: String,
    var toLoc: String,
    var toLpn: String,
//    var toQty: Double,
    var toQty: Int,
    var toZone: String,
//    var totalQty: Double,
    var totalQty: Int,
    var transContCode: String,
    var unitQty: Int,//单位规格
    var updatedBy: String,
    var updatedTime: String,
    var userDef: String,
    var version: Int,
    var waveId: Int,
    var putawayByPiece:Int,//  逐件上架 1开启 0关闭
    var pickByPiece:Int,//逐件拣货  1开启 0关闭
    var verifyItem:Int,//验证货品
    var verifyLocation:Int,//验证库位
    var verifyQuantity:Int,//验证数量
    var verifyShipCont:Int,//校验组车位置号
    var verifyLpn:Int,//验证托盘号
    var verifyCartPos:Int,//验证出库箱
    var allowOverpick:Int,
    var allowOverridePutaway:Int,//是否允许 上架覆盖
    var whCode: String,
    var tempQuality:Int, //逐件拣货/上架用的临时数量
    var showAttribute:Boolean,
    var tdList:Array<Long>?,
"""
