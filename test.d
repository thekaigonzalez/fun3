/*Copyright 2019-2023 Kai D. Gonzalez*/

import errors;
import lexer;
import parser;
import eval;

import std.json;
import std.stdio : writefln;
import std.file : readText;
import std.string : strip, startsWith, endsWith, lastIndexOf;
import std.ascii : isDigit, isAlpha;
import std.conv : to;

fun3_Value fun3_print (fun3_env * e, fun3_Value[] args)
{
    writefln("%s", args[0].value);

    return fun3_create_value("0");
}

fun3_Value fun3_add (fun3_env * e, fun3_Value[] args)
{
    return fun3_create_value(to!string(to!int(args[0].value) + to!int(args[1].value)));
}

int main()
{
    // if you're anything like me and you use vscode
    // i am telling you brother. or sister. invest in that one extension that
    // will highlight your ugly ass mistakes. you wont regret it also, invest in
    // a word wrapping
    string text = readText("test.fun");

    auto env = fun3_env();

    fun3_env_add_function(&env, "print", &fun3_print);
    fun3_env_add_function(&env, "add", &fun3_add);

    try {
    fun3_aexec(&env, text); // note: ignore the return value of fun3_exec() by all costs

    }
    catch (Exception e) {}
    return 0;
}
