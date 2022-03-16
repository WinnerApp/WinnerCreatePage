//
//  Common.swift
//  
//
//  Created by admin on 2022/3/16.
//

import Foundation
import ArgumentParser
import SwiftShell

func getEnvironment(name:String) throws -> String {
    guard let value = ProcessInfo.processInfo.environment[name] else {
        print("获取 \(name) 值")
        throw ExitCode.failure
    }
    return value
}

func checkIsFlutterDir() throws {
    let pwd = try getEnvironment(name: "PWD")
    let dartToolPath = "\(pwd)/.dart_tool"
    var isDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: dartToolPath, isDirectory: &isDirectory), isDirectory.boolValue else {
        print("当前不是一个Flutter项目或者不在主目录")
        throw ExitCode.failure
    }
}

func getCreateName(name:String) -> String {
    return name.components(separatedBy: "_")
        .map({$0.capitalized})
        .joined(separator: "")
}

func getKeyName(name:String) -> String {
    var names = name.components(separatedBy: "_")
    guard names.count > 1 else {
        return name
    }
    let first = names.removeFirst()
    names = names.map({$0.capitalized})
    names.insert(first, at: 0)
    return names.joined(separator: "")
}

func getReadLine(from list:[String], tip:String) throws -> Int {
    guard !list.isEmpty else {
        throw ExitCode.failure
    }
    print(tip)
    for element in list.enumerated() {
        print("\(element.offset) \(element.element)")
    }
    guard let value = readLine(),
          let index = Int(value),
          index >= 0, index < list.count else {
        throw ExitCode.failure
    }
    return index
}

func checkDirExit(dir:String, isDir:Bool = true) -> Bool {
    var isDirectory = ObjCBool(false)
    return FileManager.default.fileExists(atPath: dir,
                                          isDirectory: &isDirectory)
    && isDirectory.boolValue == isDir
}

func createContext() -> CustomContext {
    var context = CustomContext()
    context.env = ProcessInfo.processInfo.environment
    return context
}

func getPasteText() -> String {
    let context = createContext()
    let command = context.runAsync("pbpaste")
    command.resume()
    return command.stdout.read()
}

func getTypeName(from value:Any) throws -> String {
    if value is Int {
        return "int"
    } else if value is Double {
        return "double"
    } else if value is String {
        return "String"
    } else if let list = value as? [Any], let first = list.first {
        return "List<\(try getTypeName(from: first))>"
    }
    print("\(type(of: value))类型没有解析，请联系开发者。")
    throw ExitCode.failure
}

func getTypeDefault(from name:String) throws -> String {
    if name == "int" {
        return "0"
    } else if name == "double" {
        return "0"
    } else if name == "String" {
        return """
        ''
        """
    } else if name.contains("List") {
        return "[]"
    }
    print("\(type(of: name))类型没有默认值，请联系开发者。")
    throw ExitCode.failure
}
