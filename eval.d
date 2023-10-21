module eval;

// evaluates an AST

import lexer;
import errors;
import parser;

import std.stdio : writefln;
import std.string : strip, startsWith, endsWith, lastIndexOf;
import std.ascii : isDigit, isAlpha;
import std.conv : to;
import std.algorithm : levenshteinDistance;

enum fun3_Type
{
    str, // "str"
    number, // 0-9
    boolean, // true or false
    var, // a variable name
    none, // none
    inline // [ ... ]
}

struct fun3_Value
{
    string value;
    fun3_Type type;
}

fun3_Type fun3_validate_type(string value)
{
    value = strip(value);

    if (startsWith(value, "["))
    {
        return fun3_Type.inline;
    }

    if (value == "true" || value == "false")
    {
        return fun3_Type.boolean;
    }

    if (lex_token_type(value[0]) == f3charType.DIGIT)
    {
        return fun3_Type.number;
    }

    if (startsWith(value, "\""))
    {
        return fun3_Type.str;
    }

    /* if (startsWith(value, "'")) {
        return fun3_Type.str;
    } */

    if (lex_token_type(value[0]) == f3charType.LETTER)
    {
        return fun3_Type.var;
    }

    return fun3_Type.none;
}

// parses a string, returns the content within quotes
string fun3_parse_string(string value)
{
    f3lexerState state = f3lexerState.STATE_START;
    string result = "";
    int i = 0;

    foreach (char c; value)
    {
        if (c == '"' && state == f3lexerState.STATE_START)
        {
            state = f3lexerState.STATE_STRING;
        }
        else if (c == '"' && value[i - 1] != '\\' && state == f3lexerState.STATE_STRING)
        {
            state = f3lexerState.STATE_START;
        }
        else
        {
            result ~= c;
        }
        i++;
    }

    return result;
}

fun3_Value fun3_create_value(string value)
{
    fun3_Value v;

    v.value = value;
    v.type = fun3_validate_type(value);

    if (v.type == fun3_Type.str)
    {
        v.value = fun3_parse_string(strip(v.value));
    }

    return v;
}

fun3_Value[] fun3_create_values(string[] values)
{
    fun3_Value[] v;
    for (int i = 0; i < values.length; i++)
    {
        v ~= fun3_create_value(values[i]);
    }
    return v;
}

fun3_Value[] fun3_create_from_ast_node(ASTNode node)
{
    return fun3_create_values(node.arg);
}

struct fun3_Stat
{
    string fname;
    fun3_Value[] args;
}

struct fun3_Function
{
    string name;
    fun3_Stat[] stats;
}

struct fun3_env
{
    string module_name;
    fun3_Function[string] user_functions;
    fun3_Value function(fun3_env*, fun3_Value[])[string] builtin_functions;
}

fun3_Function create_function(string name, fun3_Stat[] stats)
{
    fun3_Function f;
    f.name = name;
    f.stats = stats;
    return f;
}

/** 
 * Evaluates a statement, returning a list of functions and their call stacks.
 * Params:
 *   statement = the statement to evaluate
 * Note:
 * This function will not accept top-level calls, only declarations. Top-level
 * calls are against the fun3/fun spec.
 */
fun3_Function[string] fun3_evaluate(string statement)
{
    AST a = generate_ast(statement);
    fun3_Function[string] funcs;

    fun3_Function current;
    fun3_Stat current_stat;
    foreach (ASTNode node; a.node)
    { // evaluate all root statements
        if (node.arg.length == 0)
        {
            error([node.id], "F3RootCallException");
        }
        current.name = node.arg[0];

        if (node.type == ASTNodeType.ASTCall)
        {
            writefln("error");
            break;
        }

        foreach (AST next; node.next)
        { // parsing function calls
            foreach (ASTNode n; next.node)
            {
                current_stat.fname = n.id;
                current_stat.args ~= fun3_create_from_ast_node(n);
                current.stats ~= current_stat;
                current_stat = fun3_Stat();
            }
        }

        funcs[current.name] = current;

        current = fun3_Function();
    }

    return funcs;

}

fun3_Value fun3_run_function(fun3_env* env, fun3_Function f)
{
    foreach (fun3_Stat stat; f.stats)
    {
        if (stat.fname in env.builtin_functions)
        {
            env.builtin_functions[stat.fname](env, stat.args);
        }
        else if (stat.fname in env.user_functions)
        {
            fun3_run_function(env, env.user_functions[stat.fname]);
        }
        else
        {
            writefln("fun3: in invocation of ('%s')", stat.fname);

            writefln("\t\x1b[31;1mfun3:\x1b[0m function '%s' not found", stat.fname);

            string exp = "";

            foreach (string n; keys(env.builtin_functions))
            {
                if (levenshteinDistance(stat.fname, n) < 3)
                {
                    exp = n;
                }
            }

            foreach (string n; keys(env.user_functions))
            {
                if (levenshteinDistance(stat.fname, n) < 3)
                {
                    exp = n;
                }
            }

            if (exp != "")
            {
                writefln("\t\x1b[31;1mfun3:\x1b[0m did you mean '%s'?", exp);
            }

            error([stat.fname], "F3FunctionNotFoundException");
        }
    }

    return fun3_create_value("0");
}

void fun3_env_add_function(fun3_env* env, string name, fun3_Value function(fun3_env*, fun3_Value[]) f)
{
    env.builtin_functions[name] = f;
}

fun3_Value fun3_exec(fun3_env* env, ASTNode node)
{
    if (node.type != ASTNodeType.ASTCall)
        return fun3_create_value("0");

    fun3_Value[] real_args = fun3_create_from_ast_node(node);

    for (int i = 0; i < real_args.length; i++)
    {
        if (real_args[i].type == fun3_Type.inline)
        {
            real_args[i] = fun3_aexec(env, real_args[i].value, true);
        }
    }

    string function_name = node.id;

    if (function_name in env.user_functions)
    {
        fun3_run_function(env, env.user_functions[function_name]);
    }

    else if (function_name in env.builtin_functions)
    {
        return env.builtin_functions[function_name](env, real_args);
    }

    else
    {
        writefln("fun3: in invocation of ('%s')", function_name);
        writefln("\t\x1b[31;1mfun3:\x1b[0m function '%s' not found", function_name);

        string exp = "";

        foreach (string n; keys(env.builtin_functions))
        {
            if (levenshteinDistance(function_name, n) < 3)
            {
                exp = n;
            }
        }

        foreach (string n; keys(env.user_functions))
        {
            if (levenshteinDistance(function_name, n) < 3)
            {
                exp = n;
            }
        }

        writefln("\t\x1b[31;3mfun3: note: did you mean \x1b[32;3m'%s'\x1b[0m?\x1b[0m", exp);
        error([function_name], "F3FunctionNotFoundException");
    }

    return fun3_create_value("0");
}

fun3_Value[] optimize_args(fun3_env* env, fun3_Value[] args)
{
    fun3_Value[] new_;

    for (int i = 0; i < args.length; i++)
    {
        if (args[i].type == fun3_Type.inline)
        {
            args[i] = fun3_aexec(env, args[i].value, true);
            new_ ~= args[i];
        }
    }

    return new_;
}

fun3_Stat[] fun3_convert_to_stats(ASTNode n)
{
    // simply converts an ASTNode to a fun3_Stat array
    fun3_Stat[] stats;
    if (n.type != ASTNodeType.ASTDecl)
        return stats;

    foreach (ASTNode node; n.next[0].node)
    {
        stats ~= fun3_Stat(node.id, fun3_create_from_ast_node(node));
    }

    return stats;
}

/** aexec - ACTUALLY EXECUTES THE FUNCTIONS IN THE ENVIRONMENT */
fun3_Value fun3_aexec(fun3_env* env, string statement, bool sub = false)
{
    AST ast = generate_ast(statement);
    statement = strip(statement);

    if (startsWith(statement, '['))
    {
        return fun3_aexec(env, statement[1 .. lastIndexOf(statement, ']')] ~ ";", true);
    }

    if (startsWith(statement, '"'))
    {
        return fun3_create_value(statement);
    }

    if (isDigit(statement[0]))
    {
        return fun3_create_value(statement);
    }

    if (statement == "true" || statement == "false")
    {
        return fun3_create_value(statement);
    }

    foreach (ASTNode node; ast.node)
    {
        if (node.type == ASTNodeType.ASTCall)
        {
            if (sub)
            {
                return fun3_exec(env, node);
            }
            else
            {
                fun3_exec(env, node);
            }
        }
        else if (node.type == ASTNodeType.ASTDecl)
        {
            if (node.arg[0] == "main")
            {
                foreach (AST n; node.next)
                {
                    foreach (ASTNode m; n.node)
                    {
                        if (m.type == ASTNodeType.ASTCall)
                        {
                            // im like 7 nests in. this is so bad
                            fun3_exec(env, m);
                        }
                    }

                }
            }
            else
            {
                env.user_functions[node.arg[0]] = create_function(node.arg[0], fun3_convert_to_stats(
                        node));
            }
        }
    }

    return fun3_create_value("0");
}

fun3_Stat[] optimize_stats(fun3_env* e, fun3_Stat[] stats)
{
    fun3_Stat[] new_;

    foreach (fun3_Stat stat; stats)
    {
        int i = 0;
        foreach (fun3_Value value; stat.args)
        {
            if (value.type == fun3_Type.inline)
            {
                stat.args[0] = fun3_aexec(e, value.value, true);
            }
            i++;
        }
        new_ ~= stat;
    }

    return new_;
}
