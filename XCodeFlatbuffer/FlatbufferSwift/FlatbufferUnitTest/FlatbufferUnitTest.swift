//
//  FlatbufferUnitTest.swift
//  FlatbufferUnitTest
//
//  Created by Veasna Sreng on 3/3/17.
//
//

import XCTest

class FlatbufferUnitTest: XCTestCase {
    
    private var data: Data?
    
    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: type(of: self))
        let path = bundle.path(forResource: "monsterdata_test", ofType: "mon")!
        self.data = try? Data(contentsOf: URL(fileURLWithPath: path), options: Data.ReadingOptions.alwaysMapped)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // Test reading binary file
    func testData() {
        FlatbufferUnitTest._testData(data: &self.data!)
    }
    
    func testBuilder() {
        let builder = Builder(capacity: 1024)
        
        let sortOffset = FlatbufferUnitTest._builderMonster(builder)
        // Write the result to a file for debugging purposes:
        // Note that the binaries are not necessarily identical, since the JSON
        // parser may serialize in a slightly different order than the above
        // Java code. They are functionally equivalent though.
        
        var data = try? builder.getData()
        try? data?.write(to: URL(fileURLWithPath: "monsterdata_test_swift.mon"))
        
        FlatbufferUnitTest._testExtendedBuffer(data: &data!)
        //
        FlatbufferUnitTest._testMutatedData(data: &data!, sort: sortOffset)
    }
    
    func testEnum() {
        XCTAssertEqual(Color.Red.rawValue, 1)
        XCTAssertEqual(Color.Green.rawValue, 2)
        XCTAssertEqual(Color.Blue.rawValue, 8)
        XCTAssertEqual(AnySwift.NONE.rawValue, 0)
        XCTAssertEqual(AnySwift.Monster.rawValue, 1)
        XCTAssertEqual(AnySwift.TestSimpleTableWithEnum.rawValue, 2)
        XCTAssertEqual(AnySwift.MyGame_Example2_Monster.rawValue, 3)
    }
    
    func testNestedFlatBuffer() {
        let nestedMonsterName = "NestedMonsterName"
        let nestedMonsterHp = Int16(600)
        let nestedMonsterMana = Int16(1024)
        
        let builder = Builder(capacity: 16)
        let nameOffset = try! builder.createString(with: nestedMonsterName)
        try? Monster.startMonster(builder)
        try? Monster.addName(builder, nameOffset: nameOffset)
        try? Monster.addHp(builder, hp: nestedMonsterHp)
        try? Monster.addMana(builder, mana: nestedMonsterMana)
        let monster1 = try! Monster.endMonster(builder)
        try? Monster.finishBuffer(builder, offset: monster1)
        let monster1Data = Array.init(try! builder.getData())
        
        let newBuilder = Builder(capacity: 16)
        let nameOffset2 = try! newBuilder.createString(with: "My Monster")
        let nestedData = try! Monster.createTestnestedflatbufferVectory(newBuilder, testnestedflatbuffer: monster1Data)
        
        try? Monster.startMonster(newBuilder)
        try? Monster.addName(newBuilder, nameOffset: nameOffset2)
        try? Monster.addHp(newBuilder, hp: 50)
        try? Monster.addMana(newBuilder, mana: 32)
        try? Monster.addTestnestedflatbuffer(newBuilder, testnestedflatbufferOffset: nestedData)
        let monsterOffset = try! Monster.endMonster(newBuilder)
        try? Monster.finishBuffer(newBuilder, offset: monsterOffset)
        
        // Now test the data extracted from the nested buffer
        var monsterData = try! newBuilder.getData()
        let monster = Monster.getRootAsMonster(withData: &monsterData)
        let nestedMonster = monster.testnestedflatbufferAsMonster
        
        XCTAssertEqual(nestedMonsterMana, nestedMonster.mana)
        XCTAssertEqual(nestedMonsterHp, nestedMonster.hp)
        XCTAssertEqual(nestedMonsterName, nestedMonster.name)
    }
    
    func testCreateByteVector() {
        let builder = Builder(capacity: 16)
        let nameOffset = try! builder.createString(with: "MyMonster")
        let inventory: [UInt8] = [0, 1, 2, 3, 4]
        let vectorOffset = try! builder.createByteVector(with: inventory)
        try? Monster.startMonster(builder)
        try? Monster.addInventory(builder, inventoryOffset: vectorOffset)
        try? Monster.addName(builder, nameOffset: nameOffset)
        let monsterOffset = try! Monster.endMonster(builder)
        try? Monster.finishBuffer(builder, offset: monsterOffset)
        var monsterData = try! builder.getData()
        let monster = Monster.getRootAsMonster(withData: &monsterData)
        
        XCTAssertEqual(monster.inventory[1], inventory[1])
        XCTAssertEqual(monster.inventoryCount, inventory.count)
        for i in 0..<monster.inventoryCount {
            XCTAssertEqual(monster.inventory[i], inventory[i])
        }
    }
    
    func testPerformceBuilder() {
        self.measure() {
            let builder = Builder(capacity: 16)
            _ = FlatbufferUnitTest._builderMonster(builder)
        }
    }
    
    static func _builderMonster(_ builder: Builder) -> UOffsetT {
        let names: [UOffsetT] = [
            try! builder.createString(with: "Frodo"),
            try! builder.createString(with: "Barney"),
            try! builder.createString(with: "Wilma")
        ]
        var off = [UOffsetT](repeating: 0, count: 3)
        try? Monster.startMonster(builder)
        try? Monster.addName(builder, nameOffset: names[0])
        off[0] = try! Monster.endMonster(builder)
        try? Monster.startMonster(builder)
        try? Monster.addName(builder, nameOffset: names[1])
        off[1] = try! Monster.endMonster(builder)
        try? Monster.startMonster(builder)
        try? Monster.addName(builder, nameOffset: names[2])
        off[2] = try! Monster.endMonster(builder)
        let sortOffset = try? builder.createSortedVectorOfTable(offsets: &off, table: Monster())
        
        // We set up the same values as monsterdata.json:
        let strOffset = try? builder.createString(with: "MyMonster")
        let invOffset = try? Monster.createInventoryVectory(builder, inventory: [0, 1, 2, 3, 4])
        let fredOffset = try? builder.createString(with: "Fred")
        try? Monster.startMonster(builder)
        try? Monster.addName(builder, nameOffset: fredOffset!)
        let monster2Offset = try? Monster.endMonster(builder)
        
        _ = try? Monster.startTest4Vector(builder, withNumberOfElement: 2)
        _ = try? Test.createTest(builder, b: 20, a: 10)
        _ = try? Test.createTest(builder, b: 40, a: 30)
        let test4Offset = try? builder.endVector(vectorNumElems: 2)
        
        let testArrayOfString = try? Monster.createTestarrayofstringVector(builder, testarrayofstring: [
            try! builder.createString(with: "test1"),
            try! builder.createString(with: "test2")
            ])
        
        _ = try? Monster.startMonster(builder)
        try? Monster.addPos(builder, posOffset: Vec3.createVec3(builder,
                                                                test3_b: 6,
                                                                test3_a: 5,
                                                                test2: Int(Color.Green.rawValue),
                                                                test1: 3.0,
                                                                z: 3.0,
                                                                y: 2.0,
                                                                x: 1.0))
        try? Monster.addHp(builder, hp: 80)
        try? Monster.addName(builder, nameOffset: strOffset!)
        try? Monster.addInventory(builder, inventoryOffset: invOffset!)
        try? Monster.addTestType(builder, testType: AnySwift.Monster.rawValue)
        try? Monster.addTest(builder, testOffset: monster2Offset!)
        try? Monster.addTest4(builder, test4Offset: test4Offset!)
        try? Monster.addTestarrayofstring(builder, testarrayofstringOffset: testArrayOfString!)
        try? Monster.addTestbool(builder, testbool: false)
        try? Monster.addTesthashu32Fnv1(builder, testhashu32Fnv1: UInt32(Int64(Int32.max) + 1))
        try? Monster.addTestarrayoftables(builder, testarrayoftablesOffset: sortOffset!)
        let monsterOffset = try? Monster.endMonster(builder)
        
        try? Monster.finishBuffer(builder, offset: monsterOffset!)
        return sortOffset!
    }
    
    static func _testData(data: inout Data) {
        XCTAssertEqual(Monster.MonsterBufferHasIdentifier(withData: &data), true)
        
        let monster = Monster.getRootAsMonster(withData: &data)
        
        XCTAssertEqual(monster.hp, 80)
        XCTAssertEqual(monster.mana, 150)
        
        XCTAssertEqual(monster.name, "MyMonster")
        
        let pos = monster.pos
        XCTAssertEqual(pos.x, 1.0)
        XCTAssertEqual(pos.y, 2.0)
        XCTAssertEqual(pos.z, 3.0)
        XCTAssertEqual(pos.test1, 3.0)
        XCTAssertEqual(pos.test2, Color.Green)
        
        let test = pos.test3
        XCTAssertEqual(test.a, 5)
        XCTAssertEqual(test.b, 6)
        
        XCTAssertEqual(monster.testType, AnySwift.Monster)
        let monster2 = Monster()
        XCTAssertEqual(monster.test(table: monster2) === monster2, true)
        XCTAssertEqual(monster2.name, "Fred")
        
        XCTAssertEqual(monster.inventoryCount, 5)
        var invsum: UInt8 = 0
        for i in 0..<monster.inventoryCount {
            invsum += monster.inventory[i]
        }
        XCTAssertEqual(invsum, 10)
        
        let test_0 = monster.test4[0]
        let test_1 = monster.test4[1]
        XCTAssertEqual(monster.test4Count, 2)
        XCTAssertEqual(test_0.a + Int16(test_0.b) + test_1.a + Int16(test_1.b) , 100)
        
        XCTAssertEqual(monster.testarrayofstringCount, 2)
        XCTAssertEqual(monster.testarrayofstring[0], "test1")
        XCTAssertEqual(monster.testarrayofstring[1], "test2")
        
        XCTAssertEqual(monster.testbool, false)
    }
    
    static func _testExtendedBuffer(data: inout Data) {
        FlatbufferUnitTest._testData(data: &data)
        let monster = Monster.getRootAsMonster(withData: &data)
        
        XCTAssertEqual(monster.testhashu32Fnv1, UInt32(Int64(Int32.max) + 1))
    }
    
    static func _testMutatedData(data: inout Data, sort: UOffsetT) {
        let monster = Monster.getRootAsMonster(withData: &data)
        
        // mana is optional and does not exist in the buffer so the mutation should fail
        // the mana field should retain its default value, but swift cannot throws from perperties
        // so 10 should make effect to the default value
        monster.mana = 10 // line actually failed in the properties setter
        XCTAssertEqual(monster.mana, 150)
        
        // Accessing a vector of sorted by the key tables
        XCTAssertEqual(monster.testarrayoftables[0].name, "Barney")
        XCTAssertEqual(monster.testarrayoftables[1].name, "Frodo")
        XCTAssertEqual(monster.testarrayoftables[2].name, "Wilma")
        
        // Example of searching for a table by the key
        XCTAssertEqual(Monster.lookup(at: Int(sort), by: "Frodo", with: &data).name, "Frodo")
        XCTAssertEqual(Monster.lookup(at: Int(sort), by: "Barney", with: &data).name, "Barney")
        XCTAssertEqual(Monster.lookup(at: Int(sort), by: "Wilma", with: &data).name, "Wilma")
        
        // testType is an existing field and mutating it should succeed
        XCTAssertEqual(monster.testType, AnySwift.Monster)
        monster.testType = AnySwift.NONE    // update type to none verify with below instruction
        XCTAssertEqual(monster.testType, AnySwift.NONE)
        monster.testType = AnySwift.Monster    // update type to none verify with below instruction
        XCTAssertEqual(monster.testType, AnySwift.Monster)
        
        //mutate the inventory vector
        monster.inventory[0] = 1
        monster.inventory[1] = 2
        monster.inventory[2] = 3
        monster.inventory[3] = 4
        monster.inventory[4] = 5
        
        for i in 0..<monster.inventoryCount {
            XCTAssertEqual(monster.inventory[i], UInt8(i + 1))
        }
        
        //reverse mutation
        monster.inventory[0] = 0
        monster.inventory[1] = 1
        monster.inventory[2] = 2
        monster.inventory[3] = 3
        monster.inventory[4] = 4
        
        for i in 0..<monster.inventoryCount {
            XCTAssertEqual(monster.inventory[i], UInt8(i))
        }

        // get a struct field and edit one of its fields
        let pos = monster.pos
        XCTAssertEqual(pos.x, 1.0)
        pos.x = 55.0
        XCTAssertEqual(pos.x, 55.0)
        pos.x = 1.0
        XCTAssertEqual(pos.x, 1.0)

        FlatbufferUnitTest._testExtendedBuffer(data: &data)
    }


}
