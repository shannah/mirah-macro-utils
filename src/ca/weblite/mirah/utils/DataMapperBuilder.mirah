/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
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
import org.mirah.jvm.mirrors.BytecodeMirror
import org.mirah.jvm.mirrors.MirahMethod
import org.mirah.jvm.mirrors.Member
import org.objectweb.asm.signature.SignatureReader

/**
 *
 * @author shannah
 */
class DataMapperBuilder 
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
  
  def build:Node
    
    classTypeFuture = @types.get(@scope, @klass.typeref)
    classTypeResolved = classTypeFuture.resolve
    
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
    
    readMapBody = NodeList.new
    
    mtype.getAllDeclaredMethods.each do | method:JVMMethod |
      if isSetter(method)
        o = method.argumentTypes.get(0)
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
        propName = SimpleString.new(getPropNameFromSetter(method.name))
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
        elsif isPrimitiveArray(resolved.name)
          
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
        
        readMapBody.add n
      end
    end
    
    readMap.body.add readMapBody
    
    # Now we need to add this class to our script
    cls
    
  end
  
  def getPropNameFromSetter(methodName:String):String
    if methodName.endsWith '_set'
      return methodName.substring(0, methodName.lastIndexOf('_'))
    elsif methodName.startsWith 'set'
      substr = methodName.substring(3)
      return "#{substr.charAt(0)}".toLowerCase + substr.substring(1)
    else
      raise "#{methodName} is not a setter method"
    end
  end
  
  def isSetter(method:JVMMethod):boolean
    if !method.name.startsWith('set') and !method.name.endsWith('_set')
      return false
    end
    if method.argumentTypes.size != 1
      return false
    end
    true
  end
  
  def box(type:TypeFuture):DerivedFuture
    @types.box(type)
  end
  
  def isPrimitiveArray(name:String):boolean
    return 'int[]'.equals(name) ||
      'double[]'.equals(name) ||
      'short[]'.equals(name) ||
      'long[]'.equals(name) ||
      'float[]'.equals(name) ||
      'byte[]'.equals(name) ||
      'char[]'.equals(name) ||
      'boolean[]'.equals(name)
  end
  
  
end

