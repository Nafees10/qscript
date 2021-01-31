/++
For generating byte code from AST
+/
module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.astcheck;

import utils.misc;
import utils.lists;

import navm.bytecode;

import std.conv : to;

/// Contains functions to generate NaByteCode from AST nodes
class CodeGen{
private:
	NaBytecode _bytecode;
}
