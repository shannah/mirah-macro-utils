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
import java.util.Map

/**
 *
 * @author shannah
 */
class BeanBuilder 
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
      import ca.weblite.codename1.bean.BeanClass
      import java.util.Map
      import ca.weblite.codename1.mapper.NumberUtil
      class `@mapperClass` < BeanClass
        def initialize
          
        end
        def getWrappedClass:Class
          `@klass`.class
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
    
    finder1 = ConstructorFinder.new
    cls.accept finder1, nil
    methods = finder1.results
    
    initializeMethod = nil
    
    methods.each do |mdef:ConstructorDefinition|
      mname = mdef.name.identifier
      if 'initialize'.equals mname
        initializeMethod = mdef
      end
    end
    
    
    
    #puts "Future is #{classTypeFuture}"
    #puts "Type system: #{@types}"
    classType = @types.findTypeDefinition(classTypeFuture)
    mtype = MirrorType(@types.loadNamedType(classTypeResolved.name).resolve)
    #puts "Class type is #{classType}"
    #puts "M type is #{mtype}"
    
    initializeBody = NodeList.new
    
    TypeUtil.getPropertiesAsMap(mtype).entrySet.each do |entry|
      propName = String(entry.getKey)
      propMap = Map(entry.getValue)
      prop = JVMMethod(propMap['property'])
      getter = JVMMethod(propMap['getter'])
      setter = JVMMethod(propMap['setter'])
      
      propNameStr = SimpleString.new(String(propName))
      
      tmpBean = Cast.new(
        @call.position,
        @klass.typeref,
        @mirah.quote { bean }
      )
      n = @mirah.quote do
        self.addProperty do
          def getName:String
            `propNameStr`
          end
          def getType:Class
            nil
          end
          def get(bean:Object):Object
            nil
          end
          def set(bean:Object, value:Object):void
            nil
          end
          
          def isReadable:boolean
            false
          end
          
          def isWritable:boolean
            false
          end
        end
      end
      
      finder = MethodFinder.new
      n.accept finder, nil
      methods = finder.results

      getName = nil
      getType = nil
      get = nil
      set = nil
      isReadable = nil
      isWritable = nil
      
      methods.each do |mdef:MethodDefinition|
        mname = mdef.name.identifier
        if 'getName'.equals mname
          getName = mdef
        elsif 'getType'.equals mname
          getType = mdef
        elsif 'get'.equals mname
          get = mdef
        elsif 'set'.equals mname
          set = mdef
        elsif 'isReadable'.equals mname
          isReadable = mdef
        elsif 'isWritable'.equals mname
          isWritable = mdef
        end
      end
      
      if getter
        get.body.add(@mirah.quote{ `tmpBean`.`"#{getter.name}"`})
        isReadable.body = NodeList.new
        isReadable.body.add @mirah.quote{ true }
      elsif prop
        get.body.add(@mirah.quote{ `tmpBean`.`"#{prop.name}"`})
        isReadable.body = NodeList.new
        isReadable.body.add @mirah.quote{ true }
      end
      
      if setter
        argType = JVMType(setter.argumentTypes[0])
        val = @mirah.quote {value}
        if 'int'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.intValue(value)}
        elsif 'double'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.doubleValue(value)}
        elsif 'float'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.floatValue(value)}
        elsif 'short'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.shortValue(value)}
        elsif 'byte'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.byteValue(value)}
        elsif 'long'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.longValue(value)}
        elsif 'char'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.charValue(value)}
        elsif 'boolean'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.booleanValue(value)}
        else
          val = cast(argType.name, val)
        end
        set.body.add(@mirah.quote{ `tmpBean`.`"#{setter.name}"` `val`})
        isWritable.body = NodeList.new
        isWritable.body.add @mirah.quote {true}
      elsif prop
        argType = JVMType(prop.returnType)
        val = @mirah.quote {value}
        if 'int'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.intValue(value)}
        elsif 'double'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.doubleValue(value)}
        elsif 'float'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.floatValue(value)}
        elsif 'short'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.shortValue(value)}
        elsif 'byte'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.byteValue(value)}
        elsif 'long'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.longValue(value)}
        elsif 'char'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.charValue(value)}
        elsif 'boolean'.equals(argType.name)
          val = @mirah.quote{ NumberUtil.booleanValue(value)}
        else
          val = cast(argType.name, val)
        end
        
        
        n2 = @mirah.quote do
          if true
            tempdest.foo = `val`
          end
        end
        #puts 'We are here'
        #puts AstFormatter.new(attrAssign)
          
          
        afinder = AttrAssignFinder.new
        n2.accept afinder, nil
        #puts "Results #{afinder.results}"
        #puts "On line 240"
        attrAssign = afinder.results[0]
        attrAssign.target = tmpBean
        attrAssign.name = SimpleString.new(prop.name)
        
        #set.body = NodeList.new
        #attrAssign.setParent(set.body)
        set.body.add n2
        
        isWritable.body = NodeList.new
        isWritable.body.add @mirah.quote {true}
      end
      
      initializeBody.add(n)
    end
    initializeMethod.body.add initializeBody
    #puts AstFormatter.new(cls)
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
  
  def cast(className:String, node:Node):Node
    is_array = className.endsWith('[]')
    if is_array
      className = className.substring(0, className.length-2)
    end
    typeref = TypeRefImpl.new(className, is_array, true, @call.target.position)
    Cast.new(
      @call.position, 
      typeref, 
      node
    )
  end
end

