/++
For generating byte code from AST
+/
module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.astcheck;
import qscript.compiler.misc;
import qscript.compiler.compiler : Function;

import utils.misc;
import utils.lists;

import std.conv : to;
