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
package ca.weblite.mirah.utils;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.Type;
import org.objectweb.asm.signature.SignatureVisitor;

/**
 *
 * @author shannah
 */
public class BaseSignatureVisitor extends SignatureVisitor {
    
    public static class Parameter {
        public Type type;
        public List<Parameter> parameters=new ArrayList<Parameter>();
        public String toString(){
            return type.getClassName()+"<"+parameters+">";
        }
        public List<Parameter> getParameters(){
            return parameters;
        }
    }
    
    List<Parameter> parameters = new ArrayList<Parameter>();
    Parameter returnType;
    
    LinkedList<Parameter> context = new LinkedList<Parameter>();
    
    public BaseSignatureVisitor(int version) {
        super(Opcodes.ASM4);
    }

    @Override
    public void visitTypeVariable(String string) {
        //System.out.println("Visiting Type variable "+string);
        super.visitTypeVariable(string); //To change body of generated methods, choose Tools | Templates.
    }

    @Override
    public void visitFormalTypeParameter(String string) {
        //System.out.println("Visiting Formal Type variable "+string);
        super.visitFormalTypeParameter(string); //To change body of generated methods, choose Tools | Templates.
    }

    @Override
    public SignatureVisitor visitParameterType() {
        if ( !context.isEmpty()){
            context.pop();
        }
        Parameter p = new Parameter();
        context.push(p);
        parameters.add(p);
        return super.visitParameterType(); //To change body of generated methods, choose Tools | Templates.
        
    }

    @Override
    public SignatureVisitor visitTypeArgument(char c) {
        Parameter p = new Parameter();
        if ( !context.isEmpty()){
            context.peek().parameters.add(p);
            context.push(p);
        }
        return super.visitTypeArgument(c); //To change body of generated methods, choose Tools | Templates.
    }

    @Override
    public void visitBaseType(char c) {
        if ( !context.isEmpty()){
             Parameter p = context.peek();
            p.type = Type.getType(""+c);
            parameters.add(p);
        }
       
        super.visitBaseType(c); //To change body of generated methods, choose Tools | Templates.
    }

    @Override
    public void visitClassType(String string) {
        if ( !context.isEmpty()){
            Parameter p = context.peek();
            p.type = Type.getObjectType(string);
        }
        //System.out.println("Visiting class type "+string);
        super.visitClassType(string); //To change body of generated methods, choose Tools | Templates.
    }

    @Override
    public void visitEnd() {
        if ( !context.isEmpty()){
            context.pop();
        }
        super.visitEnd(); //To change body of generated methods, choose Tools | Templates.
    }

    @Override
    public SignatureVisitor visitReturnType() {
        Parameter p = new Parameter();
        returnType = p;
        if ( !context.isEmpty()){
            context.pop();
        }
        context.push(p);
        return super.visitReturnType(); //To change body of generated methods, choose Tools | Templates.
    }
    
    
    
    
    public List<Parameter> getParameters(){
        return parameters;
    }
    
    
    

    


    
}
