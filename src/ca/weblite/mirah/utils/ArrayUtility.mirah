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
/**
 *
 * @author shannah
 */
class ArrayUtility
  def initialize(mirah:Compiler, call:CallSite)
    @mirah=mirah
    @typer = @mirah.typer
    @types = MirrorTypeSystem(@typer.type_system)
    @call=call
    @scoper = @typer.scoper
    @scope = @scoper.getScope(call)
    
  end
  
  def gensym: String
    @mirah.scoper.getScope(@call).temp('gensym')
  end
  
  def to_string_array(target:Node):Node
    @mirah.quote do
      if `target` == nil
        nil
      elsif `target`.kind_of? java::util::List
        cast_array(DataMapper.toArray(java::util::List(`target`)), String)
      elsif `target`.kind_of? Object[]
        cast_array(Object[].cast(`target`), String)
      else
        raise "Cannot convert type #{`target`.getClass} to string array"
      end
    end
  end
  
  def to_primitive_array(target:Node, destType:TypeName):Node
    
    boolCast = Cast.new(
      @call.position,
      TypeRefImpl.new('boolean', true, true, @call.target.position),
      target
    )
    objectCast = Cast.new(
      @call.position,
      TypeRefImpl.new('java.lang.Object', true, true, @call.target.position),
      target
    )
    
    intCast = Cast.new(
      @call.position,
      TypeRefImpl.new('int', true, true, @call.target.position),
      target
    )
    
    doubleCast = Cast.new(
      @call.position,
      TypeRefImpl.new('double', true, true, @call.target.position),
      target
    )
    
    
    floatCast = Cast.new(
      @call.position,
      TypeRefImpl.new('float', true, true, @call.target.position),
      target
    )
    
    longCast = Cast.new(
      @call.position,
      TypeRefImpl.new('long', true, true, @call.target.position),
      target
    )
    
    
    
    @mirah.quote do
    
      if `target`.kind_of? java::util::List
        unbox_list(`target`, `destType`)
      elsif `target`.kind_of? Object[]
        unbox_array(`target`, `destType`)
      elsif `target`.kind_of? int[]
        cast_array(int[].cast(`target`), `destType`)
      elsif `target`.kind_of? double[]
        cast_array(double[].cast(`target`), `destType`)
      elsif `target`.kind_of? float[]
        cast_array(float[].cast(`target`), `destType`)
      elsif `target`.kind_of? short[]
        cast_array(short[].cast(`target`), `destType`)
      elsif `target`.kind_of? byte[]
        cast_array(byte[].cast(`target`), `destType`)
      elsif `target`.kind_of? char[]
        cast_array(char[].cast(`target`), `destType`)
      #elsif `target`.getClass == boolean[]
      #  cast_array(`boolCast`, `destType`)
      elsif `target`.kind_of? long[]
        cast_array(long[].cast(`target`), `destType`)
      else
        raise "Invalid type to convert to primitive array: #{`target`.getClass}"
      end
    end
  end
  
  def unbox_array(target:Node, destType:TypeName):Node
    targetRef = TypeRefImpl.new('java.lang.Object', true, true, @call.target.position)
    target = Cast.new(
      @call.position, 
      targetRef, 
      target
    )
    
    destTypeName = destType.typeref.name
    array = gensym
    i = gensym
    out = @mirah.quote{`gensym`}
    getter = if 'int'.equals destTypeName
      @mirah.quote { NumberUtil.intValue(`array`[`i`]) }
    elsif 'double'.equals destTypeName
      @mirah.quote { NumberUtil.doubleValue(`array`[`i`]) }
    elsif 'short'.equals destTypeName
      @mirah.quote { NumberUtil.shortValue(`array`[`i`]) }
    elsif 'float'.equals destTypeName
      @mirah.quote { NumberUtil.floatValue(`array`[`i`]) }
    elsif 'long'.equals destTypeName
      @mirah.quote { NumberUtil.longValue(`array`[`i`]) }
    elsif 'byte'.equals destTypeName
      @mirah.quote { NumberUtil.byteValue(`array`[`i`]) }
    elsif 'boolean'.equals destTypeName
      @mirah.quote { NumberUtil.booleanValue(`array`[`i`]) }
    elsif 'char'.equals destTypeName
      @mirah.quote { NumberUtil.charValue(`array`[`i`]) }
    end
    #getter = Cast.new(@call.position, destType, getter)
    #puts "Before q"
    q = @mirah.quote { __temp = `destType`[`target`.length]; __temp[`i`] = `getter` }
    #puts "After q"
    #puts AstFormatter.new(q)
    finder = ElemAssignFinder.new
    q.accept finder, nil
    elAssign = finder.results[0]
    elAssign.target = out
    @mirah.quote do
      import ca.weblite.codename1.mapper.NumberUtil
      begin
        `out` = `destType`[`target`.length]
        while `i`<`array`.length 
            init {  `array` = `target`; `i`=0 }
            pre { `elAssign` }
            post { `i` = `i`+1 }
            
        end
        `out`
      end
        
    end
  end
end

