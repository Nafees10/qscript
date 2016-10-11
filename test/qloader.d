module qloader;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.sys.posix.dlfcn;

union Tqvar{
	double d;
	string s;
	Tqvar[] array;
}

class Tqloader{
private:
	alias execProc = Tqvar delegate(string name, Tqvar[] args);
	
	alias TsetExec = extern(C) void function(execProc);
	alias TinitEnd = extern(C) void function();
	alias Texecute = extern(C) void function(string);
	alias TloadScript = extern(C) string[] function(string);
	
	void* libso;
	TinitEnd init, term;
public:
	TsetExec setExec;
	Texecute execute;
	TloadScript loadScript;
	
	this(){
		libso = dlopen("/home/nafees/projects/qscript/qscript/bin/Debug/libqscript.so",
			RTLD_LAZY);
		
		if (!libso){
			throw new Exception("Failed to load QScript2.");
		}else{
			char* error;
			
			init = cast(TinitEnd)dlsym(libso,"init");
			error = dlerror();
			if (error){fprintf(stderr, "dlsym error: %s\n", error);}
			
			term = cast(TinitEnd)dlsym(libso,"term");
			error = dlerror();
			if (error){fprintf(stderr, "dlsym error: %s\n", error);}
			
			setExec = cast(TsetExec)dlsym(libso,"onExec");
			error = dlerror();
			if (error){fprintf(stderr, "dlsym error: %s\n", error);}
			
			execute = cast(Texecute)dlsym(libso,"execute");
			error = dlerror();
			if (error){fprintf(stderr, "dlsym error: %s\n", error);}
			
			loadScript = cast(TloadScript)dlsym(libso,"loadScript");
			error = dlerror();
			if (error){fprintf(stderr, "dlsym error: %s\n", error);}
			
			init();
		}
	}
	~this(){
		term();
		dlclose(libso);
	}
}