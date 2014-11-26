/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

package ca.weblite.mirah.utils
import java.util.HashSet
import org.mirah.jvm.types.MemberKind
import org.mirah.jvm.types.JVMMethod
import org.mirah.jvm.mirrors.Member
import org.objectweb.asm.Opcodes
import org.mirah.typer.DerivedFuture
import org.mirah.typer.TypeFuture
import org.mirah.jvm.mirrors.MirrorType


/**
 *
 * @author shannah
 */
class TypeUtil 
  def self.getProperties(type:MirrorType):JVMMethod[]
    out = []
    type.getDeclaredFields.each{|f| out.add f}
    getProperties(MirrorType(type.superclass)).each{ |m| out.add m} unless !type.superclass.kind_of? MirrorType
    filtered = []
    usedNames = HashSet.new
    out.each do |m|
      mdef = JVMMethod(m)
      
      
      unless [MemberKind.FIELD_ACCESS].contains(mdef.kind)
        next
      end
      
      if !usedNames.contains mdef.name
        usedNames.add mdef.name
        filtered.add mdef
      end
    end
    filtered.toArray(JVMMethod[0])
    
  end
  
  def self.getPropertiesWithAccess(type:MirrorType, access:int):JVMMethod[]
    out = []
    getProperties(type).each do |m|
      if m.kind_of? Member
        mem = Member(m)
        if mem.flags & access
          out.add mem
        end
      end
    end
    out.toArray(JVMMethod[0])
  end
  
  def self.getPublicProperties(type:MirrorType):JVMMethod[]
    getPropertiesWithAccess(type, Opcodes.ACC_PUBLIC)
  end
  
  def self.getPrivateProperties(type:MirrorType):JVMMethod[]
    getPropertiesWithAccess(type, Opcodes.ACC_PRIVATE)
  end
  
  def self.getProtectedProperties(type:MirrorType):JVMMethod[]
    getPropertiesWithAccess(type, Opcodes.ACC_PROTECTED)
  end
  
  
  def self.getNonPublicProperties(type:MirrorType):JVMMethod[]
    out = []
    getProperties(type).each do |m|
      if m.kind_of? Member
        mem = Member(m)
        if mem.flags & Opcodes.ACC_PUBLIC == 0
          out.add mem
        end
      end
    end
    out.toArray(JVMMethod[0])
  end
  
  
  def self.getMethods(type:MirrorType):JVMMethod[]
    out = []
    type.getAllDeclaredMethods.each{|f| out.add f}
    getMethods(MirrorType(type.superclass)).each{ |m| out.add m} unless !type.superclass.kind_of? MirrorType
    filtered = []
    usedNames = HashSet.new
    out.each do |m|
      mdef = JVMMethod(m)
      
      
      unless [MemberKind.METHOD].contains(mdef.kind)
        next
      end
      
      if !usedNames.contains mdef.name
        usedNames.add mdef.name
        filtered.add mdef
      end
    end
    filtered.toArray(JVMMethod[0])
    
  end
  
  def self.getMethodsWithAccess(type:MirrorType, access:int):JVMMethod[]
    out = []
    getMethods(type).each do |m|
      if m.kind_of? Member
        mem = Member(m)
        if mem.flags & access
          out.add mem
        end
      end
    end
    out.toArray(JVMMethod[0])
  end
  
  def self.getPublicMethods(type:MirrorType):JVMMethod[]
    getMethodsWithAccess(type, Opcodes.ACC_PUBLIC)
  end
  
  def self.getPrivateMethods(type:MirrorType):JVMMethod[]
    getMethodsWithAccess(type, Opcodes.ACC_PRIVATE)
  end
  
  def self.getProtectedMethods(type:MirrorType):JVMMethod[]
    getMethodsWithAccess(type, Opcodes.ACC_PROTECTED)
  end
  
  def self.getNonPublicMethods(type:MirrorType):JVMMethod[]
    out = []
    getMethods(type).each do |m|
      if m.kind_of? Member
        mem = Member(m)
        if mem.flags & Opcodes.ACC_PUBLIC == 0
          out.add mem
        end
      end
    end
    out.toArray(JVMMethod[0])
  end
  
  def self.getAccessorsFor(type:MirrorType, properties:JVMMethod[]):JVMMethod[]
    candidates = []
    properties.each do |p|
      getPublicMethods(type).each do |m|
        pname = getPropNameFromGetter(m.name)
        if pname.equals(p.name) and 
            m.argumentTypes.size==0 and 
            m.returnType==p.returnType
          candidates.add(m)
        end
      end
    end
    candidates.toArray(JVMMethod[0])
  end
  
  def self.getAccessors(type:MirrorType):JVMMethod[]
    candidates = []
    usedNames = HashSet.new
    getPublicMethods(type).each do |m|
      pname = getPropNameFromGetter(m.name)
      puts "Checking pub method #{m}"
      if m.name.length > 3 and m.name.startsWith('get') and
      
      
          m.argumentTypes.size==0 and 
          !'void'.equals(m.returnType.name) and
          !usedNames.contains(pname)
        usedNames.add(pname)
        candidates.add(m)
      end
    end
    getAccessorsFor(type, getNonPublicProperties(type)).each do |m| 
      pname = getPropNameFromGetter(m.name)
      if !usedNames.contains(pname)
        usedNames.add(pname)
        candidates.add(m)
      end
      
    end
    candidates.toArray(JVMMethod[0])
  end
  
  def self.getPublicPropertiesAndAccessors(type:MirrorType):JVMMethod[]
    out = []
    usedNames = HashSet.new
    getAccessors(type).each do |m| 
      pname = getPropNameFromGetter(m.name)
      if !usedNames.contains(pname)
        usedNames.add(pname)
        out.add(m)
      end
      
    end
    getPublicProperties(type).each do |p| 
      if !usedNames.contains(p.name)
        usedNames.add(p.name)
        out.add(p)
      end
      
    end
    
    out.toArray(JVMMethod[0])
  end
  
  
  
  def self.isSetter(method:JVMMethod):boolean
    if method.kind != MemberKind.METHOD
      return false
    end
    if !method.name.startsWith('set') and !method.name.endsWith('_set')
      return false
    end
    if method.argumentTypes.size != 1
      return false
    end
    true
  end
  
  def self.isField(method:JVMMethod):boolean
    return method.kind == MemberKind.FIELD_ACCESS
  end
  
  
  
  def self.isPrimitiveArray(name:String):boolean
    return 'int[]'.equals(name) ||
      'double[]'.equals(name) ||
      'short[]'.equals(name) ||
      'long[]'.equals(name) ||
      'float[]'.equals(name) ||
      'byte[]'.equals(name) ||
      'char[]'.equals(name) ||
      'boolean[]'.equals(name)
  end
  
  # Gets all public member methods, and all public member fields of the 
  # given type.
  def self.getMethodDefinitions(type:MirrorType):JVMMethod[]
    out = []
    type.getDeclaredFields.each{|f| out.add f}
    type.getAllDeclaredMethods.each{|m| out.add m}
    getMethodDefinitions(MirrorType(type.superclass)).each{ |m| out.add m} unless !type.superclass.kind_of? MirrorType
    filtered = []
    usedNames = HashSet.new
    out.each do |m|
      mdef = JVMMethod(m)
      
      if mdef.kind_of? Member
        member = Member(mdef)
        unless member.flags & Opcodes.ACC_PUBLIC
          next
        end
      else
        next
      end
      
      unless [MemberKind.METHOD, MemberKind.FIELD_ACCESS].contains(mdef.kind)
        next
      end
      
      if !usedNames.contains mdef.name
        usedNames.add mdef.name
        filtered.add mdef
      end
    end
    filtered.toArray(JVMMethod[0])
  end
  
  def self.getPropNameFromSetter(methodName:String):String
    if methodName.endsWith '_set'
      return methodName.substring(0, methodName.lastIndexOf('_'))
    elsif methodName.startsWith 'set'
      substr = methodName.substring(3)
      return "#{substr.charAt(0)}".toLowerCase + substr.substring(1)
    else
      raise "#{methodName} is not a setter method"
    end
  end
  
  def self.getPropNameFromGetter(methodName:String):String
    if methodName.startsWith 'get'
      substr = methodName.substring(3)
      return "#{substr.charAt(0)}".toLowerCase + substr.substring(1)
    else
      return methodName
    end
  end
  
end

