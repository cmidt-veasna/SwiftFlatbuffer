//
//  File.swift
//  FlatbufferSwift
//
//  Created by Veasna Sreng on 2/14/17.
//
//

import Foundation

// Data extension helper

extension Data {
    
    public func get<T>(at: Int, withType: T.Type) -> T? {
        let numberOfByte = at + MemoryLayout<T>.stride
        if count <= numberOfByte || numberOfByte < 1 {
            return nil
        }
        // TODO: investigate this option. Which cause memory allocation increate as it seem no deallocation has been perform
        return withUnsafeBytes {
            (ptr: UnsafePointer<T>) -> T in return ptr.advanced(by: (at/MemoryLayout<T>.stride)).pointee
        }
    }
    
    public func getInteger<T: Integer>(at: Int) -> T {
        let numberOfByte = at + MemoryLayout<T>.stride
        if count <= numberOfByte || numberOfByte < 1 {
            return 0
        }
        let copyCount = MemoryLayout<T>.stride
        var bytes: [UInt8] = [UInt8](repeating: 0, count: copyCount)
        copyBytes(to: &bytes, from: at ..< Data.Index(at + copyCount))
        return UnsafePointer(bytes).withMemoryRebound(to: T.self, capacity: 1) {
            $0.pointee
        }
    }
    
    public func getFloatingPoint<T: FloatingPoint>(at: Int) -> T {
        let numberOfByte = at + MemoryLayout<T>.stride
        if count <= numberOfByte || numberOfByte < 1 {
            return 0
        }
        let copyCount = MemoryLayout<T>.stride
        var bytes: [UInt8] = [UInt8](repeating: 0, count: copyCount)
        copyBytes(to: &bytes, from: at ..< Data.Index(at + copyCount))
        return UnsafePointer(bytes).withMemoryRebound(to: T.self, capacity: 1) {
            $0.pointee
        }
    }
    
    public func getByte(at: Int) -> Int8 {
        return getInteger(at: at)
    }
    
    public func getUnsignedByte(at: Int) -> UInt8 {
        return getInteger(at: at)
    }

    public func getShort(at: Int) -> Int16 {
        return getInteger(at: at)
    }
    
    public func getUsignedShort(at: Int) -> UInt16 {
        return getInteger(at: at)
    }
    
    public func getInt(at: Int) -> Int32 {
        return getInteger(at: at)
    }
    
    public func getUnsignedInt(at: Int) -> UInt32 {
        return getInteger(at: at)
    }
    
    public func getLong(at: Int) -> Int64 {
        return getInteger(at: at)
    }

    public func getUnsignedLong(at: Int) -> UInt64 {
        return getInteger(at: at)
    }
    
    public func getVirtualTaleOffset(at: Int) -> Int {
        return Int(getShort(at: at))
    }
    
    public func getOffset(at: Int) -> Int {
        return Int(getInt(at: at))
    }
    
    public func getFloat(at: Int) -> Float {
        return getFloatingPoint(at: at)
    }
    
    public func getDouble(at: Int) -> Double {
        return getFloatingPoint(at: at)
    }
    
    public func getArray(at: Int, count: Int, withType: UInt8.Type) -> [UInt8]? {
        var bytes: [UInt8] = [UInt8](repeating: 0, count: count)
        copyBytes(to: &bytes, from: at ..< Data.Index(at + count))
        return bytes
    }
  
}

// String helper to extract Character by index of a string

extension String {
    
    subscript (i: Int) -> Character {
        return self[self.characters.index(self.startIndex, offsetBy: i)]
    }

}
