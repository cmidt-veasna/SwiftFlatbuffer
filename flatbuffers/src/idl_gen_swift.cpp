/*
 * Copyright 2014 Google Inc. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// independent from idl_parser, since this code is not needed for most clients

#include "flatbuffers/flatbuffers.h"
#include "flatbuffers/idl.h"
#include "flatbuffers/util.h"
#include "flatbuffers/code_generators.h"

#ifdef _WIN32
#include <direct.h>
#define PATH_SEPARATOR "\\"
#define mkdir(n, m) _mkdir(n)
#else
#include <sys/stat.h>
#define PATH_SEPARATOR "/"
#endif

namespace flatbuffers {
    
    namespace swift {
        
        static const std::string METHOD_NAME[] = {
            "UnsignedByte", "UnsignedByte", "Bool", "Byte", "UnsignedByte", "Short", "UnsignedShort",
            "Int", "UnsignedInt", "Long", "UnsignedLong", "Float", "Double"
        };
        
        static const std::string SWIFT_KEYWORD[] = {
            "Any", "rethrows", "guard", "inout", "guard", "Type", "indirect", "precedence"
        };
        
        // Convert an underscore_based_indentifier in to camelCase.
        // Also uppercases the first character if first is true.
        static std::string MakeCamel(const std::string &in, bool first) {
            std::string s;
            for (size_t i = 0; i < in.length(); i++) {
                if (!i && first)
                    s += static_cast<char>(toupper(in[0]));
                else if (in[i] == '_' && i + 1 < in.length())
                    s += static_cast<char>(toupper(in[++i]));
                else
                    s += in[i];
            }
            return s;
        }
        
        static std::string GenTypeMethodBasic(const Type &type) {
            return type.base_type == BASE_TYPE_VECTOR ? METHOD_NAME[type.element] : METHOD_NAME[type.base_type];
        }

        static std::string GenTypeBasic(const Type &type) {
            static const char *ctypename[] = {
                #define FLATBUFFERS_TD(ENUM, IDLTYPE, CTYPE, JTYPE, GTYPE, NTYPE, PTYPE, STYPE) #STYPE,
                    FLATBUFFERS_GEN_TYPES(FLATBUFFERS_TD)
                #undef FLATBUFFERS_TD
            };
            return type.base_type == BASE_TYPE_VECTOR ? ctypename[type.element] : ctypename[type.base_type];
        }
        
        static std::string GenNewNameForConflictKeywork(const std::string &in) {
            int size = sizeof(SWIFT_KEYWORD)/sizeof(SWIFT_KEYWORD[0]);
            for (int i = 0; i < size; i++) {
                if (in == SWIFT_KEYWORD[i]) {
                    return in + "Swift";
                }
            }
            return in;
        }
        
        // struct builder
        
        static void GenStructBuilderArgument(const StructDef &struct_def, const char *nameprefix, std::string *code_ptr) {
            std::string &code = *code_ptr;
            
            for (auto it = struct_def.fields.vec.rbegin(); it != struct_def.fields.vec.rend(); ++it) {
                auto &field = **it;
                if (IsStruct(field.value.type)) {
                    GenStructBuilderArgument(*field.value.type.struct_def,
                                             (nameprefix + (field.name + "_")).c_str(),
                                             code_ptr);
                } else {
                    code += ", ";
                    code += nameprefix + MakeCamel(field.name, false);
                    if (field.value.type.base_type == BASE_TYPE_BOOL) {
                        code += ": Bool";
                    } else if (field.value.type.base_type != BASE_TYPE_LONG &&
                        field.value.type.base_type != BASE_TYPE_ULONG && IsInteger(field.value.type.base_type)){
                        code += ": Int";
                    } else {
                        code += ": " + GenTypeBasic(field.value.type);
                    }
                }
            }
        }
        
        static void GenStructBuilderBody(const StructDef &struct_def, const char *nameprefix, std::string *code_ptr, int level) {
            std::string &code = *code_ptr;
            code += "\t\ttry builder.prepare(size: " + NumToString(struct_def.minalign) + ", additionalBytes: " + NumToString(struct_def.bytesize) + ")\n";
            for (auto it = struct_def.fields.vec.rbegin(); it != struct_def.fields.vec.rend(); ++it) {
                auto &field = **it;
                if (field.padding) {
                    code += "\t\tbuilder.paddingZero(count: " + NumToString(field.padding) + ")\n";
                }
                if (IsStruct(field.value.type)) {
                    GenStructBuilderBody(*field.value.type.struct_def, (nameprefix + (field.name + "_")).c_str(), code_ptr, level+1);
                } else {
                    if (field.value.type.base_type != BASE_TYPE_LONG && field.value.type.base_type != BASE_TYPE_BOOL &&
                        field.value.type.base_type != BASE_TYPE_ULONG && IsInteger(field.value.type.base_type)){
                        
                        code += "\t\ttry builder.put" + GenTypeMethodBasic(field.value.type) + "(with: " + GenTypeBasic(field.value.type) + "(truncatingBitPattern: " + nameprefix + MakeCamel(field.name, false) + "))\n";
                        
                    } else {
                        
                        code += "\t\ttry builder.put" + GenTypeMethodBasic(field.value.type) + "(with: " + nameprefix + MakeCamel(field.name, false) + ")\n";
                    }
                }
            }
            if (level == 0)
                code += "\t\treturn builder.offset()\n";
        }
        
        static void GenStructBuilder(const StructDef &struct_def, std::string *code_ptr) {
            std::string &code = *code_ptr;
            
            std::string className = MakeCamel(struct_def.name, true);
            code += "extension " + className + " {\n\n";
            code += "\tpublic static func create" + className + "(_ builder: Builder";
            GenStructBuilderArgument(struct_def, "", code_ptr);
            code += ") throws -> UOffsetT {\n";
            GenStructBuilderBody(struct_def, "", code_ptr, 0);
            code += "\t}\n\n";
            code += "}\n\n";
        }
        
        // table builder
        
        static void BuildFieldOfTable(const StructDef &struct_def,
                                      const FieldDef &field,
                                      const size_t offset,
                                      std::string *code_ptr) {
            
            std::string &code = *code_ptr;
            std::string fieldNameAllCamel = MakeCamel(field.name, true);
            std::string fieldNameCamel = MakeCamel(field.name, false);
            
            if (field.value.type.base_type == BASE_TYPE_BOOL) {
                code += "\tpublic static func add" + fieldNameAllCamel + "(_ builder: Builder, " + fieldNameCamel + ": Bool) throws {\n";
                code += "\t\ttry builder.putBool(offset: " + NumToString(offset) + ", with: " + fieldNameCamel + ", byDefault: " + (field.value.constant == "0" ? "false" : "true") + ")\n";
                code += "\t}\n\n";
            
            } else if (!IsScalar(field.value.type.base_type) && (!struct_def.fixed)) {
                
                code += "\tpublic static func add" + fieldNameAllCamel + "(_ builder: Builder, " + fieldNameCamel + "Offset: UOffsetT) throws {\n";
                if (field.value.type.base_type == BASE_TYPE_STRUCT) {
                    code += "\t\ttry builder.putStruct(virtualTable: " + NumToString(offset) + ", offset: " + fieldNameCamel + "Offset, defaultOffset: " + field.value.constant + ")\n";
                } else {
                    code += "\t\ttry builder.putOffset(virtualTable: " + NumToString(offset) + ", offset: " + fieldNameCamel + "Offset, defaultOffset: " + field.value.constant + ")\n";
                }
                code += "\t}\n\n";
                
            } else {
                
                std::string withValue = "";
                code += "\tpublic static func add" + fieldNameAllCamel + "(_ builder: Builder, " + fieldNameCamel + ": ";
                code += GenTypeBasic(field.value.type);
                withValue = fieldNameCamel;
                code += ") throws {\n";
                code += "\t\ttry builder.put" + GenTypeMethodBasic(field.value.type) + "(offset: " + NumToString(offset) + ", with: " + withValue + ", byDefault: " + field.value.constant + ")\n";
                code += "\t}\n\n";
            }
            
        }
        
        static void BuildVectorOfTable(const FieldDef &field,
                                       std::string *code_ptr) {

            std::string &code = *code_ptr;
            
            auto vector_type = field.value.type.VectorType();
            auto alignment = InlineAlignment(vector_type);
            auto elem_size = InlineSize(vector_type);
            std::string fieldNameAllCamel = MakeCamel(field.name, true);
            std::string fieldNameCamel = MakeCamel(field.name, false);
            
            if (IsScalar(field.value.type.element)) {
                code += "\tpublic static func create" + fieldNameAllCamel + "Vectory(_ builder: Builder, " + fieldNameCamel + ": [" + GenTypeBasic(field.value.type) + "]) throws -> UOffsetT {\n";
                code += "\t\t_ = try builder.startVector(withElementSize: " + NumToString(elem_size) + ", count: " + fieldNameCamel + ".count, alignment: " + NumToString(alignment) + ")\n";
                code += "\t\tfor i in (0..<" + fieldNameCamel + ".count).reversed() {\n";
                code += "\t\t\ttry builder.put" + GenTypeMethodBasic(field.value.type) + "(with: " + fieldNameCamel + "[i])\n";
                code += "\t\t}\n";
                code += "\t\treturn try builder.endVector(vectorNumElems: " + fieldNameCamel + ".count)\n";
                code += "\t}\n\n";
            } else if (field.value.type.element == BASE_TYPE_STRING) {
                code += "\tpublic static func create" + fieldNameAllCamel + "Vector(_ builder: Builder, " + fieldNameCamel + ": [UOffsetT]) throws -> UOffsetT {\n";
                code += "\t\t_ = try builder.startVector(withElementSize: " + NumToString(elem_size) + ", count: " + fieldNameCamel + ".count, alignment: " + NumToString(alignment) + ")\n";
                code += "\t\tfor i in (0..<" + fieldNameCamel + ".count).reversed() {\n";
                code += "\t\t\ttry builder.putUnsignedTableOffset(offset: " + fieldNameCamel + "[i])\n";
                code += "\t\t}\n";
                code += "\t\treturn try builder.endVector(vectorNumElems: " + fieldNameCamel + ".count)\n";
                code += "\t}\n\n";
            }
            
            code += "\tpublic static func start" + fieldNameAllCamel + "Vector(_ builder: Builder, withNumberOfElement: Int) throws -> UOffsetT {\n";
            code += "\t\treturn try builder.startVector(withElementSize: " + NumToString(elem_size) + ", count: withNumberOfElement, alignment: " + NumToString(alignment) + ")\n";
            code += "\t}\n\n";
        }
        
        static void GenTableFieldBuilders(const StructDef &struct_def,
                                          std::string *code_ptr) {
            
            for (auto it = struct_def.fields.vec.begin(); it != struct_def.fields.vec.end(); ++it) {
                auto &field = **it;
                if (field.deprecated) continue;
                auto offset = it - struct_def.fields.vec.begin();
                BuildFieldOfTable(struct_def, field, offset, code_ptr);
                if (field.value.type.base_type == BASE_TYPE_VECTOR) {
                    BuildVectorOfTable(field, code_ptr);
                }
            }
            
        }
        
        static void GenTableBuilders(const bool isRoot, std::string identifier, const StructDef &struct_def,
                                     std::string *code_ptr) {

            std::string &code = *code_ptr;
            std::string className = GenNewNameForConflictKeywork(MakeCamel(struct_def.name, true));
            code += "extension " + className + " {\n\n";
            
            // static start table
            code += "\tpublic static func start" + className + "(_ builder: Builder) throws {\n";
            code += "\t\ttry builder.startObject(numberOfFields: " + NumToString(struct_def.fields.vec.size()) + ")\n";
            code += "\t}\n\n";
            
            GenTableFieldBuilders(struct_def, code_ptr);
            
            // static end table
            code += "\tpublic static func end" + className + "(_ builder: Builder) throws -> UOffsetT {\n";
            code += "\t\treturn try builder.endObject()\n";
            code += "\t}\n\n";
            
            // create finish for root table
            if (isRoot) {
                code += "\tpublic static func finishBuffer(_ builder: Builder, offset: UOffsetT) throws {\n";
                if (identifier == "") {
                    code += "\t\ttry builder.finish(by: offset)\n";
                } else {
                    code += "\t\ttry builder.finish(by: offset, file: \"" + identifier + "\")\n";
                }
                code += "\t}\n";
            }
            
            // end extension
            code += "}\n\n";
        }
        
        // Getter
        
        static void BeginEnum(const EnumDef &enum_def, std::string *code_ptr) {
            std::string &code = *code_ptr;
            code += "public enum " + GenNewNameForConflictKeywork(enum_def.name) + ": " + GenTypeBasic(enum_def.underlying_type) + " {\n";
        }
        
        // End enum code.
        static void EndEnum(std::string *code_ptr) {
            std::string &code = *code_ptr;
            code += "}\n\n";
        }
        
        // A single enum member.
        static void EnumMember(const EnumVal ev,
                               std::string *code_ptr) {
            std::string &code = *code_ptr;
            code += "\tcase ";
            code += ev.name;
            code += " = ";
            code += NumToString(ev.value) + "\n";
        }
        
        static void GenEnum(const EnumDef &enum_def, std::string *code_ptr) {
            if (enum_def.generated) return;
            
            GenComment(enum_def.doc_comment, code_ptr, nullptr);
            BeginEnum(enum_def, code_ptr);
            for (auto it = enum_def.vals.vec.begin();
                 it != enum_def.vals.vec.end();
                 ++it) {
                auto &ev = **it;
                GenComment(ev.doc_comment, code_ptr, nullptr, "\t");
                EnumMember(ev, code_ptr);
            }
            EndEnum(code_ptr);
        }
        
        // Begin class declaration
        static std::string BeginClass(const StructDef &struct_def) {
            std::string code = "";
            // class extend struct or table will have empty body as we use extension instead.
            code += struct_def.fixed ?
                "public class " + struct_def.name + ": Struct {"
                : "public class " + struct_def.name + ": Table {\n\n";
            return code;
        }
        
        static void EndClass(const StructDef &struct_def, flatbuffers::FieldDef *key_field, std::string *code_ptr, std::string *beingClass, std::string *vectorHelper) {
            std::string &code = *code_ptr;
            
            std::string compareKey = "";
            std::string lookupKeyStart = "";
            std::string lookupKeyCompBody = "";
            std::string lookupKey = "";
            std::string lookupKeyInputType = "";
            // override function key
            if (struct_def.has_key) {
                compareKey += "\tpublic override func compareKey(of: UOffsetT, with: UOffsetT, by data: inout Data) -> Bool {\n";
                if (key_field->value.type.base_type == BASE_TYPE_STRING) {
                    compareKey += "\t\treturn Table.compareString(of: Struct.__offset(virtualTableOffset: " + NumToString(key_field->value.offset) + ", offset: Int(of), data: &data),";
                    compareKey += " with: Struct.__offset(virtualTableOffset: " + NumToString(key_field->value.offset) + ", offset: Int(with), data: &data), by: &data) <= 0\n";
                    
                    lookupKeyInputType = "String";
                    lookupKeyStart = "\t\tlet keyBytes = [UInt8](key.utf8)\n";
                    lookupKeyCompBody += "\t\t\tlet comp = Table.compareString(of: Struct.__offset(virtualTableOffset: " + NumToString(key_field->value.offset) + ", offset: data.count - tableOffset, data: &data), with: keyBytes, by: &data)\n";
                    lookupKeyCompBody += "\t\t\tif comp > 0 {\n";
                    lookupKeyCompBody += "\t\t\t\tspan = middle\n";
                    lookupKeyCompBody += "\t\t\t} else if comp < 0 {\n";
                    lookupKeyCompBody += "\t\t\t\tmiddle += 1\n";
                    lookupKeyCompBody += "\t\t\t\tstart += middle\n";
                    lookupKeyCompBody += "\t\t\t\tspan -= middle\n";
                    
                } else {
                    std::string methodName = GenTypeMethodBasic(key_field->value.type);
                    compareKey += "\t\tlet first" + methodName + " = data.get" + methodName + "(at: Struct.__offset(virtualTableOffset: " + NumToString(key_field->value.offset) + ", offset: Int(of), data: &data))\n";
                    compareKey += "\t\tlet second" + methodName + " = data.get" + methodName + "(at: Struct.__offset(virtualTableOffset: " + NumToString(key_field->value.offset) + ", offset: Int(with), data: &data))\n";
                    compareKey += "\t\treturn first" + methodName + " > second" + methodName + "\n";

                    lookupKeyInputType = GenTypeBasic(key_field->value.type);
                    lookupKeyCompBody += "\t\t\tlet value = data.get" + GenTypeMethodBasic(key_field->value.type) + "(at: Struct.__offset(virtualTableOffset: " + NumToString(key_field->value.offset) + ", offset: data.count - tableOffset, data: &data))\n";
                    lookupKeyCompBody += "\t\t\tif value > key {\n";
                    lookupKeyCompBody += "\t\t\t\tspan = middle\n";
                    lookupKeyCompBody += "\t\t\t} else if value < key {\n";
                    lookupKeyCompBody += "\t\t\t\tmiddle += 1\n";
                    lookupKeyCompBody += "\t\t\t\tstart += middle\n";
                    lookupKeyCompBody += "\t\t\t\tspan -= middle\n";

                }
                compareKey += "\t}\n\n";
                
                lookupKey += "\tpublic static func lookup(at: Int, by key: " + lookupKeyInputType + ", with data: inout Data) -> " + struct_def.name + " {\n";
                lookupKey += lookupKeyStart;
                lookupKey += "\t\tvar vectorLocation = data.count - at\n";
                lookupKey += "\t\tvar span = Int(data.getInt(at: vectorLocation))\n";
                lookupKey += "\t\tvar start = 0\n";
                lookupKey += "\t\tvectorLocation += 4\n";
                lookupKey += "\t\twhile(span != 0) {\n";
                lookupKey += "\t\t\tvar middle = span / 2\n";
                lookupKey += "\t\t\tlet tableOffset = Table.__indirect(offset: vectorLocation + 4 * Int(start + middle), data: &data)\n";
                lookupKey += lookupKeyCompBody;
                lookupKey += "\t\t\t} else {\n";
                lookupKey += "\t\t\t\treturn " + struct_def.name + "().__assign(at: tableOffset, withData: &data) as! " + struct_def.name + "\n";
                lookupKey += "\t\t\t}\n";
                lookupKey += "\t\t}\n";
                lookupKey += "\t\treturn " + struct_def.name + "()\n";
                lookupKey += "\t}\n";
            }
            
            code = *beingClass + *vectorHelper + compareKey + lookupKey + "}\n\n" + code;
        }
        
        static void GenUnionField(const FieldDef &field, std::string method_name, std::string *code_ptr) {
            std::string &code = *code_ptr;

            code += "\topen func " + method_name + "(table: Table) -> Table {\n";
            code += "\t\tlet offset = __offset(virtualTableOffset: " + NumToString(field.value.offset) + ")\n";
            code += "\t\treturn offset != 0 ? __union(table: table, offset: offset) : Table()\n";
            code += "\t}\n\n";
        }
        
        static std::string GenVectorField(bool mutated, const StructDef &struct_def, const FieldDef &field, std::string method_name, std::string *code_ptr) {
            std::string &code = *code_ptr;
            
            std::string return_type = "";
            std::string vectorHelperType = "";
            std::string genericInfo = "";
            std::string mutatedCode = "";
            std::string className = GenNewNameForConflictKeywork(struct_def.name);
            
            if (field.value.type.struct_def != nullptr) {
                vectorHelperType = "Table";
                return_type = GenNewNameForConflictKeywork((*field.value.type.struct_def).name);
                genericInfo += className + ", " + return_type;

            } else {
                
                if (field.value.type.element == BASE_TYPE_BOOL) {
                    vectorHelperType = "Bool";
                    return_type = "Bool";
                    genericInfo += className;
                    
                } else if (field.value.type.enum_def != nullptr) {
                    // it byte but define as enum
                    vectorHelperType = "Enum";
                    return_type = GenNewNameForConflictKeywork((*field.value.type.enum_def).name);
                    genericInfo += className + ", " + return_type;
                    
                } else if (field.value.type.element == BASE_TYPE_LONG) {
                    vectorHelperType = "Integer";
                    return_type = "Int64";
                    genericInfo += className + ", " + return_type;
                    
                } else if (field.value.type.element == BASE_TYPE_ULONG) {
                    vectorHelperType = "Integer";
                    return_type = "UInt64";
                    genericInfo += className + ", " + return_type;
                    
                } else if (IsInteger(field.value.type.element)) {
                    vectorHelperType = "Integer";
                    return_type = GenTypeBasic(field.value.type);
                    genericInfo += className + ", " + return_type;
                    
                } else if (field.value.type.element == BASE_TYPE_FLOAT) {
                    vectorHelperType = "FloatingPoint";
                    return_type = "Float";
                    genericInfo += className + ", " + return_type;
                    
                } else if (field.value.type.element == BASE_TYPE_DOUBLE) {
                    vectorHelperType = "FloatingPoint";
                    return_type = "Double";
                    genericInfo += className + ", " + return_type;
                    
                } else if (field.value.type.element == BASE_TYPE_STRING) {
                    vectorHelperType = "String";
                    return_type = "String";
                    genericInfo += className;
                }
                
                if (mutated && IsScalar(field.value.type.element)) {
                    mutatedCode += "\t\t{ (table, at, value) -> Bool in\n";
                    mutatedCode += "\t\t\tdo {\n";
                    mutatedCode += "\t\t\t\ttry table.data?.put" + GenTypeMethodBasic(field.value.type) + "(at: at, with: value)\n";
                    mutatedCode += "\t\t\t\treturn true\n";
                    mutatedCode += "\t\t\t} catch {\n";
                    mutatedCode += "\t\t\t\treturn false\n";
                    mutatedCode += "\t\t\t}\n";
                    mutatedCode += "\t\t}\n";
                }

            }
            
            code += "\tvar " + method_name + ": Vector" + vectorHelperType + "Helper<" + genericInfo + "> {\n";
            code += "\t\tif let " + method_name + "Vector = " + method_name + "VectorHelper as Vector" + vectorHelperType + "Helper<" + genericInfo + ">? {\n";
            code += "\t\t\treturn " + method_name + "Vector\n";
            code += "\t\t}\n";
            code += "\t\t" + method_name + "VectorHelper = Vector" + vectorHelperType + "Helper<" + genericInfo + ">(object: self, offset: " + NumToString(field.value.offset) + ")\n";
            
            code += mutatedCode;
            
            code += "\t\treturn " + method_name + "VectorHelper!\n";
            code += "\t}\n\n";
            
            code += "\tvar " + method_name + "Count: Int {\n";
            code += "\t\tget {\n";
            code += "\t\t\tlet offset = __offset(virtualTableOffset: " + NumToString(field.value.offset) + ")\n";
            code += "\t\t\treturn offset != 0 ? __vectorLength(offset: offset) : 0\n";
            code += "\t\t}\n";
            code += "\t}\n\n";
            
            return "\tfileprivate var " + method_name + "VectorHelper: Vector" + vectorHelperType + "Helper<" + genericInfo + ">?\n";
        }
        
        // generate struct method
        static void GenStructField(bool isFixed, const FieldDef &field, std::string method_name, std::string *code_ptr) {
            std::string &code = *code_ptr;
            
            std::string return_type = GenNewNameForConflictKeywork((*field.value.type.struct_def).name);
            std::string lower_var_name = (*field.value.type.struct_def).name;
            std::transform(lower_var_name.begin(), lower_var_name.end(), lower_var_name.begin(), ::tolower);
            
            code += "\tvar " + method_name + ": " + return_type + " {\n";
            code += "\t\tget {\n";
            code += "\t\t\treturn get" + MakeCamel(method_name, true) + "(" + lower_var_name + ": " + return_type + "())\n";
            code += "\t\t}\n";
            code += "\t}\n\n";
            
            code += "\topen func get" + MakeCamel(method_name, true) + "(" + lower_var_name + ": " + return_type + ")" + " -> " + return_type + " {\n";
            if (isFixed) {
                code += "\t\treturn " + lower_var_name + ".__assign(at: position + " + NumToString(field.value.offset) + ", withData: &data!) as! " + return_type + "\n";
            } else {
                code += "\t\tlet offset = __offset(virtualTableOffset: " + NumToString(field.value.offset) + ")\n";
                if ((*field.value.type.struct_def).fixed) {
                    code += "\t\treturn " + lower_var_name + ".__assign(at: offset + position, withData: &data!) as! " + return_type + "\n";
                } else {
                    code += "\t\treturn " + lower_var_name + ".__assign(at: __indirect(offset: offset + position), withData: &data!) as! " + return_type + "\n";
                }
            }
            code += "\t}\n\n";
        }

        // Generate struct or table methods.
        static void GenStruct(const Parser &parser_, const StructDef &struct_def,
                              std::string *code_ptr) {
            if (struct_def.generated) return;
            
            GenComment(struct_def.doc_comment, code_ptr, nullptr);
            std::string beginClass = BeginClass(struct_def);
            std::string vectorHelper = "";
            
            std::string &code = *code_ptr;
            code += "extension " + struct_def.name + " {\n\n";
            flatbuffers::FieldDef *key_field = nullptr;
            if (!struct_def.fixed) {
                // is the table so create getRoot with NSData
                // get Root with NSData only
                std::string lower_def_name = struct_def.name;
                std::transform(lower_def_name.begin(), lower_def_name.end(), lower_def_name.begin(), ::tolower);
                
                std::string className = GenNewNameForConflictKeywork(struct_def.name);
                lower_def_name = GenNewNameForConflictKeywork(lower_def_name);
                
                std::string method_body = "\t\treturn getRootAs" + className + "(withData: &withData, " + lower_def_name + ": " + className + "())";
                std::string method_name = "getRootAs" + className;
                std::string method_decl = "\topen static func " + method_name + "(withData: inout Data) -> " + className + " {\n" + method_body + "\n\t}\n\n";
                
                code += method_decl;
                 
                // get Root with specify object
                // swift UnsafeMutableRawPointer no copy will supply this option
                // https://developer.apple.com/reference/foundation/data/1780455-init
                method_body = "\t\treturn " + lower_def_name + ".__assign(at: withData.getOffset(at: 0), withData: &withData) as! " + className;
                method_decl = "\topen static func " + method_name + "(withData: inout Data, " + lower_def_name + ": " + className + ") -> " + className + " {\n" + method_body + "\n\t}\n\n";
                 
                code += method_decl;
                
                if (parser_.root_struct_def_ == &struct_def) {
                    if (parser_.file_identifier_.length()) {
                        // Check if a buffer has the identifier.
                        code += "\topen static func ";
                        code += className + "BufferHasIdentifier(withData: inout Data) -> Bool {\n";
                        code += "\t\treturn __has_identifier(withData: &withData, at: 0, ident: \"";
                        code += parser_.file_identifier_;
                        code += "\")\n\t}\n\n";
                    }
                }
            }
            
            for (auto it = struct_def.fields.vec.begin(); it != struct_def.fields.vec.end(); ++it) {
                auto &field = **it;
                if (field.deprecated) continue;
                if (field.key) key_field = &field;
                
                GenComment(field.doc_comment, code_ptr, nullptr);
                
                std::string return_type = "";
                std::string method_name = "";
                std::string method_argu = "()";
                std::string method_body = "";
                
                std::string mutatedCode = "";
                std::string mutatedCodeBody = "";
                
                if (IsScalar(field.value.type.base_type)) {

                    if (field.value.type.base_type == BASE_TYPE_BOOL) {
                        // prefix is
                        return_type = "Bool";
                        method_name = MakeCamel(field.name, false);
                        method_body = struct_def.fixed ? "\t\t\treturn 0 != Int((data?.getByte(at: position + " + NumToString(field.value.offset) + "))!)\n" : "\t\t\treturn __bool(offset: " + NumToString(field.value.offset) + ", value: " +
                            ( field.value.constant == "0" ? "false" : "true" ) + ")\n";

                        if (parser_.opts.mutable_buffer) {
                            mutatedCode += "\t\tset {\n";
                            if (struct_def.fixed) {
                                mutatedCode += "\t\t\ttry? self.data?.putByte(at: position + " + NumToString(field.value.offset) + ", with: newValue ? 1 : 0)\n";
                            } else {
                                mutatedCode += "\t\t\tlet offset = __offset(virtualTableOffset: " + NumToString(field.value.offset) + ")\n";
                                mutatedCode += "\t\t\tif (offset != 0) {\n";
                                mutatedCode += "\t\t\ttry? self.data?.putByte(at: offset + position, with: newValue ? 1 : 0)\n";
                                mutatedCode += "\t\t\t}\n";
                            }
                            mutatedCode += "\t\t}\n";
                        }
                        
                    } else {
                        // prefix get
                        method_name = MakeCamel(field.name, false);
                        
                        if (struct_def.fixed) {
                            
                            if (field.value.type.enum_def != nullptr) {
                                // it byte but define as enum
                                return_type = GenNewNameForConflictKeywork((*field.value.type.enum_def).name);
                                method_body += "\t\t\treturn " + return_type + "(rawValue: (data!.getInteger(at: position + " + NumToString(field.value.offset) +") as " + GenTypeBasic((*field.value.type.enum_def).underlying_type) + "))!\n";
                                
                                mutatedCodeBody += "\t\t\ttry? self.data?.put" + GenTypeMethodBasic(field.value.type) + "(at: position + " + NumToString(field.value.offset) + ", with: newValue.rawValue)\n";
                                
                            } else if (field.value.type.base_type == BASE_TYPE_LONG) {
                                return_type = "Int64";
                                method_body += "\t\t\treturn (data?.getLong(at: position + " + NumToString(field.value.offset) + "))!\n";
                                mutatedCodeBody += "\t\t\ttry? self.data?.putLong(at: position + " + NumToString(field.value.offset) + ", with: newValue)\n";
                                
                            } else if (field.value.type.base_type == BASE_TYPE_ULONG) {
                                return_type = "UInt64";
                                method_body += "\t\t\treturn (data?.getUnsignedLong(at: position + " + NumToString(field.value.offset) + "))!\n";
                                mutatedCodeBody += "\t\t\ttry? self.data?.putUnsignedLong(at: position + " + NumToString(field.value.offset) + ", with: newValue)\n";
                            } else if (IsInteger(field.value.type.base_type)) {
                                return_type = GenTypeBasic(field.value.type);
                                method_body += "\t\t\treturn (data!.getInteger(at: position + " + NumToString(field.value.offset) + ")) as " + return_type + "\n";
                                mutatedCodeBody = "\t\t\ttry? self.data?.put" + GenTypeMethodBasic(field.value.type) + "(at: position + " + NumToString(field.value.offset) + ", with: ";
                                mutatedCodeBody += "newValue)\n";
                                
                            } else if (field.value.type.base_type == BASE_TYPE_FLOAT) {
                                return_type = "Float";
                                method_body += "\t\t\treturn (data?.getFloat(at: position + " + NumToString(field.value.offset) + "))!\n";
                                mutatedCodeBody += "\t\t\ttry? self.data?.putFloat(at: position + " + NumToString(field.value.offset) + ", with: newValue)\n";
                                
                            } else if (field.value.type.base_type == BASE_TYPE_DOUBLE) {
                                return_type = "Double";
                                method_body += "\t\t\treturn (data?.getDouble(at: position + "  + NumToString(field.value.offset) + "))!\n";
                                mutatedCodeBody += "\t\t\ttry? self.data?.putDouble(at: position + " + NumToString(field.value.offset) + ", with: newValue)\n";
                                
                            }
                            
                            // generate mutated field
                            if (parser_.opts.mutable_buffer) {
                                mutatedCode += "\t\tset {\n";
                                mutatedCode += mutatedCodeBody;
                                mutatedCode += "\t\t}\n";
                            }

                            
                        } else {
                            
                            method_body += "\t\t\tlet offset = __offset(virtualTableOffset: " + NumToString(field.value.offset) + ")\n";
                            if (field.value.type.enum_def != nullptr) {
                                // it byte but define as enum
                                return_type = GenNewNameForConflictKeywork((*field.value.type.enum_def).name);
                                method_body += "\t\t\treturn " + return_type + "(rawValue: offset != 0 ? (data!.getInteger(at: offset + position) as " + GenTypeBasic((*field.value.type.enum_def).underlying_type) + ") : " + field.value.constant + ")!\n";
                                
                                mutatedCodeBody += "\t\t\t\ttry? self.data?.put" + GenTypeMethodBasic(field.value.type) + "(at: offset + position, with: newValue.rawValue)\n";

                            } else if (field.value.type.base_type == BASE_TYPE_LONG) {
                                return_type = "Int64";
                                method_body += "\t\t\treturn offset != 0 ? (data?.getLong(at: offset + position))! : " + field.value.constant + "\n";
                                mutatedCodeBody += "\t\t\t\ttry? self.data?.putLong(at: offset + position, with: newValue)\n";
                                
                            } else if (field.value.type.base_type == BASE_TYPE_ULONG) {
                                return_type = "UInt64";
                                method_body += "\t\t\treturn offset != 0 ? (data?.getUnsignedLong(at: offset + position))! : " + field.value.constant + "\n";
                                mutatedCodeBody += "\t\t\t\ttry? self.data?.putUnsignedLong(at: offset + position, with: newValue)\n";
                            } else if (IsInteger(field.value.type.base_type)) {
                                return_type = GenTypeBasic(field.value.type);
                                method_body += "\t\t\treturn offset != 0 ? (data!.getInteger(at: offset + position)) as " + return_type + " : " + field.value.constant +"\n";
                                
                                mutatedCodeBody += "\t\t\t\ttry? self.data?.put" + GenTypeMethodBasic(field.value.type) + "(at: offset + position, with: ";
                                mutatedCodeBody += "newValue)\n";
                                
                            } else if (field.value.type.base_type == BASE_TYPE_FLOAT) {
                                return_type = "Float";
                                method_body += "\t\t\treturn offset != 0 ? (data?.getFloat(at: offset + position))! : " + field.value.constant + "\n";
                                mutatedCodeBody += "\t\t\t\ttry? self.data?.putFloat(at: offset + position, with: newValue)\n";
                                
                            } else if (field.value.type.base_type == BASE_TYPE_DOUBLE) {
                                return_type = "Double";
                                method_body += "\t\t\treturn offset != 0 ? (data?.getDouble(at: offset + position))! : " + field.value.constant + "\n";
                                mutatedCodeBody += "\t\t\t\ttry? self.data?.putDouble(at: offset + position, with: newValue)\n";
                                
                            }
                            
                            // generate mutated field
                            if (parser_.opts.mutable_buffer) {
                                mutatedCode += "\t\tset {\n";
                                mutatedCode += "\t\t\tlet offset = __offset(virtualTableOffset: " + NumToString(field.value.offset) + ")\n";
                                mutatedCode += "\t\t\tif (offset != 0) {\n";
                                mutatedCode += mutatedCodeBody;
                                mutatedCode += "\t\t\t}\n";
                                mutatedCode += "\t\t}\n";
                            }

                        }
                        
                    }
                    
                    
                } else {
                    
                    method_name = MakeCamel(field.name, false);
                    
                    if (struct_def.fixed) {
                        // another struct
                        
                        GenStructField(true, field, method_name, code_ptr);
                        continue;
                        
                    } else {
                        
                        method_body += "\t\t\tlet offset = __offset(virtualTableOffset: " + NumToString(field.value.offset) + ")\n";
                        
                        if (field.value.type.base_type == BASE_TYPE_STRING) {
                            return_type = "String";
                            method_body += "\t\t\treturn offset != 0 ? __string(offset: offset + position) : \"\"\n";
                        } else if (field.value.type.base_type == BASE_TYPE_VECTOR) {
                            
                            vectorHelper += GenVectorField(parser_.opts.mutable_buffer, struct_def, field, method_name, code_ptr);
                            
                            // generate object accessors if is nested_flatbuffer
                            auto nested = field.attributes.Lookup("nested_flatbuffer");
                            if (nested) {
                                auto nested_qualified_name =
                                parser_.namespaces_.back()->GetFullyQualifiedName(nested->constant);
                                auto nested_type = parser_.structs_.Lookup(nested_qualified_name);
                                auto nested_type_name = (*nested_type).name;
                                auto nestedMethodName = MakeCamel(field.name, false)
                                + "As" + nested_type_name;
                                
                                std::string lower_name = nested_type_name;
                                std::transform(lower_name.begin(), lower_name.end(), lower_name.begin(), ::tolower);
                                
                                code += "\tvar " + nestedMethodName + ": " + nested_type_name + " {\n";
                                code += "\t\treturn " + nestedMethodName + "(" + lower_name + ": " + nested_type_name + "())\n";
                                code += "\t}\n\n";
                                
                                code += "\topen func " + nestedMethodName + "(" + lower_name + ": " + nested_type_name + ") -> " + nested_type_name + " {\n";
                                code += "\t\tlet offset = __offset(virtualTableOffset: " + NumToString(field.value.offset) + ")\n";
                                code += "\t\treturn offset == 0 ? " + lower_name + " : " + lower_name + ".__assign(at: __indirect(offset: __vector(offset: offset)), withData: &self.data!) as! " + nested_type_name + "\n";
                                code += "\t}\n\n";
                            }
                            
                            continue;
                            
                        } else if (field.value.type.base_type == BASE_TYPE_UNION) {
                            
                            GenUnionField(field, method_name, code_ptr);
                            continue;
                            
                        } else if (field.value.type.base_type == BASE_TYPE_STRUCT) {
                            
                            GenStructField(false, field, method_name, code_ptr);
                            continue;
                            
                        }
                        
                    }
                    
                }
                
                code += "\tvar " + method_name + ": " + return_type + " {\n";
                code += "\t\tget {\n";
                code += method_body;
                code += "\t\t}\n";
                // generate mutator scalar field, by default mutatedCode will be empty only --gen-mutable is specify in the command line
                code += mutatedCode;
                code += "\t}\n\n";

            }
            
            code += "}\n\n";
            if (!struct_def.fixed) {
                vectorHelper += "\n";
            }
            EndClass(struct_def, key_field, code_ptr, &beginClass, &vectorHelper);
            
            // generate builder
            if (struct_def.fixed) {
                GenStructBuilder(struct_def, code_ptr);
            } else {
                GenTableBuilders(parser_.root_struct_def_ == &struct_def, parser_.file_identifier_, struct_def, code_ptr);
            }
        }
        
        class SwiftGenerator : public BaseGenerator {
        public:
            SwiftGenerator(const Parser &parser, const std::string &path,
                        const std::string &file_name)
            : BaseGenerator(parser, path, file_name, "" /* not used */,
                            "" /* not used */){};
        
            bool generate() {

                for (auto it = parser_.enums_.vec.begin(); it != parser_.enums_.vec.end(); ++it) {
                    std::string enumcode;
                    swift::GenEnum(**it, &enumcode);
                    if (!SaveType(**it, enumcode, false)) return false;
                }
                
                for (auto it = parser_.structs_.vec.begin(); it != parser_.structs_.vec.end(); ++it) {
                    std::string declcode;
                    swift::GenStruct(parser_, **it, &declcode);
                    if (!SaveType(**it, declcode, true)) return false;
                }
                
                return true;
            }
        
        private:
            // Begin by declaring namespace and imports.
            void BeginFile(const bool needs_imports,
                           std::string *code_ptr) {
                std::string &code = *code_ptr;
                code = code + "// Code generated by flatc command **DO NOT MODIFIED THIS CODE**\n\n";
                if (needs_imports) {
                    code += "import Foundation\n\n";
                }
            }
            
            // Save out the generated code for a Go Table type.
            bool SaveType(const Definition &def, const std::string &classcode,
                          bool needs_imports) {
                if (!classcode.length()) return true;
                
                std::string code = "";
                BeginFile(needs_imports, &code);
                code += classcode;
                std::string filename = def.name + ".swift";
                return SaveFile(filename.c_str(), code, false);
            }
            
        };
    
    }
    
    bool GenerateSwift(const Parser &parser, const std::string &path,
                    const std::string &file_name) {
        swift::SwiftGenerator generator(parser, path, file_name);
        return generator.generate();
    }

}  // namespace flatbuffers

