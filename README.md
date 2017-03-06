# Swift For Flatbuffer
Unofficial Swift library and code generation for Flatbuffer

# Usage

## Build Flatbuffer From source

In the current source of flatbuffer, I have included the binary executable which was build under MacOS Sierra 10.12.3. If you're running flatbuffer on other platform you can recompile the code follow the official instruction on Flatbuffer site https://google.github.io/flatbuffers/flatbuffers_guide_building.html

## Generate Code from the schema

The sample of the schema was included in the XCode Project under FlatbufferUnitTest. If you wanna create your own schema, please visit Flatbuffer official site how to write Flatbuffer schema https://google.github.io/flatbuffers/flatbuffers_guide_writing_schema.html

To generate the code, run the following command

```
flatc --swift monster_test.fbs
```

To generate mutable code, run the following command

```
flatc --gen-mutable --swift monster_test.fbs
```

## Reading Flatbuffer data

In the current source code of Unit Test there is a binary file name "monsterdata_test.mon". You can include this file to your project.

Note that, you need to add swift file from Xcode project under sources (https://github.com/cmidt-veasna/SwiftFlatbuffer/tree/master/XCodeFlatbuffer/FlatbufferSwift/Sources). If you only attempted to read the Flatbuffer data then you can exclude the file "builder.swift" and "writer.swift"

#### Read data from the binary file

Initial Data object pointing to Flatbuffer binary file. This code is suppose run on MacOS, if you're running this code on iOS please adjust it accordingly.

```swift
let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "monsterdata_test", ofType: "mon")!
var data = try? Data(contentsOf: URL(fileURLWithPath: path), options: Data.ReadingOptions.alwaysMapped)
```

Access to Flatbuffer binary data

```swift
let monster = Monster.getRootAsMonster(withData: &data)
print(monster.hp)
print(monster.mana)
print(monster.name)
// accesss unsigned byte vector
for i in 0..<monster.inventoryCount {
    print(monster.inventory[i])
}
```

Access to Flatbuffer data with Object cache initialization. Note, this only prevent object from being create every time you access nested table or vector

every time the below code executed, it always create a new Instant of "Vec3" Struct

```swift
let pos = monster.pos
```

To reuse the Instant of "Vec3" Struct, use the below code

```swift
let pos = Vec3()
_ = monster.getPos(vec3: pos)
...
_ = monster1.getPos(vec3: pos)
```

As for vector, it's implemented with subscript which will be a little different, see the below code:

```swift
let monster1 = monster.testnestedflatbuffer[0]
let monster2 = monster.testnestedflatbuffer[1]
```

The monster1 and monster2 will be initialization as two different object but sharing the same data. To reuse the monster object and prevent initialization every time we access "testnestedflatbuffer", use the code below

```swift
let xmonster = Monster()
_ = monster.testnestedflatbuffer[0, xmonster]
...
_ = monster.testnestedflatbuffer[1, xmonster]
...
```

#### Mutable options

As describe by Flatbuffer, we can only update the value to existing Flatbuffer with Scalar type field. It's a bit different from other language as the code using properties setter which mean the setter will silence if the update was failed. This might be because of the properties does not exist in the binary buffer. Read more about forcing default from the following page https://google.github.io/flatbuffers/flatbuffers_guide_tutorial.html

```swift
monster.hp = 200
```

#### Build Flatbuffer binary data

The current code of Flatbuffer compiler for Swift did not provide any additional code wrapper to help simplify the binary build. See below code

```swift
let strOffset = try! builder.createString(with: "MyMonster")
_ = try? Monster.startMonster(builder)
try? Monster.addHp(builder, hp: 80)
try? Monster.addName(builder, nameOffset: strOffset)
let monsterOffset = try! Monster.endMonster(builder)
try? Monster.finishBuffer(builder, offset: monsterOffset)
// get final binary data
builder.getData()
```

## Xcode Test

To test Flatbuffer, open Xcode project, Set the active schema to "FlatbufferUnitTest" then hit Command + U

## Unsupported Feature

- Namespace

Swift does not support multiple namespace in the a module or project.

- Relection (&Resizing)

This feature is support in C++.

- JSON Parser

Currently not implemented.
