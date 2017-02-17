#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;
using StringTools;

class TypeScriptDeclarationGenerator {
    static function use() {
        Context.onGenerate(function(types) {
            var exposedClasses = [];
            for (type in types) {
                switch (type.follow()) {
                    case TInst(_.get() => cl, _):
                        if (cl.meta.has(":expose") || Lambda.exists(cl.statics.get(), function(f) return f.meta.has(":expose")))
                            exposedClasses.push(cl);
                    default:
                }
            }
            if (exposedClasses.length > 0)
                Context.onAfterGenerate(function() {
                    var declarations = ["// Generated by Haxe TypeScript Declaration Generator :)"];
                    for (cl in exposedClasses) {
                        if (cl.meta.has(":expose")) {
                            declarations.push(generateClassDeclaration(cl));
                        }
                    }
                    var outJS = Compiler.getOutput();
                    var outDTS = Path.withoutExtension(outJS) + ".d.ts";
                    sys.io.File.saveContent(outDTS, declarations.join("\n\n"));
                });
        });
    }

    static function generateClassDeclaration(cl:ClassType):String {
        var parts = [];
        parts.push('declare class ${cl.name} {');

        if (cl.constructor != null) {
            var ctor = cl.constructor.get();
            if (ctor.isPublic)
                switch (ctor.type) {
                    case TFun(args, _):
                        var args = args.map(convertArg);
                        parts.push('\tconstructor(${args.join(", ")});');
                    default: throw "wtf";
                }
        }

        for (field in cl.statics.get()) {
            if (field.isPublic) {
                if (field.doc != null) {
                    parts.push("\t/**");
                    var lines = field.doc.split("\n");
                    for (line in lines) {
                        line = line.trim();
                        if (line.length > 0)
                            parts.push('\t\t$line');
                    }
                    parts.push("\t*/");
                }

                switch (field.type) {
                    case TFun(args, ret):
                        var args = args.map(convertArg);
                        parts.push('\tstatic ${field.name}(${args.join(", ")}): ${convertTypeRef(ret)};');

                    default:
                }
            }
        }

        parts.push('}');
        return parts.join("\n");
    }

    static function convertArg(arg:{name:String, opt:Bool, t:Type}):String {
        var argString = arg.name;
        if (arg.opt) argString += "?";
        argString += ": " + convertTypeRef(arg.t);
        return argString;
    }

    static function convertTypeRef(t:Type):String {
        return switch (t.followWithAbstracts().toString()) {
            case "String": "string";
            case "Int" | "Float": "number";
            case "Bool": "boolean";
            case "Void": "void";
            case other: other;
        }
    }
}
#end