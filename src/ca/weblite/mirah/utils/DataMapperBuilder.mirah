/*
 *  Copyright 2014 Steve Hannah
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
package ca.weblite.mirah.utils
import org.mirah.typer.Typer
import org.mirah.typer.Scope
import mirah.lang.ast.*
import org.mirah.macros.Compiler
import org.objectweb.asm.Type
import org.mirah.jvm.mirrors.MirrorTypeSystem
import org.mirah.jvm.mirrors.MirrorType
import org.mirah.jvm.types.JVMMethod
import org.mirah.typer.TypeFuture
import org.mirah.jvm.mirrors.BaseType
import org.mirah.jvm.types.JVMTypeUtils
import org.mirah.typer.ResolvedType
import org.mirah.typer.DerivedFuture
import org.mirah.jvm.mirrors.ArrayType
import org.mirah.jvm.types.JVMType
import org.mirah.jvm.types.MemberKind
import org.mirah.jvm.types.Flags
import org.mirah.jvm.mirrors.BytecodeMirror
import org.mirah.jvm.mirrors.MirahMethod
import org.mirah.jvm.mirrors.Member
import org.objectweb.asm.signature.SignatureReader
import org.objectweb.asm.Opcodes
import java.util.HashSet
import org.mirah.util.AstFormatter

/**
 * A class for building DataMapper objects  This is meant to be used by the 
 * data_mapper macro.  Encapsulating it in a separate class makes it easier to 
 * manage.
 * @author shannah
 */
class DataMapperBuilder 
  
  /**
   * @param mirah Reference to the mirah compiler.  Taken from the macro.
   * @param call The call site.  Taken from the macro.
   * @param klass The class to create a mapper for.
   * @param mapperClass The name of the class that should be created.
   */
  def initialize(mirah:Compiler, call:CallSite, klass:TypeName, mapperClass:TypeName)
    @mirah=mirah
    @typer = @mirah.typer
    @types = MirrorTypeSystem(@typer.type_system)
    @call=call
    #puts "Creating #{klass}"
    @klass = klass
    @mapperClass = mapperClass
    @scoper = @typer.scoper
    @scope = @scoper.getScope(call)
    
    
  end
  
  /**
   * Builds a data mapper and returns the Node that can be added to the AST.  
   */
  def build:Node
    
    classTypeFuture = @types.get(@scope, @klass.typeref)
    classTypeResolved = classTypeFuture.resolve
    
    # Begin by creating the skeleton of the Mapper class with stubs
    # for the methods that we will fill in later.
    cls = @mirah.quote do
      import ca.weblite.codename1.mapper.DataMapper

      
      import java.util.Map
      class `@mapperClass` < DataMapper
        def init:void
          register(`@klass.typeref`.class, self)
        end
        def readMap(src:Map,dest:Object):void
        end
        
        def writeMap(dest:Map, src:Object):void
        end
        
      
      end
    end
    
    # Obtain references to some common class types that we will need.
    listType = @types.wrap(
        Type.getType('Ljava/util/List;')
    ).resolve
    
    stringType = @types.wrap(
        Type.getType('Ljava/lang/String;')
    ).resolve
    
    mapType = @types.wrap(
        Type.getType('Ljava/util/Map;')
    ).resolve
    
    finder = MethodFinder.new
    cls.accept finder, nil
    methods = finder.results
    
    readMap = nil
    writeMap = nil
    
    methods.each do |mdef:MethodDefinition|
      mname = mdef.name.identifier
      if 'readMap'.equals mname
        readMap = mdef
      elsif 'writeMap'.equals mname
        writeMap = mdef
      end
    end
    
    
    
    #puts "Future is #{classTypeFuture}"
    #puts "Type system: #{@types}"
    classType = @types.findTypeDefinition(classTypeFuture)
    mtype = MirrorType(@types.loadNamedType(classTypeResolved.name).resolve)
    #puts "Class type is #{classType}"
    #puts "M type is #{mtype}"
    
    # Create nodes for the bodies of readMap and writeMap
    readMapBody = NodeList.new
    writeMapBody = NodeList.new
    
    #puts "on line 115 #{TypeUtil.getPublicPropertiesAndAccessors(mtype)}"
    
    # Create the body for the writeMap() method.
    # Just loop through all public properties and accessor methods
    # and call the set(Map,String,Object) method on each with the passed
    # Map object.
    TypeUtil.getPublicPropertiesAndAccessors(mtype).each do |method|
      next if "getClass".equals(method.name) 
        #getClass isn't the kind of accessor we're looking for
      
      propName = SimpleString.new(TypeUtil.getPropNameFromGetter(method.name))
      #puts "Prop name is #{propName}"
      tmpSrc = Cast.new(
          @call.position,
          @klass.typeref,
          @mirah.quote { src }
        )
      n = @mirah.quote do
        set(dest, `propName`, `tmpSrc`.`"#{method.name}"`)
      end
      writeMapBody.add(n)
    end
    writeMap.body.add writeMapBody
    
    
    # Create the body for the readMap() method. 
    # Just loop through all setter methods and public properties
    # and get corresponding values from the Map.
    TypeUtil.getMethodDefinitions(mtype).each do | method:JVMMethod |
      if TypeUtil.isSetter(method) or TypeUtil.isField(method)
        o = if TypeUtil.isField(method)
          method.returnType
        else
          method.argumentTypes.get(0)
        end
        signatureStruct=nil
        if method.kind_of? Member
          signature = Member(method).signature
          if signature 
            #puts "Reading signature #{signature}"
            reader = SignatureReader.new(signature.toString)
            visitor = BaseSignatureVisitor.new(1)
            reader.accept visitor
            signatureStruct = visitor.getParameters
          end
          
        else
          nil
        end
        
        resolved = nil
        is_array = false
        if o.kind_of? ArrayType
          #puts "Array type #{ArrayType(o).name}"
          resolved = ArrayType(o)
          is_array = true
        elsif o.kind_of? BaseType
          #puts 'base type '
          resolved = BaseType(o)
          #if  o.kind_of? BytecodeMirror
            #puts "Element type #{BytecodeMirror(o).getAsmType.getElementType}"
            #puts "ASM Type #{BytecodeMirror(o).getAsmType}"
            #puts "Signature: #{BytecodeMirror(o).signature}"
            #puts "Name: :#{BytecodeMirror(o).name}"
            #puts "Method name: #{method.name}"
          #end
        elsif o.kind_of? MirrorType
          #puts 'mirrortype'
          resolved = MirrorType(o)
        else
          #puts 'future type'
          resolved =TypeFuture(o).resolve
          
        end
        
        #puts "O class is #{o.getClass}"
        propName = if TypeUtil.isField(method)
          SimpleString.new(method.name)
        else
          SimpleString.new(TypeUtil.getPropNameFromSetter(method.name))
        end
        
        #puts "Resolved type #{resolved.name}"
        
        typeref = if is_array
          TypeRefImpl.new(ArrayType(o).getComponentType.name, true, true, @call.target.position)
        else
          TypeRefImpl.new(resolved.name, false, true, @call.target.position)
        end
        
        componentTypeRef = if is_array
          TypeRefImpl.new(ArrayType(o).getComponentType.name, false, true, @call.target.position)
        else
          nil
        end
        
        
        tmpScalar = if 'int'.equals resolved.name
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getInt(src, `propName`)}
          )
        elsif 'double'.equals resolved.name 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getDouble(src, `propName`)}
          )
        elsif 'float'.equals resolved.name 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getFloat(src, `propName`)}
          )
        elsif 'char'.equals resolved.name 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getChar(src, `propName`)}
          )
        elsif 'boolean'.equals resolved.name 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getBoolean(src, `propName`)}
          )
        elsif 'short'.equals resolved.name 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getFloat(src, `propName`)}
          )
        elsif 'long'.equals resolved.name 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getLong(src, `propName`)}
          )
        elsif 'byte'.equals resolved.name 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getByte(src, `propName`)}
          )
        elsif 'java.util.Date'.equals resolved.name 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getDate(src, `propName`)}
          )
        elsif TypeUtil.isPrimitiveArray(resolved.name)
          
          @mirah.quote do
            to_primitive_array(get(src, `propName`), `componentTypeRef`)
          end
        elsif 'java.lang.String[]'.equals resolved.name
          #puts 'Resolving String array'
          @mirah.quote do
            to_string_array(get(src, `propName`))
          end
        elsif 'java.util.Date[]'.equals resolved.name
          #puts 'Resolving Date array'
          @mirah.quote do
            getDateArray(src, `propName`)
          end
        elsif is_array
          @mirah.quote do
            cast_array getObjects(src, `propName`, `componentTypeRef`.class).toArray, `componentTypeRef`
          end
        else
          #puts 'Default resolve for '+propName
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{get(src, `propName`, `typeref`.class)}
          )
        end
        
        
        # If this is a vector type, we need to find out the type of each item
        # If we can't find this out, then we need to skip it.
        if listType.assignableFrom(resolved)
          componentTypeRef = nil
          paramStruct = if signatureStruct and !signatureStruct.isEmpty 
            signatureStruct.get(0)
          else
            nil
          end
          if !paramStruct.getParameters.isEmpty
            pType = paramStruct.getParameters[0].type
            componentTypeRef = TypeRefImpl.new(pType.getClassName, false, true, @call.target.position)
            
            
          end
        elsif mapType.assignableFrom(resolved)
          keyTypeRef = nil
          valTypeRef = nil
          params = if signatureStruct and !signatureStruct.isEmpty
            signatureStruct.get(0).getParameters
          else
            nil
          end
          if params.size == 2
            keyTypeRef = TypeRefImpl.new(params.get(0).type.getClassName, false, true, @call.target.position)
            valTypeRef = TypeRefImpl.new(params.get(1).type.getClassName, false, true, @call.target.position)
          end
          
          
        end
        
        
        tmpVector = if componentTypeRef 
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getList(src, `propName`, `componentTypeRef`.class)}
          )
        else
          nil
        end
        
        
        
        tmpMap = if valTypeRef and keyTypeRef and 'java.lang.String'.equals(keyTypeRef.name)
          Cast.new(
            @call.position, 
            typeref, 
            @mirah.quote{getMap(src, `propName`, `valTypeRef`.class)}
          )
        else
          nil
        end
        
        tmpDest = Cast.new(
          @call.position,
          @klass.typeref,
          @mirah.quote { dest }
        )
        
        if TypeUtil.isField(method)
          tmpOut = @mirah.quote{`gensym`}
          if listType.assignableFrom(resolved) and tmpVector
            n = @mirah.quote do
              if exists(src, `propName`)
                tempdest.foo = `tmpVector`
              end  
            end
          elsif mapType.assignableFrom(resolved) and tmpMap
            n = @mirah.quote do
              if exists(src, `propName`)
                tempdest.foo = `tmpMap`
              end  
            end
          else
            n = @mirah.quote do
              if exists(src, `propName`)
                tempdest.foo =`tmpScalar`
              end  
            end
          end
          
          
          afinder = AttrAssignFinder.new
          n.accept afinder, nil
          #puts "Results #{afinder.results}"
          attrAssign = afinder.results[0]
          attrAssign.target = tmpDest
          attrAssign.name = SimpleString.new(method.name)
          #puts AstFormatter.new(attrAssign)
          #puts AstFormatter.new(n)
          
          
          
        else
          if listType.assignableFrom(resolved) and tmpVector
            n = @mirah.quote do
              if exists(src, `propName`)
                `tmpDest`.`"#{method.name}"` `tmpVector`
              end  
            end
          elsif mapType.assignableFrom(resolved) and tmpMap
            n = @mirah.quote do
              if exists(src, `propName`)
                `tmpDest`.`"#{method.name}"` `tmpMap`
              end  
            end
          else
            n = @mirah.quote do
              if exists(src, `propName`)
                `tmpDest`.`"#{method.name}"` `tmpScalar`
              end  
            end
          end
        end
          
        
        readMapBody.add n
      end
    end
    
    readMap.body.add readMapBody
    
    # Now we need to add this class to our script
    cls
    
  end
  
  
  
  def isGetter(method:JVMMethod):boolean
    if method.kind != MemberKind.METHOD
      return false
    end
    if method.argumentTypes.size != 0
      return false
    end
    if 'void'.equals(method.returnType.name)
      return false
    end
      
    true
  end
  
  
  
  def box(type:TypeFuture):DerivedFuture
    @types.box(type)
  end
  
  def gensym: String
    @mirah.scoper.getScope(@call).temp('gensym')
  end
end

