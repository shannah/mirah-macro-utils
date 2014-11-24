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
/**
 *
 * @author shannah
 */
class MappableBuilder 
  
  def initialize(mirah:Compiler, call:CallSite)
    @mirah = mirah
    @call = call
    @typer = mirah.typer
    @types = MirrorTypeSystem(@typer.type_system)
   
    @scoper = @typer.scoper
    @scope = @scoper.getScope(call)
  end
  
  def generateMappableMethods(klass:ClassDefinition):void
    
    
    stringType = @types.getStringType.resolve
    mappableType = @types.wrap(
        Type.getType('Lca/weblite/codename1/mapper/Mappable;')
    ).resolve
    #@types.findTypeDefinition(@types.getStringType).
    intType = @types.wrap(Type.getType('I')).resolve
    longType = @types.wrap(Type.getType('J')).resolve
    doubleType = @types.wrap(Type.getType('D')).resolve
    
    #puts "Mappable type is #{mappableType}"
    
    
    finder = MethodFinder.new
    klass.accept finder, nil
    methods = finder.results
    
    readMapBody = NodeList.new
    writeMapBody = NodeList.new
    
    readMap = @mirah.quote do
      def readMap(map:Map, mapper:Mapper):void

      end         
    end
    
    
    imports = @mirah.quote do
      import java.util.Map
      import ca.weblite.codename1.mapper.Mapper
      import ca.weblite.codename1.mapper.Mappable
    end

    writeMap = @mirah.quote do
      def writeMap(map:Map, mapper:Mapper):void

      end
    end
    methodsAlreadyExist = false
    methods.each do |mdef:MethodDefinition|
      mname = mdef.name.identifier
      #puts "Found method #{mname}"
      if 'readMap'.equals mname or 'writeMap'.equals mname
        methodsAlreadyExist = true
      end
      if methodsAlreadyExist
        next
      end
      num_args = mdef.arguments.required_size
      
      if (mname.startsWith('set') or mname.endsWith('_set')) and num_args == 1
        propName = getPropNameFromSetter(mname)
        
        argType = mdef.arguments.required(0).type.typeref
        #puts mdef.arguments.required(0).type.typeref.name
        resolved = @types.get(@scope, argType).resolve
        #puts "Resolved type #{resolved.name}"
        
        readMethod = if stringType.assignableFrom(resolved)
          'readString'
        elsif mappableType.assignableFrom(resolved)
          'readMappable'
        elsif resolved.name == 'int'
          'readInt'
        elsif resolved.name == 'long'
          'readLong'
        elsif resolved.name == 'double'
          'readDouble'
        elsif resolved.name == 'float'
          'readFloat'
        elsif resolved.name == 'short'
          'readShort'
        elsif resolved.name == 'char'
          'readChar'
        elsif resolved.name == 'boolean'
          'readBoolean'
        else
          nil
        end
        
        
        if readMethod != nil
          if 'readMappable'.equals(readMethod)
            propNameStr = SimpleString.new(propName)
            tmp = Cast.new(
              @call.position, 
              TypeRefImpl.new(resolved.name, false, true, @call.target.position), 
              @mirah.quote{mapper.`readMethod`(map, `propNameStr`, `argType`.class)}
            )
            readMapBody.add @mirah.quote do
              if map.containsKey(`propNameStr`)
                `"#{mname}"` `tmp`
              end
            end
          else
            propNameStr = SimpleString.new(propName)
            readMapBody.add @mirah.quote do
              if map.containsKey(`propNameStr`)
                `"#{mname}"` mapper.`readMethod`(map, `propNameStr`)
              end
            end
          end
          
        end
      end
      
    end
    if methodsAlreadyExist
      return
    end

    readMap.body.add readMapBody
    klass.body.add imports

    #puts "Adding readMap!!!"

    klass.body.add readMap
    klass.body.add writeMap
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
end

