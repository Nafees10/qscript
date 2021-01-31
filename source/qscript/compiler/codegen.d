/++
For generating byte code from AST
+/
module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.compiler;

import navm.bytecode;

import utils.misc;
import utils.lists;

/// Contains functions to generate NaByteCode from AST nodes
class CodeGen{
private:
	NaBytecode _bytecode;
	ScriptNode _script;
	Library[] _libs;
	
}
